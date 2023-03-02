// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;
import "forge-std/Test.sol";
import "@mocks/MockERC20.sol";
import "@/FactoryArbitrove.sol";
import "../../script/FactoryArbitrove.s.sol";

contract VaultTest is Test, VyperDeployer {
    Vault vault;
    MockERC20 public jonesToken;

    function setUp() public {
        address someRandomUser = vm.addr(1);
        vm.prank(someRandomUser);
        vm.deal(someRandomUser, 1 ether);
        address oracleSignerAddress = vm.envAddress("ORACLE_SIGNER_ADDRESS");

        FactoryArbitrove factory = new FactoryArbitrove();
        address routerAddress = deployContract("src/contracts/Router.vy");
        AddressRegistry(factory.addressRegistryAddress()).init(oracleSignerAddress, IVault(factory.vaultAddress()), FeeOracle(factory.feeOracleAddress()), routerAddress);
        Vault(payable(factory.vaultAddress())).init{value: 1e15}(AddressRegistry(factory.addressRegistryAddress()));
        FeeOracle(factory.feeOracleAddress()).init(AddressRegistry(factory.addressRegistryAddress()), 20, 0);

        vault = Vault(payable(factory.vaultAddress()));
    }

    function test_setup() public {
        address someRandomUser = vm.addr(1);
        console.log(vault.balanceOf(someRandomUser));
        assertEq(vault.balanceOf(someRandomUser), 1e15);
        // assertTrue(true);
        // assertEq(address(farm.erc20()), address(testTroveToken));
        // assertEq(farm.rewardPerBlock(), 10);
        // assertEq(farm.startBlock(), 100);
        // assertEq(farm.endBlock(), 1000);
        // assertEq(farm.poolLength(), 1);
        // assertEq(farm.totalAllocPoint(), 100);

        // assertEq((testTroveToken.balanceOf(address(this))), 1000);
        // assertEq((testEsTroveToken.balanceOf(address(this))), 1000);
    }

    function testDeposit() public {
        // setUp();
        // assertEq(farm.deposited(0, address(this)), 0);
        // farm.deposit(0, 100, false);
        //farm.withdraw(0, 0, false);

        //     assertEq(farm.deposited(0, address(this)), 100);
        //     assertEq(farm.userInfo(0, address(this)).amount, 100);
        //     assertEq(farm.userInfo(0, address(this)).realAmount, 100);
    }
}
