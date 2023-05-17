// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "../../script/FactoryArbitrove.s.sol";

interface IRouter {
    function fee() external view returns (uint256);

    function mintQueueBack() external view returns (uint256);

    function mintQueueFront() external view returns (uint256);

    function burnQueueBack() external view returns (uint256);

    function burnQueueFront() external view returns (uint256);

    function owner() external view returns (address);

    function tokenDeposits(address) external view returns (uint256);

    function setFee(uint256) external;

    function submitMintRequest(MintRequest memory) external;

    function submitBurnRequest(BurnRequest memory) external;

    function processMintRequest(OracleParams memory) external;

    function processBurnRequest(OracleParams memory) external;

    function refundMintRequest() external;

    function refundBurnRequest() external;

    function rescueStuckTokens(IERC20, uint256) external;

    function suicide() external;
}
