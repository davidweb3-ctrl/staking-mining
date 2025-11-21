// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/src/Test.sol";
import {KKToken} from "../contracts/KKToken.sol";
import {StakingPool} from "../contracts/StakingPool.sol";

contract StakingPoolTest is Test {
    KKToken public kkToken;
    StakingPool public stakingPool;

    address public owner = address(1);
    address public user1 = address(2);
    address public user2 = address(3);

    function setUp() public {
        // Deploy KK Token
        vm.prank(owner);
        kkToken = new KKToken();

        // Deploy Staking Pool
        vm.prank(owner);
        stakingPool = new StakingPool(address(kkToken));

        // Add staking pool as minter
        vm.prank(owner);
        kkToken.addMinter(address(stakingPool));

        // Give users some ETH
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
    }

    function testStake() public {
        vm.prank(user1);
        stakingPool.stake{value: 10 ether}();

        assertEq(stakingPool.balanceOf(user1), 10 ether);
        assertEq(stakingPool.totalStaked(), 10 ether);
    }

    function testUnstake() public {
        // Stake first
        vm.prank(user1);
        stakingPool.stake{value: 10 ether}();

        // Unstake half
        vm.prank(user1);
        stakingPool.unstake(5 ether);

        assertEq(stakingPool.balanceOf(user1), 5 ether);
        assertEq(stakingPool.totalStaked(), 5 ether);
    }

    function testRewardDistribution() public {
        // User1 stakes 10 ETH
        vm.prank(user1);
        stakingPool.stake{value: 10 ether}();

        // Mine 10 blocks
        vm.roll(block.number + 10);

        // User2 stakes 5 ETH
        vm.prank(user2);
        stakingPool.stake{value: 5 ether}();

        // Mine 10 more blocks
        vm.roll(block.number + 10);

        // Check rewards
        uint256 user1Reward = stakingPool.earned(user1);
        uint256 user2Reward = stakingPool.earned(user2);

        console.log("User1 reward:", user1Reward);
        console.log("User2 reward:", user2Reward);

        // User1 should have more rewards (staked longer and more)
        assertGt(user1Reward, user2Reward);
    }

    function testClaim() public {
        // Stake
        vm.prank(user1);
        stakingPool.stake{value: 10 ether}();

        // Mine blocks
        vm.roll(block.number + 10);

        // Claim rewards
        uint256 earnedBefore = stakingPool.earned(user1);
        assertGt(earnedBefore, 0);

        vm.prank(user1);
        stakingPool.claim();

        assertEq(stakingPool.earned(user1), 0);
        assertGt(kkToken.balanceOf(user1), 0);
    }

    function testMultipleStakes() public {
        // First stake
        vm.prank(user1);
        stakingPool.stake{value: 5 ether}();

        vm.roll(block.number + 5);

        // Second stake
        vm.prank(user1);
        stakingPool.stake{value: 5 ether}();

        assertEq(stakingPool.balanceOf(user1), 10 ether);
    }

    function testFairDistribution() public {
        // User1 stakes 10 ETH
        vm.prank(user1);
        stakingPool.stake{value: 10 ether}();

        // Mine 100 blocks
        vm.roll(block.number + 100);

        // User2 stakes 10 ETH
        vm.prank(user2);
        stakingPool.stake{value: 10 ether}();

        // Mine 100 more blocks
        vm.roll(block.number + 100);

        // Both users should have rewards, but user1 should have more
        uint256 user1Reward = stakingPool.earned(user1);
        uint256 user2Reward = stakingPool.earned(user2);

        assertGt(user1Reward, 0);
        assertGt(user2Reward, 0);
        assertGt(user1Reward, user2Reward); // User1 staked longer
    }

    function testRewardPerBlock() public {
        vm.prank(user1);
        stakingPool.stake{value: 10 ether}();

        // Mine exactly 1 block
        vm.roll(block.number + 1);

        // Should have some reward (10 tokens per block, but distributed by weight)
        uint256 reward = stakingPool.earned(user1);
        assertGt(reward, 0);
    }
}

