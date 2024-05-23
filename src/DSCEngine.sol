//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title DSC Engine
 * @author Sachet Dhanuka
 * 
 * The system is designed to be as minimal as possible,and have the tokens maintain a 1 token == 1$ peg
 * This stable coin has the properties:
 * -Exogenous Collateral
 * -Algorithmically Stable
 * -Dollar Pegged
 * 
 * It is similar to DAI if it had no governance,no fees and was only backed by WBTC and WETH
 * 
 * @notice This contract is the core of DSC System.It handles all the logic for mining and redeeming DSC,as well as depositing and withdrawing collateral
 * @notice This contract is VERY loosly based on the MakerDAO DSS (DAI) System
 */

import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract DSCEngine is ReentrancyGuard{

    error DSCEngine__NeedsMoreThanZero();
    error DSCEngine__tokenCollateralAddressAndpriceFeedArrayMustBeOfSameLength();
    error DSCEngine__NotAllowedToken();
    error DSCEngine__TransferFailed();
    error DSCEngine__HealthFactorIsBelowMinimum(uint256 healthFactor);
    error DSCEngine__MintFailed();
    error DSCEngine__HealthFactorOk();
    error DSCEngine__HealthFactorNotImproved();

    DecentralizedStableCoin private immutable i_dsc;
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50;
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;
    uint256 private constant LIQUIDATION_BONUS = 10;

    mapping(address token => address priceFeed) private s_priceFeeds;
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited;
    mapping(address user => uint256 amountDSC) private s_DSCMinted;
    address[] private s_tokenCollateralAddress;

    event CollateralDeposited(address indexed User,address indexed TokenAddress,uint256 indexed Amount);
    event CollateralRedeemed(address indexed redeemedFrom,address indexed redeemedTo,address indexed Token,uint256 amount);

    modifier MoreThanZero(uint256 amount){
        if(amount<=0){
            revert DSCEngine__NeedsMoreThanZero();
        }
        _;
    }
    modifier IsAllowedToken(address token){
        if(s_priceFeeds[token]==address(0)){
            revert DSCEngine__NotAllowedToken();
        }
        _;
    }

    constructor(address[] memory tokenCollateralAddress,address[] memory priceFeed,address Dsc){
        if(tokenCollateralAddress.length != priceFeed.length){
            revert DSCEngine__tokenCollateralAddressAndpriceFeedArrayMustBeOfSameLength();
        }
        for(uint256 i=0;i<tokenCollateralAddress.length;i++){
            s_priceFeeds[tokenCollateralAddress[i]] = priceFeed[i];
            s_tokenCollateralAddress.push(tokenCollateralAddress[i]);
        }
        i_dsc = DecentralizedStableCoin(Dsc);
    }

    function depositCollateralAndmintDSC(address tokenCollateralAddress,uint256 amountCollateral,uint256 amountDSCtoMint)external{
        depositCollateral(tokenCollateralAddress,amountCollateral);
        mintDSC(amountDSCtoMint);
    }
    function redeemCollateralAndburnDSC(address tokenCollateralAddress,uint256 amountCollateral,uint256 amountDSCtoBurn)external{
        burnDSC(amountDSCtoBurn);
        redeemCollateral(tokenCollateralAddress,amountCollateral);
    }

    function depositCollateral(address tokenCollateralAddress,uint256 amountCollateral)IsAllowedToken(tokenCollateralAddress)MoreThanZero(amountCollateral)nonReentrant public{
        s_collateralDeposited[msg.sender][tokenCollateralAddress] += amountCollateral;
        emit CollateralDeposited(msg.sender,tokenCollateralAddress,amountCollateral);
        bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender,address(this),amountCollateral);
        if(!success){
            revert DSCEngine__TransferFailed();
        }
    }
    //In order to redeem collateral, health factor must be over 1 after collateral is pulled
    function redeemCollateral(address tokenCollateralAddress,uint256 amountCollateral)MoreThanZero(amountCollateral)public{
        //solidity takes care of the math problem.If user withdraws more than he has ,it will throw an error and revert!
        //Here we are transfering the tokens to the sender before the check.That violates the CEI, but it is much more gas effecient than calculating the health factor by simulating.
        _redeemCollateral(tokenCollateralAddress,amountCollateral,msg.sender,msg.sender);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    function mintDSC(uint256 amountDSCtoMint)MoreThanZero(amountDSCtoMint)public{
        s_DSCMinted[msg.sender] += amountDSCtoMint;
        _revertIfHealthFactorIsBroken(msg.sender);
        bool minted = i_dsc.mint(msg.sender,amountDSCtoMint);
        if(!minted){
            revert DSCEngine__MintFailed();
        }
    }
    function burnDSC(uint256 amountDSCtoBurn)MoreThanZero(amountDSCtoBurn)public{
        _burnDSC(amountDSCtoBurn,msg.sender,msg.sender);
        _revertIfHealthFactorIsBroken(msg.sender); // I dont think we would need this...
    }
    function liquidate(address collateral,address user,uint256 debtToCover)external{
        uint256 startingHealthFactor = _healthFactor(user);
        if(startingHealthFactor >= MIN_HEALTH_FACTOR){
            revert DSCEngine__HealthFactorOk();
        }
        // We want to burn their DSC
        // And take their collateral
        // Bad User: 140$ETH 100$DSC
        // Debt to cover = 100$
        // 100$ == ?? ETH == 0.05ETH
        uint256 totalAmountFromDebtCovered = getTokenAmountFromUSD(collateral,debtToCover);
        // And give them a 10 percent bonus
        // So we are giving the liquidator 110$ WETH for 100 DSC
        uint256 bonusCollateral = (totalAmountFromDebtCovered * LIQUIDATION_BONUS)/LIQUIDATION_PRECISION;
        // 0.05 * .1 = 0.005
        uint256 totalCollateralToRedeem = bonusCollateral + totalAmountFromDebtCovered;
        _redeemCollateral(collateral,totalCollateralToRedeem,user,msg.sender);
        _burnDSC(debtToCover,user,msg.sender);

        uint256 endingHealthFactor = _healthFactor(user);
        if(endingHealthFactor < startingHealthFactor){
            revert DSCEngine__HealthFactorNotImproved();
        }
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    /////////////////////////////////////////
    /// Private and Internal view Functions//
    ////////////////////////////////////////

    /* @dev Low-level internal function, do not call unless the function calling it is checking for health factors being broken
    */
    function _burnDSC(uint256 amountDSCtoBurn,address onBehalfOf,address DSCFrom)private{
        s_DSCMinted[onBehalfOf] -= amountDSCtoBurn;
        bool success = i_dsc.transferFrom(DSCFrom,address(this),amountDSCtoBurn);
        if(!success){
            revert DSCEngine__TransferFailed();
        }
        i_dsc.burn(amountDSCtoBurn);
    }
    function _redeemCollateral(address tokenCollateral,uint256 amountCollateral,address from,address to)private{
        s_collateralDeposited[from][tokenCollateral] -= amountCollateral;
        emit CollateralRedeemed(from,to,tokenCollateral,amountCollateral);
        bool success = IERC20(tokenCollateral).transfer(to,amountCollateral);
        if(!success){
            revert DSCEngine__TransferFailed();
        }
    }

    function _AccountInformation(address user)private view returns(uint256 totalDSCMinted,uint256 totalCollateralValueInUSD){
        totalDSCMinted = s_DSCMinted[user];
        totalCollateralValueInUSD = getAccountCollateralValue(user);
        return (totalDSCMinted,totalCollateralValueInUSD);
    }
    function _healthFactor(address user)private view returns(uint256){
        //Total DSCMinted
        //Total Collateral Value in USD
        (uint256 totalDSCMinted,uint256 totalCollateralValueInUSD) = _AccountInformation(user);
        uint256 collateralAdjustedForThreshold = (totalCollateralValueInUSD * LIQUIDATION_THRESHOLD)/LIQUIDATION_PRECISION;
        return (collateralAdjustedForThreshold * PRECISION) / totalDSCMinted;
    }
    function _revertIfHealthFactorIsBroken(address user)internal view{
        uint256 userHealthFactor = _healthFactor(user);
        if(userHealthFactor < MIN_HEALTH_FACTOR){
            revert DSCEngine__HealthFactorIsBelowMinimum(userHealthFactor);
        }
    }

    /////////////////////////////////////////
    /// Public and External view Functions//
    ///////////////////////////////////////

    function getTokenAmountFromUSD(address token,uint256 usdAmountInWei)public view returns(uint256){
        AggregatorV3Interface pricefeed = AggregatorV3Interface(s_priceFeeds[token]);
        (,int256 price,,,) = pricefeed.latestRoundData();
        return (usdAmountInWei * PRECISION)/(uint256(price)*ADDITIONAL_FEED_PRECISION);
    }

    function getAccountCollateralValue(address user)public view returns(uint256 totalCollateralValueInUSD){
        // loop through each collateral token,get the amount they have deposited,and map it to the
        // price to get the USD value
        for(uint256 i = 0;i < s_tokenCollateralAddress.length;i++){
            address token = s_tokenCollateralAddress[i];
            uint256 amount = s_collateralDeposited[user][token];
            totalCollateralValueInUSD += getUSDValue(token,amount);
        }
        return totalCollateralValueInUSD;
    }
    function getUSDValue(address token,uint256 amount)public view returns(uint256){
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (,int256 price,,,) = priceFeed.latestRoundData();
        return ((uint256(price) * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION;
    }
     function getAccountInformation(address user)external view returns(uint256 totalDSCMinted,uint256 totalCollateralValueInUSD){
        (totalDSCMinted,totalCollateralValueInUSD) = _AccountInformation(user);
        return (totalDSCMinted,totalCollateralValueInUSD);
     }

    /////////////////////////////////////////
    /// Getter Functions ///////////////////
    ///////////////////////////////////////
    
    function getDepositedCollateralAmount(address user,address token)public view returns(uint256){
        return s_collateralDeposited[user][token];
    }
    function getTokenCollateralAddress()public view returns(address[] memory){
        return s_tokenCollateralAddress;
    }
}