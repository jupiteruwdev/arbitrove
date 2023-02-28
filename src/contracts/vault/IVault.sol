// SPDX-License-Identifier: MIT

import "@structs/structs.sol";

pragma solidity 0.8.17;
interface IVault {
    // function getAllCoinValuesAcrossStrategies() external view returns (CoinValue[] memory);
    function getAmountAcrossStrategies(address coin) external returns (uint256 value);
}
