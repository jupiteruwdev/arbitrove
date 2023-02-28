// SPDX-License-Identifier: MIT

import "@structs/structs.sol";

pragma solidity 0.8.17;
interface IStrategy {

    function getComponentAmount(address coin) external view returns (uint);
}
