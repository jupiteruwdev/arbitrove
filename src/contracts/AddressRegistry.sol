// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@strategy/IStrategy.sol";
import "@vault/FeeOracle.sol";

contract AddressRegistry is OwnableUpgradeable {
    FeeOracle public feeOracle;
    address public router;
    mapping(address => IStrategy[]) public coinToStrategy;
    mapping(IStrategy => bool) public strategyWhitelist;
    address[] public supportedCoinAddresses;

    event SET_ROUTER(address);
    event ADD_STRATEGY(IStrategy, address[]);

    constructor() {
        _disableInitializers();
    }

    function init(FeeOracle _feeOracle, address _router) external initializer {
        require(
            address(_feeOracle) != address(0),
            "_feeOracle address can't be zero"
        );
        require(_router != address(0), "_router address can't be zero");

        __Ownable_init();
        feeOracle = _feeOracle;
        router = _router;
    }

    function setRouter(address _router) external onlyOwner {
        require(_router != address(0), "_router address can't be zero");
        router = _router;

        emit SET_ROUTER(_router);
    }

    function addStrategy(
        IStrategy strategy,
        address[] calldata coins
    ) external onlyOwner {
        require(!strategyWhitelist[strategy], "Strategy already whitelisted");
        for (uint256 i; i < coins.length; ) {
            IStrategy[] memory strategiesForCoin = coinToStrategy[coins[i]];
            uint256 j;
            /// check strategy is already registered for the coin
            for (; j < strategiesForCoin.length; j++) {
                if (address(strategiesForCoin[j]) == address(strategy)) break;
            }
            /// add strategy if it's not registered
            if (j == strategiesForCoin.length) {
                coinToStrategy[coins[i]].push(strategy);
            }
            unchecked {
                i++;
            }
        }
        strategyWhitelist[strategy] = true;

        emit ADD_STRATEGY(strategy, coins);
    }

    function getCoinToStrategy(
        address coin
    ) external view returns (IStrategy[] memory) {
        return coinToStrategy[coin];
    }

    function getWhitelistedStrategies(
        IStrategy strategy
    ) external view returns (bool) {
        return strategyWhitelist[strategy];
    }
}
