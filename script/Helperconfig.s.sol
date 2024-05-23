//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract HelperConfig is Script{
    struct NetworkConfig{
        address wethUsdpricefeed;
        address wbtcUsdpricefeed;
        address weth;
        address wbtc;
        uint256 deployerkey;
    }

    NetworkConfig public ActiveNetworkConfig;
    uint8 public constant DECIMALS = 8;
    int256 public constant ETH_USD_PRICE = 2000e8;
    int256 public constant BTC_USD_PRICE = 1000e8;
    uint256 public constant ANVIL_PRIVATE_KEY =0x4bbbf85ce3377467afe5d46f804f221813b2bb87f24d81f60f1fcdbf7cbf4356;

    constructor(){
        if(block.chainid == 11155111){
            ActiveNetworkConfig = getsepoliaEthconfig();
        }else{
            ActiveNetworkConfig = getanvilEthconfig();
        }
    }
    function getsepoliaEthconfig()public view returns(NetworkConfig memory){
        return NetworkConfig({
            wethUsdpricefeed : 0x694AA1769357215DE4FAC081bf1f309aDC325306,
            wbtcUsdpricefeed : 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43,
            weth : 0xdd13E55209Fd76AfE204dBda4007C227904f0a81,
            wbtc : 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063,
            deployerkey : vm.envUint("PRIVATE_KEY")
        });
    }
    function getanvilEthconfig()public returns(NetworkConfig memory){
        if(ActiveNetworkConfig.wethUsdpricefeed != address(0)){
            return ActiveNetworkConfig;
        }
        vm.startBroadcast();
        MockV3Aggregator ethUsdpricefeed = new MockV3Aggregator(DECIMALS,ETH_USD_PRICE);
        ERC20Mock wethMock = new ERC20Mock();
        MockV3Aggregator btcUsdpricefeed = new MockV3Aggregator(DECIMALS,BTC_USD_PRICE);
        ERC20Mock wbtcMock = new ERC20Mock();
        vm.stopBroadcast();
        return NetworkConfig({
            wethUsdpricefeed : address(ethUsdpricefeed),
            wbtcUsdpricefeed : address(btcUsdpricefeed),
            weth : address(wethMock),
            wbtc : address(wbtcMock),
            deployerkey : ANVIL_PRIVATE_KEY
        });
    }
}