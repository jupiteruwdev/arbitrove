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

    function init(AddressRegistry _addressRegistry, uint256 _maxFee, uint256 _maxBonus) external initializer onlyOwner {
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

    function getCoinWeights(CoinPriceUSD[] calldata cpu, IVault vault, uint256 expireTimestamp, bytes32 nonce, bytes32 r, bytes32 s, uint8 v) isNormalizedWeightArray(weights) public returns(CoinWeight[] memory weights, uint256 tvlUSD10000X) {
        weights = new CoinWeight[](targets.length);
        require(block.timestamp < expireTimestamp, "Execution window passed");
        require(!nonceActivated[nonce], "NOnce already activated");
        // activate nonce
        nonceActivated[nonce] = true;
        // verify signature
        require(ecrecover(keccak256(abi.encode(cpu, address(vault), expireTimestamp, nonce)), v, r, s) == addressRegistry.oracleSigner(), "Signature verification failed");
        require(cpu.length == targets.length, "Oracle length error");
        for (uint256 i; i < targets.length;) {
            uint256 amount = vault.getAmountAcrossStrategies(targets[i].coin);
            require(cpu[i].coin == targets[i].coin, "Oracle order error");
            weights[i] = CoinWeight(cpu[i].coin, amount);
            unchecked {
                i++;
            }
        }
        // normalize the coin weight
        // find max
        tvlUSD10000X = 0;
        for (uint256 i; i < targets.length;) {
            require(cpu[i].coin == targets[i].coin, "Oracle order error");
            tvlUSD10000X += weights[i].weight * cpu[i].price / 10**ERC20(cpu[i].coin).decimals();
            unchecked {
                i++;
            }
        }
        for (uint256 i; i < targets.length;) {
            require(cpu[i].coin == weights[i].coin, "Oracle order error");
            weights[i].weight = weights[i].weight * cpu[i].price / 10**ERC20(cpu[i].coin).decimals() * 100 / tvlUSD10000X;
            unchecked {
                i++;
            }
        }
    }
    
    function getDepositFee(CoinPriceUSD[] calldata cpu, IVault vault, uint256 expireTimestamp, bytes32 nonce, bytes32 r, bytes32 s, uint8 v, uint256 position, uint256 amount) external returns (int256 fee, CoinWeight[] memory weights, uint256 tvlUSD10000X) {
        (weights, tvlUSD10000X) = getCoinWeights(cpu, vault, expireTimestamp, nonce, r, s, v);
        CoinWeight memory target = targets[position];
        CoinWeight memory currentCoinWeight = weights[position];
        require(target.coin == currentCoinWeight.coin, "Oracle order error");
        uint256 depositValueUSD10000X = amount * cpu[position].price / 10**ERC20(cpu[position].coin).decimals();
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

    function getWithdrawalFee(CoinPriceUSD[] calldata cpu, IVault vault, uint256 expireTimestamp, bytes32 nonce, bytes32 r, bytes32 s, uint8 v, uint256 position, uint256 amount) external returns (int256 fee, CoinWeight[] memory weights, uint256 tvlUSD10000X) {
        (weights, tvlUSD10000X) = getCoinWeights(cpu, vault, expireTimestamp, nonce, r, s, v);
        CoinWeight memory target = targets[position];
        CoinWeight memory currentCoinWeight = weights[position];
        require(target.coin == currentCoinWeight.coin, "Oracle order error");
        uint256 withdrawalValueUSD10000X = amount * cpu[position].price / 10**ERC20(cpu[position].coin).decimals();
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
