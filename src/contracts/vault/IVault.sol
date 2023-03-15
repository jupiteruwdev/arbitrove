// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IVault {
    function getAmountAcrossStrategies(
        address coin
    ) external returns (uint256 value);

    function debt(address coin) external returns (uint256 value);
}
