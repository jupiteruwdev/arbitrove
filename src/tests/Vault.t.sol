// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;
import "forge-std/Test.sol";
import "@mocks/MockERC20.sol";
import "@mocks/MockStrategy.sol";
import "@/FactoryArbitrove.sol";
import "../../script/FactoryArbitrove.s.sol";

contract VaultTest is Test, VyperDeployer {
    Vault public vault;
    MockERC20 public jonesToken;
    Router public router;
    AddressRegistry public ar;
    FeeOracle public feeOracle;

    address public whale = vm.addr(1);
    uint256 public mockCoin1Balance = 1e18;
    uint256 public mockVaultBalance = 1e19;

    function setUp() public {
        vm.startPrank(whale);
        vm.deal(whale, 1 ether);

        /// pre required contracts deployments
        FactoryArbitrove factory = new FactoryArbitrove();
        factory.upgradeImplementation(
            TProxy(payable(factory.vaultAddress())),
            address(new Vault())
        );

        router = Router(deployContract("src/contracts/Router.vy"));
        router.initialize(
            factory.vaultAddress(),
            factory.addressRegistryAddress()
        );

        ar = AddressRegistry(factory.addressRegistryAddress());
        ar.init(FeeOracle(factory.feeOracleAddress()), address(router));
        Vault(payable(factory.vaultAddress())).init829{value: 1e18}(
            AddressRegistry(factory.addressRegistryAddress())
        );
        FeeOracle(factory.feeOracleAddress()).init(20, 0);

        /// setting up initial data
        CoinWeight[] memory cw = new CoinWeight[](2);

        feeOracle = FeeOracle(factory.feeOracleAddress());
        vault = Vault(payable(factory.vaultAddress()));
        jonesToken = new MockERC20("Jones Token", "JONES");
        jonesToken.mint(whale, mockCoin1Balance);
        jonesToken.mint(address(vault), mockVaultBalance);
        cw[0] = CoinWeight(address(0), 50);
        cw[1] = CoinWeight(address(jonesToken), 50);
        FeeOracle(factory.feeOracleAddress()).setTargets(cw);
        vault.setCoinCapUSD(address(jonesToken), 1000e18);
        vault.setBlockCap(100000e18);
        ExampleStrategy st = new ExampleStrategy();
        address[] memory x = new address[](1);
        x[0] = address(jonesToken);
        AddressRegistry(factory.addressRegistryAddress()).addStrategy(st, x);
        vm.stopPrank();
    }

    function test_setup() public {
        CoinWeight[] memory cw = new CoinWeight[](2);
        cw[0] = CoinWeight(address(0), 50);
        cw[1] = CoinWeight(address(jonesToken), 50);

        assertEq(
            vault.balanceOf(whale),
            mockCoin1Balance,
            "!whale's vault balance"
        );
        assertEq(feeOracle.getTargets()[0].coin, cw[0].coin, "!coin1 address");
        assertEq(feeOracle.getTargets()[1].coin, cw[1].coin, "!coin2 address");
        assertEq(router.owner(), whale, "!router owner");
        assertEq(
            ar.getCoinToStrategy(address(jonesToken)).length,
            1,
            "!strategy length for jonesToken"
        );
    }

    function testDepositAndWithdraw() public {
        vm.startPrank(whale);
        uint256 initialBalance = jonesToken.balanceOf(address(whale));
        uint256 expectedJTWhaleBalance = initialBalance - mockCoin1Balance;
        assertEq(
            initialBalance,
            mockCoin1Balance,
            "!whale's jonesToken initial balance"
        );
        jonesToken.approve(address(router), mockCoin1Balance);

        /// submit mint request to the router
        router.submitMintRequest(
            MintRequest(
                mockCoin1Balance,
                1000000000000,
                jonesToken,
                whale,
                block.timestamp + 1 days
            )
        );

        assertEq(
            jonesToken.balanceOf(whale),
            expectedJTWhaleBalance,
            "!expected whale's jonesToken balance after submit mint"
        );
        assertEq(
            jonesToken.balanceOf(address(router)),
            mockCoin1Balance,
            "!expected router jonesToken balance after submit mint"
        );
        assertEq(
            jonesToken.balanceOf(address(vault)),
            mockVaultBalance,
            "!expected vault jonesToken balance after submit mint"
        );

        CoinPriceUSD[] memory x = new CoinPriceUSD[](2);
        x[0] = CoinPriceUSD(address(0), 1600e4);
        x[1] = CoinPriceUSD(address(jonesToken), 20e4);
        assertEq(feeOracle.getTargets()[0].coin, x[0].coin);

        /// process mint request in the queue
        router.acquireLock();
        router.processMintRequest(OracleParams(x, block.timestamp + 1 days));
        router.releaseLock();

        uint256 routerVaultBalance = vault.balanceOf(address(router));
        uint256 whaleVaultBalance = vault.balanceOf(whale);
        assertEq(
            jonesToken.balanceOf(address(router)),
            0,
            "!expected router jonesToken balance after process mint"
        );
        assertEq(
            routerVaultBalance,
            0,
            "!expected router vault balance after process mint"
        );
        assertGt(
            whaleVaultBalance,
            0,
            "!expected whale vault balance after process mint"
        );

        /// Withdraw flow
        initialBalance = jonesToken.balanceOf(address(whale));
        assertEq(
            initialBalance,
            expectedJTWhaleBalance,
            "!whale's jonesToken initial balance"
        );
        vault.approve(address(router), whaleVaultBalance);

        /// submit burn request to the router
        router.submitBurnRequest(
            BurnRequest(
                mockCoin1Balance,
                mockCoin1Balance,
                jonesToken,
                whale,
                block.timestamp + 1 days
            )
        );

        router.acquireLock();
        router.processBurnRequest(OracleParams(x, block.timestamp + 1 days));
        router.releaseLock();

        assertEq(
            jonesToken.balanceOf(address(router)),
            0,
            "!expected router jonesToken balance after process burn"
        );
        assertEq(
            jonesToken.balanceOf(address(vault)),
            mockVaultBalance,
            "!expected vault's jonesToken balance after process burn"
        );
        assertEq(
            jonesToken.balanceOf(whale),
            mockCoin1Balance,
            "!expected whale's jonesToken balance"
        );
        assertLt(
            vault.balanceOf(whale),
            whaleVaultBalance,
            "!expected whale's vault balance"
        );
        vm.stopPrank();
    }
}
