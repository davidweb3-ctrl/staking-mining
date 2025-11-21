// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Lending Pool Interface (for bonus feature)
 * @notice This interface represents a typical DeFi lending protocol like Aave
 */
interface ILendingPool {
    /**
     * @dev Deposits ETH to the lending pool
     * @notice The amount is sent via msg.value
     */
    function deposit() payable external;

    /**
     * @dev Withdraws ETH from the lending pool
     * @param amount The amount of ETH to withdraw
     */
    function withdraw(uint256 amount) external;

    /**
     * @dev Gets the balance of deposited ETH
     * @return The balance of deposited ETH
     */
    function balanceOf(address account) external view returns (uint256);
}

