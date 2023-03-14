// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@strategy/IStrategy.sol";
import "@vault/IVault.sol";
import "@vault/FeeOracle.sol";

contract AddressRegistry is OwnableUpgradeable {
  IVault public vault;
  FeeOracle public feeOracle;
  address public router;
  mapping (address => IStrategy[]) public coinToStrategy;
  mapping (IStrategy => bool) public strategyWhitelist;
  address[] public supportedCoinAddresses;

  constructor() {
    _disableInitializers();
  }

  function getCoinToStrategy(address u) external view returns (IStrategy[] memory) {
    return coinToStrategy[u];
  }

  function getWhitelistedStrategies(IStrategy s) external view returns (bool) {
    return strategyWhitelist[s];
  }
  
  function init(IVault _vault, FeeOracle _feeOracle, address _router) initializer external {
    __Ownable_init();
    vault = _vault;
    feeOracle = _feeOracle;
    router = _router;
  }

  function reinit(IVault _vault, FeeOracle _feeOracle, address _router) onlyOwner external {
    vault = _vault;
    feeOracle = _feeOracle;
    router = _router;
  }

  function addStrategy(IStrategy strategy, address[] calldata components) onlyOwner external {
    require(!strategyWhitelist[strategy], "Strategy already whitelisted");
    for (uint i; i < components.length;) {
      coinToStrategy[components[i]].push(strategy);
      unchecked {
        i++;
      }
    }
    strategyWhitelist[strategy] = true;
  }
}