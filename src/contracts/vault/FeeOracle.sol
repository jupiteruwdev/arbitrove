// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@vault/IVault.sol";
import "@structs/structs.sol";

contract FeeOracle is OwnableUpgradeable {
    CoinWeight[50] public targets;
    /// length of coin weight targets
    uint256 public targetsLength;
    /// max fee
    uint256 public maxFee;
    /// max bonus
    uint256 public maxBonus;
    /// weight denominator for weight calculation
    uint256 public weightDenominator;

    event SET_TARGETS(CoinWeight[]);

    constructor() {
        _disableInitializers();
    }

    function init(uint256 _maxFee, uint256 _maxBonus) external initializer {
        require(_maxFee <= 100, "_maxFee can't greater than 100");
        require(_maxBonus <= 100, "_maxFee can't greater than 100");

        __Ownable_init();
        maxFee = _maxFee;
        maxBonus = _maxBonus;
        weightDenominator = 100;
    }

    function setTargets(CoinWeight[] memory weights) external onlyOwner {
        targetsLength = weights.length;
        for (uint8 i; i < weights.length; ) {
            targets[i] = weights[i];
            unchecked {
                ++i;
            }
        }
        isNormalizedWeightArray(weights);
        emit SET_TARGETS(weights);
    }

    function getDepositFee(
        DepositFeeParams memory params
    )
        external
        returns (int256 fee, CoinWeight[] memory weights, uint256 tvlUSD10000X)
    {
        CoinWeightsParams memory coinWeightParams = CoinWeightsParams({
            cpu: params.cpu,
            vault: params.vault,
            expireTimestamp: params.expireTimestamp
        });
        (weights, tvlUSD10000X) = getCoinWeights(coinWeightParams);
        CoinWeight memory target = targets[params.position];
        CoinWeight memory currentCoinWeight = weights[params.position];
        uint256 __decimals = target.coin == address(0)
            ? 18
            : IERC20Metadata(target.coin).decimals();

        /// new weight calc
        /// formula: depositValue = depositAmount * depositPrice / 10**decimals
        uint256 depositValueUSD10000X = (params.amount *
            params.cpu[params.position].price) / 10 ** __decimals;

        /// formula: currentCoinValue = currentCoinWeight * tvl / weightDenominator
        uint256 currentCoinValue = (currentCoinWeight.weight * tvlUSD10000X) /
            weightDenominator;

        /// formula: newWeight = (currentCoinValue + depositValue) * weightDenominator / (tvl + depositValue)
        uint256 newWeight = ((currentCoinValue + depositValueUSD10000X) *
            weightDenominator) / (tvlUSD10000X + depositValueUSD10000X);

        // calculate distance
        uint256 originalDistance = target.weight >= currentCoinWeight.weight
            ? ((target.weight - currentCoinWeight.weight) * 100) / target.weight
            : ((currentCoinWeight.weight - target.weight) * 100) /
                target.weight;
        uint256 newDistance = target.weight >= newWeight
            ? ((target.weight - newWeight) * 100) / target.weight
            : ((newWeight - target.weight) * 100) / target.weight;
        require(newDistance < 100, "Too far away from target");
        if (originalDistance > newDistance) {
            // bonus
            uint256 improvement = originalDistance - newDistance;
            fee = (int256(improvement * maxBonus) * -1) / 100;
        } else {
            // penalty
            uint256 deterioration = newDistance - originalDistance;
            fee = int256(deterioration * maxFee) / 100;
        }
    }

    function getWithdrawalFee(
        WithdrawalFeeParams memory params
    )
        external
        returns (int256 fee, CoinWeight[] memory weights, uint256 tvlUSD10000X)
    {
        CoinWeightsParams memory coinWeightParams = CoinWeightsParams({
            cpu: params.cpu,
            vault: params.vault,
            expireTimestamp: params.expireTimestamp
        });
        (weights, tvlUSD10000X) = getCoinWeights(coinWeightParams);
        CoinWeight memory target = targets[params.position];
        CoinWeight memory currentCoinWeight = weights[params.position];
        uint256 __decimals = target.coin == address(0)
            ? 18
            : IERC20Metadata(target.coin).decimals();

        /// new weight calc
        /// formula: withdrawalValue = withdrawalAmount * withdrawalPrice / 10**decimals
        uint256 withdrawalValueUSD10000X = (params.amount *
            params.cpu[params.position].price) / 10 ** __decimals;

        /// formula: currentCoinValue = currentCoinWeight * tvl / weightDenominator
        uint256 currentCoinValue = (currentCoinWeight.weight * tvlUSD10000X) /
            weightDenominator;

        /// formula: newWeight = (currentCoinValue - withdrawalValue) * weightDenominator / (tvl - withdrawalValue)
        uint256 newWeight = ((currentCoinValue - withdrawalValueUSD10000X) *
            weightDenominator) / (tvlUSD10000X - withdrawalValueUSD10000X);

        // calculate distance
        uint256 originalDistance = target.weight >= currentCoinWeight.weight
            ? ((target.weight - currentCoinWeight.weight) * weightDenominator) /
                target.weight
            : ((currentCoinWeight.weight - target.weight) * weightDenominator) /
                target.weight;
        uint256 newDistance = target.weight >= newWeight
            ? ((target.weight - newWeight) * weightDenominator) / target.weight
            : ((newWeight - target.weight) * weightDenominator) / target.weight;
        require(newDistance < weightDenominator, "Too far away from target");
        if (originalDistance > newDistance) {
            // bonus
            uint256 improvement = originalDistance - newDistance;
            fee = int256(improvement * maxBonus) / 100;
        } else {
            // penalty
            uint256 deterioration = newDistance - originalDistance;
            fee = (int256(deterioration * maxFee) * -1) / 100;
        }
    }

    function getTargets() external view returns (CoinWeight[] memory) {
        CoinWeight[] memory _targets = new CoinWeight[](targetsLength);
        for (uint8 i; i < targetsLength; ) {
            _targets[i] = targets[i];
            unchecked {
                ++i;
            }
        }
        return _targets;
    }

    event log_uint(uint256);

    function getCoinWeights(
        CoinWeightsParams memory params
    ) public returns (CoinWeight[] memory weights, uint256 tvlUSD10000X) {
        weights = new CoinWeight[](targetsLength);
        require(
            block.timestamp < params.expireTimestamp,
            "Execution window passed"
        );
        // verify signature
        require(params.cpu.length == targetsLength, "Oracle length error");
        CoinWeight[50] memory _targets = targets;
        uint256 _targetsLength = targetsLength;
        for (uint8 i; i < _targetsLength; ) {
            require(
                params.cpu[i].coin == _targets[i].coin,
                "Oracle order error 1"
            );
            uint256 amount = params.vault.getAmountAcrossStrategies(
                _targets[i].coin
            ) - params.vault.debt(_targets[i].coin);
            weights[i] = CoinWeight(params.cpu[i].coin, amount);
            unchecked {
                i++;
            }
        }
        // normalize the coin weight
        // find max
        uint8[] memory __decimals = new uint8[](_targetsLength);
        for (uint8 i; i < _targetsLength; ) {
            __decimals[i] = _targets[i].coin == address(0)
                ? 18
                : IERC20Metadata(_targets[i].coin).decimals();
            tvlUSD10000X +=
                (weights[i].weight * params.cpu[i].price) /
                10 ** __decimals[i];
            unchecked {
                i++;
            }
        }

        for (uint8 i; i < _targetsLength; ) {
            weights[i].weight =
                (weights[i].weight * params.cpu[i].price * 100) /
                tvlUSD10000X /
                10 ** __decimals[i];
            unchecked {
                i++;
            }
        }
        isNormalizedWeightArray(weights);
    }

    function isNormalizedWeightArray(
        CoinWeight[] memory weights
    ) internal pure {
        uint256 totalWeight = 0;
        uint8 j;
        for (uint8 i; i < weights.length; ) {
            totalWeight += weights[i].weight;
            unchecked {
                i++;
            }
            unchecked {
                j++;
            }
        }
        // compensate for rounding errors
        require(totalWeight >= 100 - j, "Weight error");
        require(totalWeight <= 100, "Weight error 2");
    }
}
