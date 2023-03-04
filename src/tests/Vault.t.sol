// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;
import "forge-std/Test.sol";
import "@mocks/MockERC20.sol";
import "@/FactoryArbitrove.sol";
import "../../script/FactoryArbitrove.s.sol";
import "@/strategy/Strategy.sol";

contract VaultTest is Test, VyperDeployer {
    Vault vault;
    MockERC20 public jonesToken;
    Router router;
    AddressRegistry ar;
    FeeOracle feeOracle;

    function setUp() public {
        address someRandomUser = vm.addr(1);
        vm.startPrank(someRandomUser);
        vm.deal(someRandomUser, 1 ether);

        FactoryArbitrove factory = new FactoryArbitrove();
        bytes memory sfd = abi.encode(
            factory.vaultAddress(),
            factory.addressRegistryAddress()
        );
        router = Router(deployContract("src/contracts/Router.vy"));
        router.initialize(
            factory.vaultAddress(),
            factory.addressRegistryAddress()
        );
        ar = AddressRegistry(factory.addressRegistryAddress());
        ar.init(
            IVault(factory.vaultAddress()),
            FeeOracle(factory.feeOracleAddress()),
            address(router)
        );
        Vault(payable(factory.vaultAddress())).init{value: 1e18}(
            AddressRegistry(factory.addressRegistryAddress())
        );
        FeeOracle(factory.feeOracleAddress()).init(
            AddressRegistry(factory.addressRegistryAddress()),
            20,
            0
        );
        CoinWeight[] memory cw = new CoinWeight[](2);

        feeOracle = FeeOracle(factory.feeOracleAddress());
        vault = Vault(payable(factory.vaultAddress()));
        jonesToken = new MockERC20("Jones Token", "JONES");
        jonesToken.mint(someRandomUser, 1e18);
        jonesToken.mint(address(vault), 1e19);
        cw[0] = CoinWeight(address(0), 50);
        cw[1] = CoinWeight(address(jonesToken), 50);
        FeeOracle(factory.feeOracleAddress()).setTargets(cw);
        vault.setCoinCapUSD(address(jonesToken), 1000e18);
        vault.setBlockCap(100000e18);
        ExampleStrategy st = new ExampleStrategy();
        address[] memory x = new address[](1);
        x[0] = address(jonesToken);
        AddressRegistry(factory.addressRegistryAddress()).addStrategy(st, x);
    }

    function test_setup() public {
        address someRandomUser = vm.addr(1);
        assertEq(vault.balanceOf(someRandomUser), 1e18);
        CoinWeight[] memory cw = new CoinWeight[](2);
        cw[0] = CoinWeight(address(0), 50);
        cw[1] = CoinWeight(address(jonesToken), 50);
        assertEq(feeOracle.getTargets()[0].coin, cw[0].coin);
        assertEq(feeOracle.getTargets()[1].coin, cw[1].coin);
        assertEq(router.owner(), someRandomUser);
        assertEq(ar.getCoinToStrategy(address(jonesToken)).length, 1);
    }

    function testDeposit() public {
        address someRandomUser = vm.addr(1);
        uint256 initialBalance = jonesToken.balanceOf(address(someRandomUser));
        assertEq(initialBalance, 1e18);
        jonesToken.approve(address(router), 1e18);
        router.submitMintRequest(
            MintRequest(
                1e18,
                1102011930037,
                jonesToken,
                someRandomUser,
                block.timestamp + 1 days
            )
        );

        assertEq(jonesToken.balanceOf(someRandomUser), initialBalance - 1e18);
        assertEq(jonesToken.balanceOf(address(router)), 1e18);
        assertEq(jonesToken.balanceOf(address(vault)), 1e19);

        CoinPriceUSD[] memory x = new CoinPriceUSD[](2);
        x[0] = CoinPriceUSD(address(0), 1600e4);
        x[1] = CoinPriceUSD(address(jonesToken), 20e4);
        assertEq(feeOracle.getTargets()[0].coin, x[0].coin);
        router.acquireLock();
        router.processMintRequest(OracleParams(x, block.timestamp + 1 days));
        assertEq(jonesToken.balanceOf(address(router)), 0);
    }
}
