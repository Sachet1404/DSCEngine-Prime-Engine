//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../src/DSCEngine.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployDSC is Script{

    address[] public tokenAddress;
    address[] public priceFeeds;
    function run()external returns(DecentralizedStableCoin,DSCEngine,HelperConfig){
        HelperConfig helperconfig = new HelperConfig();

        (address wethUsdpricefeed,address wbtcUsdpricefeed,address weth,address wbtc,uint256 deployerkey) = helperconfig.ActiveNetworkConfig();
        tokenAddress = [weth,wbtc];
        priceFeeds = [wethUsdpricefeed,wbtcUsdpricefeed];

        vm.startBroadcast(deployerkey);
        DecentralizedStableCoin dsc = new DecentralizedStableCoin();
        DSCEngine dscengine = new DSCEngine(tokenAddress,priceFeeds,address(dsc));
        dsc.transferOwnership(address(dscengine));
        vm.stopBroadcast();

        return (dsc,dscengine,helperconfig);
    }
}