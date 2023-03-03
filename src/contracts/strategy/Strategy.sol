// SPDX-License-Identifier: MIT

import "@structs/structs.sol";
import "@strategy/IStrategy.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

pragma solidity 0.8.17;

contract ExampleStrategy is IStrategy {
    function getComponentAmount(address coin) external view returns (uint) {
            return IERC20(coin).balanceOf(address(this));
    }
    // doesnt mean to be used. just an example. can't withdraw
}