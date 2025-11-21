// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/src/Script.sol";
import {KKToken} from "../contracts/KKToken.sol";
import {StakingPool} from "../contracts/StakingPool.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deploying contracts with account:", deployer);
        console.log("Account balance:", deployer.balance);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy KK Token
        KKToken kkToken = new KKToken();
        console.log("KKToken deployed at:", address(kkToken));

        // Deploy Staking Pool
        StakingPool stakingPool = new StakingPool(address(kkToken));
        console.log("StakingPool deployed at:", address(stakingPool));

        // Add staking pool as minter
        kkToken.addMinter(address(stakingPool));
        console.log("StakingPool added as minter");

        vm.stopBroadcast();

        console.log("\n=== Deployment Summary ===");
        console.log("KKToken:", address(kkToken));
        console.log("StakingPool:", address(stakingPool));
    }
}

