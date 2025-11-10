// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title VoteToken - Governance token with voting power
/// @author Your Name
contract VoteToken is ERC20Votes, Ownable {
    constructor() ERC20("VoteToken", "VOTE") ERC20Permit("VoteToken") {
        _mint(msg.sender, 1_000_000 * 1e18);
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}
