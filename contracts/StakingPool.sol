// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IToken.sol";
import "./interfaces/IStaking.sol";
import "./interfaces/ILendingPool.sol";

/**
 * @title StakingPool
 * @notice ETH staking pool that rewards users with KK Token based on stake duration and amount
 * @dev Implements fair distribution: rewards are allocated based on (stake amount * stake duration)
 */
contract StakingPool is IStaking, ReentrancyGuard, Ownable {
    IToken public immutable kkToken;
    ILendingPool public lendingPool; // Optional: for earning interest on staked ETH

    // Constants
    uint256 public constant REWARD_PER_BLOCK = 10 * 10**18; // 10 KK tokens per block
    uint256 public lastRewardBlock; // Last block number where rewards were calculated

    // User staking information
    struct UserInfo {
        uint256 amount; // Staked ETH amount
        uint256 stakeBlock; // Block number when user staked
        uint256 rewardDebt; // Reward debt to avoid double counting
    }

    mapping(address => UserInfo) public userInfo;

    // Global staking information
    uint256 public totalStaked; // Total ETH staked
    uint256 public totalWeight; // Total weight (sum of all stake amounts * durations)
    uint256 public accRewardPerWeight; // Accumulated rewards per weight unit

    // Events
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event Claimed(address indexed user, uint256 reward);
    event LendingPoolUpdated(address indexed oldPool, address indexed newPool);

    constructor(address _kkToken) Ownable(msg.sender) {
        require(_kkToken != address(0), "StakingPool: invalid token address");
        kkToken = IToken(_kkToken);
        lastRewardBlock = block.number;
    }

    /**
     * @dev Update the lending pool address (optional feature)
     * @param _lendingPool The address of the lending pool contract
     */
    function setLendingPool(address _lendingPool) external onlyOwner {
        address oldPool = address(lendingPool);
        lendingPool = ILendingPool(_lendingPool);
        emit LendingPoolUpdated(oldPool, _lendingPool);
    }

    /**
     * @dev Update reward variables to be up-to-date
     */
    function updatePool() public {
        if (block.number <= lastRewardBlock) {
            return;
        }

        if (totalWeight == 0) {
            lastRewardBlock = block.number;
            return;
        }

        uint256 blocksSinceLastUpdate = block.number - lastRewardBlock;
        uint256 reward = blocksSinceLastUpdate * REWARD_PER_BLOCK;

        if (reward > 0) {
            accRewardPerWeight += (reward * 1e18) / totalWeight;
        }

        lastRewardBlock = block.number;
    }

    /**
     * @dev Calculate user's current weight (stake amount * duration)
     * @param userAddr The user address
     * @return weight The user's current weight
     */
    function getUserWeight(address userAddr) public view returns (uint256) {
        UserInfo memory user = userInfo[userAddr];
        if (user.amount == 0 || user.stakeBlock == 0) {
            return 0;
        }
        // Weight = amount * (current block - stake block + 1)
        // +1 to account for the block where staking happened
        if (block.number >= user.stakeBlock) {
            return user.amount * (block.number - user.stakeBlock + 1);
        }
        return 0;
    }

    /**
     * @dev Update user's weight in totalWeight
     * @param userAddr The user address
     * @notice This function updates totalWeight by removing old weight and adding new weight
     */
    function updateUserWeight(address userAddr) internal {
        UserInfo storage user = userInfo[userAddr];
        
        // Calculate and remove old weight from totalWeight
        if (user.amount > 0 && user.stakeBlock > 0 && user.stakeBlock <= block.number) {
            uint256 oldWeight = user.amount * (block.number - user.stakeBlock + 1);
            if (totalWeight >= oldWeight) {
                totalWeight -= oldWeight;
            } else {
                totalWeight = 0; // Safety check
            }
        }
    }

    /**
     * @dev Calculate current total weight (sum of all user weights)
     * @return The total weight
     */
    function getTotalWeight() public view returns (uint256) {
        // This is a simplified version - in production, you might want to track this more efficiently
        // For now, we'll use the stored totalWeight and update it when needed
        return totalWeight;
    }

    /**
     * @dev Calculate pending rewards for a user
     * @param userAddr The user address
     * @return pending The pending reward amount
     */
    function pendingReward(address userAddr) public view returns (uint256) {
        UserInfo memory user = userInfo[userAddr];
        if (user.amount == 0 || user.stakeBlock == 0) {
            return 0;
        }

        // Calculate current total weight (all users' weights)
        uint256 currentTotalWeight = totalWeight;
        
        // If we're past the last reward block, we need to account for new rewards
        uint256 currentAccRewardPerWeight = accRewardPerWeight;
        
        if (block.number > lastRewardBlock && currentTotalWeight > 0) {
            uint256 blocksSinceLastUpdate = block.number - lastRewardBlock;
            uint256 reward = blocksSinceLastUpdate * REWARD_PER_BLOCK;
            currentAccRewardPerWeight += (reward * 1e18) / currentTotalWeight;
        }

        // Calculate user's current weight
        uint256 userWeight = user.amount * (block.number - user.stakeBlock + 1);
        
        // Calculate user's total reward based on weight
        uint256 userReward = (userWeight * currentAccRewardPerWeight) / 1e18;
        
        // Subtract already accounted reward debt
        if (userReward > user.rewardDebt) {
            return userReward - user.rewardDebt;
        }
        return 0;
    }

    /**
     * @dev Stake ETH to the pool
     */
    function stake() external payable override nonReentrant {
        require(msg.value > 0, "StakingPool: amount must be greater than 0");

        updatePool();
        updateUserWeight(msg.sender);

        UserInfo storage user = userInfo[msg.sender];
        
        // If user already has staked, claim existing rewards first
        if (user.amount > 0) {
            uint256 pending = pendingReward(msg.sender);
            if (pending > 0) {
                safeKKTransfer(msg.sender, pending);
                user.rewardDebt = (getUserWeight(msg.sender) * accRewardPerWeight) / 1e18;
            }
        }

        // Update user staking info
        user.amount += msg.value;
        if (user.stakeBlock == 0) {
            user.stakeBlock = block.number; // Set stake block for first stake
        }
        totalStaked += msg.value;

        // Update totalWeight with new user weight
        // Weight starts from the next block, so we use (block.number + 1 - user.stakeBlock)
        // But for simplicity, we'll calculate it as if it's already the next block
        if (user.stakeBlock > 0 && user.stakeBlock <= block.number) {
            uint256 newWeight = user.amount * (block.number - user.stakeBlock + 1);
            totalWeight += newWeight;
        }

        // Update reward debt
        user.rewardDebt = (getUserWeight(msg.sender) * accRewardPerWeight) / 1e18;

        // Optional: Deposit to lending pool if configured
        if (address(lendingPool) != address(0)) {
            (bool success, ) = address(lendingPool).call{value: msg.value}(
                abi.encodeWithSignature("deposit()")
            );
            require(success, "StakingPool: lending pool deposit failed");
        }

        emit Staked(msg.sender, msg.value);
    }

    /**
     * @dev Unstake ETH from the pool
     * @param amount The amount of ETH to unstake
     */
    function unstake(uint256 amount) external override nonReentrant {
        UserInfo storage user = userInfo[msg.sender];
        require(user.amount >= amount, "StakingPool: insufficient staked amount");

        updatePool();
        updateUserWeight(msg.sender);

        // Claim pending rewards
        uint256 pending = pendingReward(msg.sender);
        if (pending > 0) {
            safeKKTransfer(msg.sender, pending);
        }

        // Update user staking info
        user.amount -= amount;
        totalStaked -= amount;

        // If user unstakes all, reset stake block
        if (user.amount == 0) {
            user.stakeBlock = 0;
            user.rewardDebt = 0;
        } else {
            // Reset stake block to current block for remaining stake
            user.stakeBlock = block.number;
            // Update totalWeight with new user weight (starts from next block)
            uint256 newWeight = user.amount * 1; // Weight for current block
            totalWeight += newWeight;
            user.rewardDebt = (getUserWeight(msg.sender) * accRewardPerWeight) / 1e18;
        }

        // Withdraw from lending pool if configured
        if (address(lendingPool) != address(0)) {
            lendingPool.withdraw(amount);
        }

        // Transfer ETH back to user
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "StakingPool: ETH transfer failed");

        emit Unstaked(msg.sender, amount);
    }

    /**
     * @dev Claim KK Token rewards
     */
    function claim() external override nonReentrant {
        updatePool();
        updateUserWeight(msg.sender);

        UserInfo storage user = userInfo[msg.sender];
        require(user.amount > 0, "StakingPool: no staked amount");

        uint256 pending = pendingReward(msg.sender);
        require(pending > 0, "StakingPool: no rewards to claim");

        // Reset stake block to current block after claiming
        if (user.stakeBlock > 0) {
            // Remove old weight
            uint256 oldWeight = user.amount * (block.number - user.stakeBlock + 1);
            if (totalWeight >= oldWeight) {
                totalWeight -= oldWeight;
            }
            // Reset stake block
            user.stakeBlock = block.number;
            // Add new weight (starts from next block)
            uint256 newWeight = user.amount * 1; // Weight for current block
            totalWeight += newWeight;
        }
        
        user.rewardDebt = (getUserWeight(msg.sender) * accRewardPerWeight) / 1e18;
        safeKKTransfer(msg.sender, pending);

        emit Claimed(msg.sender, pending);
    }

    /**
     * @dev Get staked ETH balance of an account
     * @param account The account address
     * @return The staked ETH amount
     */
    function balanceOf(address account) external view override returns (uint256) {
        return userInfo[account].amount;
    }

    /**
     * @dev Get earned but not yet claimed KK Token rewards
     * @param account The account address
     * @return The earned reward amount
     */
    function earned(address account) external view override returns (uint256) {
        return pendingReward(account);
    }

    /**
     * @dev Safe KK token transfer, ensuring we don't exceed available balance
     * @param to The address to transfer to
     * @param amount The amount to transfer
     */
    function safeKKTransfer(address to, uint256 amount) internal {
        uint256 kkBalance = kkToken.balanceOf(address(this));
        if (amount > kkBalance) {
            // Mint the difference if needed
            kkToken.mint(address(this), amount - kkBalance);
        }
        kkToken.transfer(to, amount);
    }

    /**
     * @dev Receive ETH (fallback function)
     */
    receive() external payable {
        this.stake{value: msg.value}();
    }
}

