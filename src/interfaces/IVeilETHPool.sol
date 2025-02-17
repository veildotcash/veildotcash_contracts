// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

interface IVeilETHPool {
    function deposit(bytes32 commitment) external payable;
    function denomination() external view returns (uint256);
} 