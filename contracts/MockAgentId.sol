// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Test-only mock of the Agent ID registry: an address "holds" an Agent ID
///         when its mock balance is set to 1. NOT deployed to mainnet.
contract MockAgentId {
    mapping(address => uint256) private _bal;

    function set(address user, uint256 value) external {
        _bal[user] = value;
    }

    function balanceOf(address user) external view returns (uint256) {
        return _bal[user];
    }
}
