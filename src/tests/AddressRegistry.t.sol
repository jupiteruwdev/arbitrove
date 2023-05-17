// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Test.sol";

import "@mocks/MockERC20.sol";

import "../../script/FactoryArbitrove.s.sol";

contract AddressRegistryTest is Test, VyperDeployer {
    AddressRegistry public ar;
    Router public router;

    event Initialized(address indexed feeOracle, address indexed router);

    function setUp() public {
        FactoryArbitrove factory = new FactoryArbitrove();
        factory.upgradeImplementation(
            TProxy(payable(factory.vaultAddress())),
            address(new Vault())
        );
        router = Router(
            deployContractWithArgs(
                "src/contracts/Router.vy",
                abi.encode(
                    factory.vaultAddress(),
                    factory.addressRegistryAddress(),
                    address(this)
                )
            )
        );

        ar = AddressRegistry(factory.addressRegistryAddress());
        ar.init(FeeOracle(factory.feeOracleAddress()), address(router));
    }

    function testInit() public {
        FactoryArbitrove factory = new FactoryArbitrove();
        factory.upgradeImplementation(
            TProxy(payable(factory.vaultAddress())),
            address(new Vault())
        );
        Router _router = Router(
            deployContractWithArgs(
                "src/contracts/Router.vy",
                abi.encode(
                    factory.vaultAddress(),
                    factory.addressRegistryAddress(),
                    address(this)
                )
            )
        );

        AddressRegistry _ar = AddressRegistry(factory.addressRegistryAddress());
        FeeOracle _feeOracle = FeeOracle(factory.feeOracleAddress());
        FeeOracle _feeOracleZero = FeeOracle(address(0));
        vm.expectRevert("_feeOracle address can't be zero");
        _ar.init(_feeOracleZero, address(_router));

        vm.expectRevert("_router address can't be zero");
        _ar.init(_feeOracle, address(0));

        vm.expectEmit(true, true, false, true);
        emit Initialized(address(_feeOracle), address(_router));

        _ar.init(_feeOracle, address(_router));
    }

    function testSetRouter() public {
        vm.expectRevert("_router address can't be zero");
        ar.setRouter(address(0));

        ar.setRouter(address(1));
        assertEq(ar.router(), address(1), "!setRouter");
    }

    function testAddRemoveRebalancer() public {
        vm.expectRevert("Rebalancer not whitelisted");
        ar.removeRebalancer(address(1));

        ar.addRebalancer(address(1));

        vm.expectRevert("Rebalancer already whitelisted");
        ar.addRebalancer(address(1));

        assertEq(
            ar.rebalancerWhitelist(address(1)),
            block.timestamp + 1 days,
            "!addRebalancer"
        );

        ar.removeRebalancer(address(1));
        assertEq(ar.rebalancerWhitelist(address(1)), 0, "!removeRebalancer");
    }

    function testAddStrategy() public {
        address[] memory coins = new address[](2);
        coins[0] = address(new MockERC20("Test Token1", "TT1"));
        coins[1] = address(new MockERC20("Test Token2", "TT2"));

        IStrategy strategy = IStrategy(address(1));

        ar.addStrategy(strategy, coins);

        vm.expectRevert("Strategy already whitelisted");
        ar.addStrategy(strategy, coins);

        coins[1] = address(new MockERC20("Test Token3", "TT3"));

        ar.addStrategy(IStrategy(address(2)), coins);

        assertEq(
            ar.supportedCoinAddresses(2),
            coins[1],
            "!supportedCoinAddress3"
        );

        assertEq(
            ar.getSupportedCoinAddresses().length,
            3,
            "!supportedCoinAddresses"
        );

        assertEq(
            ar.strategyWhitelist(IStrategy(address(1))),
            block.timestamp + 1 days,
            "!1.addStrategy"
        );

        assertEq(
            ar.strategyWhitelist(IStrategy(address(2))),
            block.timestamp + 1 days,
            "!2.addStrategy"
        );

        /// test adding only strategy
        uint256 beforeCoinsLength = ar.getSupportedCoinAddresses().length;
        ar.addStrategy(IStrategy(address(3)), coins);

        assertEq(
            ar.getSupportedCoinAddresses().length,
            beforeCoinsLength,
            "!supported coin address should not change if coins are already added"
        );

        assertEq(
            ar.strategyWhitelist(IStrategy(address(3))),
            block.timestamp + 1 days,
            "!3.addStrategy"
        );
    }

    function testRemoveStrategy() public {
        vm.expectRevert("Strategy not whitelisted");
        ar.removeStrategy(IStrategy(address(1)));

        address[] memory coins = new address[](2);
        coins[0] = address(new MockERC20("Test Token1", "TT1"));
        coins[1] = address(new MockERC20("Test Token2", "TT2"));

        ar.addStrategy(IStrategy(address(1)), coins);

        coins[1] = address(new MockERC20("Test Token3", "TT3"));

        ar.addStrategy(IStrategy(address(2)), coins);
        ar.addStrategy(IStrategy(address(3)), coins);

        ar.removeStrategy(IStrategy(address(1)));
        assertEq(
            ar.strategyWhitelist(IStrategy(address(1))),
            0,
            "!2.removeStrategy"
        );
        coins[0] = address(new MockERC20("Test Token1", "TT1"));
        coins[1] = address(new MockERC20("Test Token2", "TT2"));
        ar.addStrategy(IStrategy(address(1)), coins);

        coins[0] = address(new MockERC20("Test Token4", "TT4"));
        coins[1] = address(new MockERC20("Test Token5", "TT5"));
        ar.addStrategy(IStrategy(address(4)), coins);

        ar.removeStrategy(IStrategy(address(3)));
        assertEq(
            ar.strategyWhitelist(IStrategy(address(3))),
            0,
            "!1.removeStrategy"
        );
    }
}
