// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "forge-std/Test.sol";
import "@mocks/MockERC20.sol";
import "@mocks/MockStrategy.sol";
import "@/FactoryArbitrove.sol";
import "../../script/FactoryArbitrove.s.sol";
import "@/Rebalancer.sol";

contract RebalancerTest is Test, VyperDeployer {
    Vault public vault;
    AddressRegistry ar;
    IWETH public weth = IWETH(0xdCBaAe1f76a21faaDF4405FD144D6F574396C108);
    Rebalancer public rebalancer;

    function setUp() public {
        vm.deal(address(this), 1 ether);

        /// pre required contracts deployments
        FactoryArbitrove factory = new FactoryArbitrove();
        factory.upgradeImplementation(
            TProxy(payable(factory.vaultAddress())),
            address(new Vault())
        );

        Router router = Router(
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
        Vault(payable(factory.vaultAddress())).init829{value: 0.5 ether}(
            AddressRegistry(factory.addressRegistryAddress())
        );

        vault = Vault(payable(factory.vaultAddress()));

        rebalancer = Rebalancer(payable(factory.rebalancerAddress()));
        rebalancer.init(vault, weth);

        ar.addRebalancer(address(rebalancer));
    }

    function testRebalancer() public {
        vm.warp(block.timestamp + 1.5 days);

        vault.rebalance(address(rebalancer), address(0), 0.01 ether);
        assertEq(
            weth.balanceOf(address(vault)),
            0.01 ether,
            "!weth deposit balance"
        );
    }
}
