//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

//Handler is going to narrow down the way we call function

import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {Test,console} from "forge-std/Test.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract Handler is Test{
    DSCEngine dscengine;
    DecentralizedStableCoin dsc;
    ERC20Mock weth;
    ERC20Mock wbtc;
    uint256 MAX_DEPOSIT_SIZE = type(uint96).max;
    uint256 public marker;
    address[] public UsersHavingCollaterals;
    constructor(DecentralizedStableCoin _dsc,DSCEngine _dscengine){
        dscengine = _dscengine;
        dsc = _dsc;
        address[] memory tokenCollaterals = dscengine.getTokenCollateralAddress();
        weth = ERC20Mock(tokenCollaterals[0]);
        wbtc = ERC20Mock(tokenCollaterals[1]);
    }

    function depositCollateral(uint256 collateralSeed,uint256 amountCollateral)public{
        ERC20Mock  collateral = _getCollateralFromSeed(collateralSeed);
        amountCollateral = bound(amountCollateral,1,MAX_DEPOSIT_SIZE);
        UsersHavingCollaterals.push(msg.sender);
        vm.startPrank(msg.sender);
        collateral.mint(msg.sender,amountCollateral);
        collateral.approve(address(dscengine),amountCollateral);
        dscengine.depositCollateral(address(collateral),amountCollateral);
        vm.stopPrank();
    }
    function redeemCollateral(uint256 collateralSeed,uint256 amountCollateral)public{
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        uint256 maxCollateralToRedeem = dscengine.getDepositedCollateralAmount(msg.sender,address(collateral));
        amountCollateral = bound(amountCollateral,0,maxCollateralToRedeem);
        if(amountCollateral == 0){
            return;
        }
        vm.prank(msg.sender);
        dscengine.redeemCollateral(address(collateral),amountCollateral);
    }
    
    function mintDSC(uint256 amount,uint256 addressSeed)public{
        if(UsersHavingCollaterals.length == 0){
            return;
        }
        address sender = UsersHavingCollaterals[addressSeed % UsersHavingCollaterals.length];
        (uint256 totalDSCMinted,uint256 collateralValueInUSD) = dscengine.getAccountInformation(sender);
        int256 maxAmountToMint = (int256(collateralValueInUSD) / 2) - int256(totalDSCMinted);
        
        if(maxAmountToMint < 0){
            return;
        }
        amount = bound(amount,0,uint256(maxAmountToMint));
        if(amount == 0){
            return;
        }
        vm.prank(sender);
        dscengine.mintDSC(amount);
        marker++;
    }
    // Helper Functions
    function _getCollateralFromSeed(uint256 collateralSeed)private view returns(ERC20Mock){
        if(collateralSeed % 2 == 0){
            return weth;
        }
        return wbtc;
    }
}

