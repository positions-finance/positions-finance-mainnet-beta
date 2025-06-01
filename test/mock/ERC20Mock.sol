// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

/**
 * @title SimpleToken
 * @dev A simple ERC20 token with open mint and burn functions
 * Anyone can mint tokens to any address
 * Anyone can burn their own tokens
 */
contract ERC20Mock is ERC20, ERC20Burnable {
    /**
     * @dev Constructor that gives the token a name and symbol
     * @param name The name of the token
     * @param symbol The symbol of the token
     */
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    /**
     * @dev Public mint function - anyone can call this to mint tokens
     * @param to The address to mint tokens to
     * @param amount The amount of tokens to mint (in wei units)
     */
    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}
