//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test,console} from "forge-std/Test.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract DSCEngineTest is Test{

    DecentralizedStableCoin dsc;
    DSCEngine dscengine;
    HelperConfig helperconfig;
    address wethUsdpricefeed;
    address wbtcUsdpricefeed;
    address weth;
    address wbtc;
    address public USER = makeAddr("User");
    uint256 public constant AMOUNT_COLLATERAL = 10 ether;
    uint256 public constant STARTING_ERC20_BALANCE = 10 ether;
    function setUp()external{
        DeployDSC deployer = new DeployDSC();
        (dsc,dscengine,helperconfig) = deployer.run();
        (wethUsdpricefeed,wbtcUsdpricefeed,weth,wbtc,) = helperconfig.ActiveNetworkConfig();
        ERC20Mock(weth).mint(USER,STARTING_ERC20_BALANCE);
    }
    modifier DepositedCollateral(){
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscengine),AMOUNT_COLLATERAL);
        dscengine.depositCollateral(weth,AMOUNT_COLLATERAL);
        vm.stopPrank();
        _;
    }

   ///////////////////////
   /// PriceTest ///////
   ///////////////////////

    function testGetUsdValue()public view{
        uint256 ethAmount = 15e18;
        uint256 expectedUsdValue = 30000e18;
        uint256 actualUsdValue = dscengine.getUSDValue(weth,ethAmount);
        assertEq(expectedUsdValue,actualUsdValue);
    }
    function testgetTokenAmountFromUSD()public view{
        uint256 USDAmount = 100 ether;
        uint256 expectedTokenValue = 0.05 ether;
        uint256 actualTokenValue = dscengine.getTokenAmountFromUSD(weth,USDAmount);
        assertEq(expectedTokenValue,actualTokenValue);
    }
    /////////////////////////////
    /// depositCollateral ///////
    /////////////////////////////
    
    function testRevertsIfCollateralZero()public{
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscengine),AMOUNT_COLLATERAL);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dscengine.depositCollateral(weth,0);
        vm.stopPrank();
    }
    function testdepositedCollateralMappingisUpdated()public{
        uint256 amountCollateral = 5 ether;
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscengine),AMOUNT_COLLATERAL);
        dscengine.depositCollateral(weth,amountCollateral);
        assertEq(dscengine.getDepositedCollateralAmount(USER,weth),amountCollateral);
        vm.stopPrank();
    }
    function testRevertsIfTokenNotAllowed()public{
        uint256 amountCollateral = 5 ether;
        ERC20Mock mock = new ERC20Mock();
        mock.mint(USER,STARTING_ERC20_BALANCE);
        vm.prank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__NotAllowedToken.selector);
        dscengine.depositCollateral(address(mock),amountCollateral);
    }
    function testCanDepositCollateralAndGetAccountInfo() DepositedCollateral public{
        (uint256 totalDSCMinted,uint256 totalCollateralValueInUSD) = dscengine.getAccountInformation(USER);
        uint256 expectedTotalDSCMinted = 0;
        uint256 expectedDepositedAmount = dscengine.getTokenAmountFromUSD(weth,totalCollateralValueInUSD);
        assertEq(totalDSCMinted,expectedTotalDSCMinted);
        assertEq(AMOUNT_COLLATERAL,expectedDepositedAmount);
    }

    ///////////////////////
    /// Constructor ///////
    ///////////////////////

    address[] public tokenAddress;
    address[] public priceFeeds; 
    function testRevertsIfTokenLengthDoesnotMatchPriceFeeds()public {
        tokenAddress.push(weth);
        priceFeeds.push(wethUsdpricefeed);
        priceFeeds.push(wbtcUsdpricefeed);
        vm.expectRevert(DSCEngine.DSCEngine__tokenCollateralAddressAndpriceFeedArrayMustBeOfSameLength.selector);
        new DSCEngine(tokenAddress,priceFeeds,address(dsc));
    }
    
}