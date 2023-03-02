// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@/AddressRegistry.sol";
import "@vault/IVault.sol";
import "@structs/structs.sol";

// TODO: add precision to fee

contract FeeOracle is OwnableUpgradeable {
    address public weth_usdcPair;
    AddressRegistry addressRegistry;
    CoinWeight[] targets;
    uint256 targetsLength;
    mapping(bytes32 => bool) nonceActivated;
    uint256 maxFee;
    uint256 maxBonus;

      constructor() {
        _disableInitializers();
    }

    modifier isNormalizedWeightArray(CoinWeight[] memory weights) {
        _;
        uint256 totalWeight = 0;
        uint256 j = 0;
        for (uint i; i < weights.length;) {
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

    function init(AddressRegistry _addressRegistry, uint256 _maxFee, uint256 _maxBonus) external initializer {
        __Ownable_init();
        addressRegistry = _addressRegistry;
        maxFee = _maxFee;
        maxBonus = _maxBonus;
    }

    function setTargets(CoinWeight[] memory weights) isNormalizedWeightArray(weights) onlyOwner external {
        targetsLength = weights.length;
        for (uint i; i < weights.length;) {
            targets[i] = weights[i];
            unchecked {
                i++;
            }
        }
    }

    function getCoinWeights(CoinWeightsParams memory params) isNormalizedWeightArray(weights) public returns(CoinWeight[] memory weights, uint256 tvlUSD10000X) {
        weights = new CoinWeight[](targets.length);
        require(block.timestamp < params.expireTimestamp, "Execution window passed");
        require(!nonceActivated[params.nonce], "NOnce already activated");
        // activate nonce
        nonceActivated[params.nonce] = true;
        // verify signature
        require(ecrecover(keccak256(abi.encode(params.cpu, address(params.vault), params.expireTimestamp, params.nonce)), params.v, params.r, params.s) == addressRegistry.oracleSigner(), "Signature verification failed");
        require(params.cpu.length == targets.length, "Oracle length error");
        for (uint256 i; i < targets.length;) {
            uint256 amount = params.vault.getAmountAcrossStrategies(targets[i].coin) - params.vault.debt(targets[i].coin);
            require(params.cpu[i].coin == targets[i].coin, "Oracle order error");
            weights[i] = CoinWeight(params.cpu[i].coin, amount);
            unchecked {
                i++;
            }
        }
        // normalize the coin weight
        // find max
        tvlUSD10000X = 0;
        for (uint256 i; i < targets.length;) {
            require(params.cpu[i].coin == targets[i].coin, "Oracle order error");
            tvlUSD10000X += weights[i].weight * params.cpu[i].price / 10**ERC20(params.cpu[i].coin).decimals();
            unchecked {
                i++;
            }
        }
        for (uint256 i; i < targets.length;) {
            require(params.cpu[i].coin == weights[i].coin, "Oracle order error");
            weights[i].weight = weights[i].weight * params.cpu[i].price * 100 / tvlUSD10000X / 10**ERC20(params.cpu[i].coin).decimals();
            unchecked {
                i++;
            }
        }
    }
    
    function getDepositFee(DepositFeeParams memory params) external returns (int256 fee, CoinWeight[] memory weights, uint256 tvlUSD10000X) {
        CoinWeightsParams memory coinWeightParams = CoinWeightsParams({
            cpu: params.cpu,
            vault: params.vault,
            expireTimestamp: params.expireTimestamp,
            nonce: params.nonce,
            r: params.r,
            s: params.s,
            v: params.v
        });
        (weights, tvlUSD10000X) = getCoinWeights(coinWeightParams);
        CoinWeight memory target = targets[params.position];
        CoinWeight memory currentCoinWeight = weights[params.position];
        require(target.coin == currentCoinWeight.coin, "Oracle order error");
        uint256 depositValueUSD10000X = params.amount * params.cpu[params.position].price / 10**ERC20(params.cpu[params.position].coin).decimals();
        uint256 newWeight = (currentCoinWeight.weight * tvlUSD10000X / 100 + depositValueUSD10000X) * 100 / (tvlUSD10000X + depositValueUSD10000X);
        // calculate distance
        uint256 originalDistance = target.weight >= currentCoinWeight.weight ? (target.weight - currentCoinWeight.weight) * 100 / target.weight : (currentCoinWeight.weight - target.weight) * 100 / target.weight;
        uint256 newDistance = target.weight >= newWeight ? (target.weight - newWeight) * 100 / target.weight : (newWeight - target.weight) * 100 / target.weight;
        require(newDistance < 100, "Too far away from target");
        if (originalDistance > newDistance) {
            // bonus
            uint256 improvement = originalDistance - newDistance;
            fee = int256(improvement * maxBonus) * -1 / 100;
        } else {
            // penalty
            uint256 deterioration = originalDistance - newDistance;
            fee = int256(deterioration * maxFee) / 100;
        }
    }

    function getWithdrawalFee(WithdrawalFeeParams memory params) external returns (int256 fee, CoinWeight[] memory weights, uint256 tvlUSD10000X) {
        CoinWeightsParams memory coinWeightParams = CoinWeightsParams({
            cpu: params.cpu,
            vault: params.vault,
            expireTimestamp: params.expireTimestamp,
            nonce: params.nonce,
            r: params.r,
            s: params.s,
            v: params.v
        });
        (weights, tvlUSD10000X) = getCoinWeights(coinWeightParams);
        CoinWeight memory target = targets[params.position];
        CoinWeight memory currentCoinWeight = weights[params.position];
        require(target.coin == currentCoinWeight.coin, "Oracle order error");
        uint256 withdrawalValueUSD10000X = params.amount * params.cpu[params.position].price / 10**ERC20(params.cpu[params.position].coin).decimals();
        uint256 newWeight = (currentCoinWeight.weight * tvlUSD10000X / 100 - withdrawalValueUSD10000X) * 100 / (tvlUSD10000X + withdrawalValueUSD10000X);
        // calculate distance
        uint256 originalDistance = target.weight >= currentCoinWeight.weight ? (target.weight - currentCoinWeight.weight) * 100 / target.weight : (currentCoinWeight.weight - target.weight) * 100 / target.weight;
        uint256 newDistance = target.weight >= newWeight ? (target.weight - newWeight) * 100 / target.weight : (newWeight - target.weight) * 100 / target.weight;
        require(newDistance < 100, "Too far away from target");
        if (originalDistance > newDistance) {
            // bonus
            uint256 improvement = originalDistance - newDistance;
            fee = int256(improvement * maxBonus) / 100;
        } else {
            // penalty
            uint256 deterioration = originalDistance - newDistance;
            fee = int256(deterioration * maxFee) * -1 / 100;
        }
    }

}
