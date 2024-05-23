//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test,console} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Handler} from "./Handler.t.sol";

contract Invariants is StdInvariant, Test{
    DeployDSC deployer;
    DSCEngine dscengine;
    DecentralizedStableCoin dsc;
    HelperConfig helperconfig;
    address weth;
    address wbtc;
    Handler handler;
    function setUp()external{
        deployer = new DeployDSC();
        (dsc,dscengine,helperconfig) = deployer.run();
        (,,weth,wbtc,) = helperconfig.ActiveNetworkConfig();
        handler = new Handler(dsc,dscengine);
        targetContract(address(handler));
    }
    function invariant_ProtocolMustHaveMoreValueThanTotalSupply()public view{
        uint256 totalSupply = dsc.totalSupply();
        uint256 wethDeposited = IERC20(weth).balanceOf(address(dscengine));
        uint256 wbtcDeposited = IERC20(wbtc).balanceOf(address(dscengine));
        uint256 wethValue = dscengine.getUSDValue(weth,wethDeposited);
        uint256 wbtcValue = dscengine.getUSDValue(wbtc,wbtcDeposited);

        console.log("wethValue: ",wethValue);
        console.log("wbtcValue: ",wbtcValue);
        console.log("totalSupply: ",totalSupply);
        console.log("marker: ",handler.marker());
        
        assert(wbtcValue + wethValue >= totalSupply);
        
    }
}