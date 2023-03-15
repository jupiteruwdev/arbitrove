// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IStrategy {
    function getComponentAmount(address coin) external view returns (uint);
}
