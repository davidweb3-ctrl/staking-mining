// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/src/Script.sol";
import {KKToken} from "../contracts/KKToken.sol";
import {StakingPool} from "../contracts/StakingPool.sol";

contract VerifyDeployment is Script {
    // 部署的合约地址（从部署脚本中获取）
    address constant KK_TOKEN = 0x5FbDB2315678afecb367f032d93F642f64180aa3;
    address constant STAKING_POOL = 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512;

    function run() external view {
        console.log("\n=== Verifying Deployment ===");
        
        // 验证 KKToken
        KKToken kkToken = KKToken(KK_TOKEN);
        console.log("KKToken name:", kkToken.name());
        console.log("KKToken symbol:", kkToken.symbol());
        console.log("KKToken total supply:", kkToken.totalSupply());
        
        // 验证 StakingPool
        StakingPool stakingPool = StakingPool(payable(STAKING_POOL));
        console.log("StakingPool KKToken address:", address(stakingPool.kkToken()));
        console.log("StakingPool total staked:", stakingPool.totalStaked());
        console.log("StakingPool reward per block:", stakingPool.REWARD_PER_BLOCK());
        console.log("StakingPool last reward block:", stakingPool.lastRewardBlock());
        
        // 验证 StakingPool 是否是 minter
        bool isMinter = kkToken.minters(STAKING_POOL);
        console.log("StakingPool is minter:", isMinter);
        
        console.log("\n=== Deployment Verified Successfully ===");
    }
}

