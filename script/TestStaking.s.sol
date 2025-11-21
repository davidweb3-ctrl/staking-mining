// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/src/Script.sol";
import {KKToken} from "../contracts/KKToken.sol";
import {StakingPool} from "../contracts/StakingPool.sol";

contract TestStaking is Script {
    // 部署的合约地址
    address constant KK_TOKEN = 0x5FbDB2315678afecb367f032d93F642f64180aa3;
    address constant STAKING_POOL = 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512;
    
    // 测试账户私钥（anvil 默认账户）
    uint256 constant USER1_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    uint256 constant USER2_KEY = 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;

    function run() external {
        KKToken kkToken = KKToken(KK_TOKEN);
        StakingPool stakingPool = StakingPool(payable(STAKING_POOL));
        
        address user1 = vm.addr(USER1_KEY);
        address user2 = vm.addr(USER2_KEY);
        
        console.log("\n=== Testing Staking Functionality ===");
        console.log("User1 address:", user1);
        console.log("User2 address:", user2);
        console.log("User1 balance:", user1.balance);
        console.log("User2 balance:", user2.balance);
        
        // 测试 1: User1 质押 10 ETH
        console.log("\n--- Test 1: User1 stakes 10 ETH ---");
        vm.startBroadcast(USER1_KEY);
        stakingPool.stake{value: 10 ether}();
        vm.stopBroadcast();
        
        uint256 user1Staked = stakingPool.balanceOf(user1);
        console.log("User1 staked amount:", user1Staked);
        console.log("Total staked:", stakingPool.totalStaked());
        
        // 挖几个区块
        console.log("\n--- Mining 5 blocks ---");
        vm.roll(block.number + 5);
        console.log("Current block:", block.number);
        
        // 检查奖励
        uint256 user1Earned = stakingPool.earned(user1);
        console.log("User1 earned rewards:", user1Earned);
        
        // 测试 2: User2 质押 5 ETH
        console.log("\n--- Test 2: User2 stakes 5 ETH ---");
        vm.startBroadcast(USER2_KEY);
        stakingPool.stake{value: 5 ether}();
        vm.stopBroadcast();
        
        uint256 user2Staked = stakingPool.balanceOf(user2);
        console.log("User2 staked amount:", user2Staked);
        console.log("Total staked:", stakingPool.totalStaked());
        
        // 再挖几个区块
        console.log("\n--- Mining 10 more blocks ---");
        vm.roll(block.number + 10);
        console.log("Current block:", block.number);
        
        // 检查两个用户的奖励
        user1Earned = stakingPool.earned(user1);
        uint256 user2Earned = stakingPool.earned(user2);
        console.log("User1 earned rewards:", user1Earned);
        console.log("User2 earned rewards:", user2Earned);
        console.log("User1 should have more rewards (staked longer and more):", user1Earned > user2Earned);
        
        // 测试 3: User1 领取奖励
        console.log("\n--- Test 3: User1 claims rewards ---");
        uint256 user1EarnedBefore = stakingPool.earned(user1);
        console.log("User1 earned rewards before claim:", user1EarnedBefore);
        
        if (user1EarnedBefore > 0) {
            uint256 user1KKBefore = kkToken.balanceOf(user1);
            console.log("User1 KK balance before claim:", user1KKBefore);
            
            vm.startBroadcast(USER1_KEY);
            stakingPool.claim();
            vm.stopBroadcast();
            
            uint256 user1KKAfter = kkToken.balanceOf(user1);
            console.log("User1 KK balance after claim:", user1KKAfter);
            console.log("User1 received KK tokens:", user1KKAfter - user1KKBefore);
            
            // 挖几个区块后检查新奖励
            vm.roll(block.number + 3);
            console.log("User1 earned rewards after claim (3 blocks later):", stakingPool.earned(user1));
        } else {
            console.log("No rewards to claim");
        }
        
        // 测试 4: User2 部分赎回
        console.log("\n--- Test 4: User2 unstakes 2 ETH ---");
        uint256 user2ETHBefore = user2.balance;
        console.log("User2 ETH balance before unstake:", user2ETHBefore);
        
        vm.startBroadcast(USER2_KEY);
        stakingPool.unstake(2 ether);
        vm.stopBroadcast();
        
        uint256 user2ETHAfter = user2.balance;
        console.log("User2 ETH balance after unstake:", user2ETHAfter);
        console.log("User2 received ETH:", user2ETHAfter - user2ETHBefore);
        console.log("User2 remaining staked:", stakingPool.balanceOf(user2));
        
        console.log("\n=== All Tests Completed Successfully ===");
    }
}

