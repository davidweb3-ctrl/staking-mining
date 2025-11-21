// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IToken.sol";

/**
 * @title KK Token
 * @notice ERC20 token that can be minted by authorized contracts
 */
contract KKToken is ERC20, Ownable, IToken {
    mapping(address => bool) public minters;

    event MinterAdded(address indexed minter);
    event MinterRemoved(address indexed minter);

    constructor() ERC20("KK Token", "KK") Ownable(msg.sender) {}

    /**
     * @dev Add a minter address
     * @param minter The address to add as minter
     */
    function addMinter(address minter) external onlyOwner {
        minters[minter] = true;
        emit MinterAdded(minter);
    }

    /**
     * @dev Remove a minter address
     * @param minter The address to remove from minters
     */
    function removeMinter(address minter) external onlyOwner {
        minters[minter] = false;
        emit MinterRemoved(minter);
    }

    /**
     * @dev Mint tokens to an address
     * @param to The address to mint tokens to
     * @param amount The amount of tokens to mint
     */
    function mint(address to, uint256 amount) external override {
        require(minters[msg.sender], "KKToken: caller is not a minter");
        _mint(to, amount);
    }
}

