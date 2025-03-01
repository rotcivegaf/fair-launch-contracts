// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Factory} from "../src/Factory.sol";
import {IUniswapV2Router02} from "v2-periphery/interfaces/IUniswapV2Router02.sol";

import {IERC20} from "forge-std/interfaces/IERC20.sol";

contract Deploy is Script {
    function run() public returns (Factory factory) {
        console.log("Deploying...");

        // sepolia 0xeE567Fe1712Faf6149d80dA1E6934E354124CfE3
        factory = new Factory(
            IUniswapV2Router02(0xeE567Fe1712Faf6149d80dA1E6934E354124CfE3)
        );
    }
}