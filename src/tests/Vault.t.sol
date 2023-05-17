// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;
import "forge-std/Test.sol";

import "forge-std/StdUtils.sol";

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
    address public user1 = vm.addr(2);
    address public user2 = vm.addr(3);
    uint256 public mockCoin1Balance = 1e18;
    uint256 public mockUser1Balance = 1e18;
    uint256 public mockUser2Balance = 10e18;
    uint256 public mockVaultBalance = 1e19;

    event SetAddressRegistry(AddressRegistry indexed addressRegistry);

    function setUp() public {
        vm.startPrank(whale);
        vm.deal(whale, 1 ether);

        /// pre required contracts deployments
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
                    whale
                )
            )
        );

        ar = AddressRegistry(factory.addressRegistryAddress());
        ar.init(FeeOracle(factory.feeOracleAddress()), address(router));

        Vault(payable(factory.vaultAddress())).init829{value: 1e18}(
            AddressRegistry(factory.addressRegistryAddress())
        );
        FeeOracle(factory.feeOracleAddress()).init(70);

        /// setting up initial data
        CoinWeight[] memory cw = new CoinWeight[](2);

        feeOracle = FeeOracle(factory.feeOracleAddress());
        vault = Vault(payable(factory.vaultAddress()));
        /// set vault pool ratio denominator
        jonesToken = new MockERC20("Jones Token", "JONES");
        jonesToken.mint(whale, mockCoin1Balance);
        jonesToken.mint(user1, mockUser1Balance);
        jonesToken.mint(user2, mockUser2Balance);
        jonesToken.mint(address(vault), mockVaultBalance);
        cw[0] = CoinWeight(address(0), 0.5e18);
        cw[1] = CoinWeight(address(jonesToken), 0.5e18);
        FeeOracle(factory.feeOracleAddress()).setTargets(cw);
        vault.setCoinCapUSD(address(jonesToken), 1000e18);
        vault.setBlockCap(100000e18);
        ExampleStrategy st = new ExampleStrategy();
        address[] memory x = new address[](1);
        x[0] = address(jonesToken);
        AddressRegistry(factory.addressRegistryAddress()).addStrategy(st, x);
        vm.stopPrank();
    }

    // function testLive() public {
    //     Router _router = Router(0x7Ea13E17B09789A4D35616E96725cF2E26875A1E);
    //     FeeOracle _feeOracle = FeeOracle(
    //         0x2E4Fe97147Af312e72CD65AB234c4b85ccAdb674
    //     );
    //     Vault _vault = Vault(
    //         payable(0xb49B6A3Fd1F4bB510Ef776de7A88A9e65904478A)
    //     );
    //     vm.startPrank(0xd00C229faE4dAe8E3b1F5d39f4e7866f737B25a5);
    //     _router.submitMintRequest(
    //         MintRequest(
    //             1000000000000000000,
    //             1000,
    //             IERC20(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1),
    //             0xd00C229faE4dAe8E3b1F5d39f4e7866f737B25a5,
    //             block.timestamp + 1 days
    //         )
    //     );
    //     vm.stopPrank();

    //     // emit log_uint(
    //     //     _vault.coinCap(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1)
    //     // );
    //     // emit log_uint(_vault.blockCapUSD());

    //     vm.startPrank(0x84799b137192E5db1d0Cde253351EB121Ac8BBF8);
    //     CoinPriceUSD[] memory cpu = new CoinPriceUSD[](9);
    //     cpu[0] = CoinPriceUSD(
    //         0x0000000000000000000000000000000000000000,
    //         1893080000000000000000
    //     );
    //     cpu[1] = CoinPriceUSD(
    //         0x82aF49447D8a07e3bd95BD0d56f35241523fBab1,
    //         1893080000000000000000
    //     );
    //     cpu[2] = CoinPriceUSD(
    //         0xfc5A1A6EB076a2C7aD06eD22C90d7E710E35ad0a,
    //         72250000000000000000
    //     );
    //     cpu[3] = CoinPriceUSD(
    //         0x539bdE0d7Dbd336b79148AA742883198BBF60342,
    //         1150000000000000000
    //     );
    //     cpu[4] = CoinPriceUSD(
    //         0x3d9907F9a368ad0a51Be60f7Da3b97cf940982D8,
    //         2165250000000000000000
    //     );
    //     cpu[5] = CoinPriceUSD(
    //         0x10393c20975cF177a3513071bC110f7962CD67da,
    //         2110000000000000000
    //     );
    //     cpu[6] = CoinPriceUSD(
    //         0x18c11FD286C5EC11c3b683Caa813B77f5163A122,
    //         6080000000000000000
    //     );
    //     cpu[7] = CoinPriceUSD(
    //         0x3082CC23568eA640225c2467653dB90e9250AaA0,
    //         386494000000000000
    //     );
    //     cpu[8] = CoinPriceUSD(
    //         0x371c7ec6D8039ff7933a2AA28EB827Ffe1F52f07,
    //         502564000000000000
    //     );

    //     OracleParams memory op = OracleParams(cpu, block.timestamp + 10000);

    //     // CoinWeight[] memory targets = _feeOracle.getTargets();

    //     // uint256 maxFee = _feeOracle.maxFee();

    //     // emit log_uint(targets[1].weight);
    //     // emit log_uint(maxFee);

    //     FeeParams memory wfp = FeeParams(
    //         cpu,
    //         IVault(0xb49B6A3Fd1F4bB510Ef776de7A88A9e65904478A),
    //         block.timestamp + 1000,
    //         1,
    //         1000000000000000000
    //         // 100
    //     );

    //     // (, CoinWeight[] memory weights, uint256 tvl) = _feeOracle
    //     //     .getWithdrawalFee(wfp);

    //     // emit log_uint(weights[1].weight);

    //     // _router.acquireLock();

    //     emit log_uint(_vault.totalSupply());
    //     int256 test = 1e18;
    //     emit log_uint(uint256(test));
    //     bytes32 poolRatio = vm.load(address(_vault), bytes32(uint256(0)));
    //     bytes32 blockRatio = vm.load(address(_vault), bytes32(uint256(3)));

    //     emit log_bytes32(poolRatio);

    //     uint256 depositValue = (cpu[1].price * 1e18) / 10 ** 18;
    //     uint256 poolRatioDenominator = 1e18;
    //     int256 weightDenominator = 1e18;
    //     uint256 totalSupply = _vault.totalSupply();
    //     uint256 tvl = 532648364277809666849270;
    //     int256 fee = 0;

    //     uint256 mintAmount = (
    //         ((((depositValue * poolRatioDenominator) / tvl) *
    //             totalSupply *
    //             uint256(weightDenominator - fee)) / poolRatioDenominator)
    //     ) / uint256(weightDenominator);

    //     emit log_uint(mintAmount);

    //     // emit log_uint(uint256(poolRatio));
    //     // emit log_uint(uint256(blockRatio));
    //     // _router.processMintRequest(op);

    //     vm.stopPrank();
    // }

    function testInit() public {
        FactoryArbitrove factory = new FactoryArbitrove();
        factory.upgradeImplementation(
            TProxy(payable(factory.vaultAddress())),
            address(new Vault())
        );

        address vaultAddress = factory.vaultAddress();
        Vault _vault = Vault(payable(vaultAddress));

        vm.expectRevert("_addressRegistry address can't be zero");
        _vault.init829{value: 1e18}(AddressRegistry(address(0)));

        vm.expectRevert();
        _vault.init829{value: 1e14}(
            AddressRegistry(AddressRegistry(address(1)))
        );

        vm.expectEmit(true, false, false, true);
        emit SetAddressRegistry(ar);

        _vault.init829{value: 1e18}(ar);
    }

    function testSetup() public {
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
            0,
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
        router.processMintRequest(OracleParams(x, block.timestamp + 1 days));

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

        router.processBurnRequest(OracleParams(x, block.timestamp + 1 days));

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

    function testMultiDepositAndWithdraw() public {
        multipleDeposit();
        multipleWithdraw();
    }

    function testSetAddressRegistry(address _random) public {
        vm.assume(_random != address(0));
        vm.expectRevert();
        vault.setAddressRegistry(AddressRegistry(_random));

        vm.startPrank(whale);
        AddressRegistry arZero = AddressRegistry(address(0));
        vm.expectRevert("_addressRegistry address can't be zero");
        vault.setAddressRegistry(arZero);

        vault.setAddressRegistry(AddressRegistry(_random));
        assertEq(address(vault.addressRegistry()), _random, "!addressRegistry");
        vm.stopPrank();
    }

    function testSetCoinCapUSD(address _random) public {
        vm.assume(_random != address(0));
        vm.expectRevert();
        vault.setCoinCapUSD(_random, 100e18);
        vm.startPrank(whale);

        vm.expectRevert("invalid coin address");
        vault.setCoinCapUSD(address(0), 100e18);

        vault.setCoinCapUSD(_random, 100e18);
        assertEq(vault.coinCap(_random), 100e18, "!coinCapUSD");
        vm.stopPrank();
    }

    function setBlockCap(uint256 _random) public {
        vm.expectRevert();
        vault.setBlockCap(_random);
        vm.startPrank(whale);
        vault.setBlockCap(_random);
        assertEq(vault.blockCapUSD(), _random, "!blockCap");
        vm.stopPrank();
    }

    function testClaimDebt(address _random) public {
        vm.expectRevert(bytes("only router has permitted"));
        vault.claimDebt(_random, 100e18);

        vm.startPrank(address(router));
        vm.expectRevert("insufficient debt amount for coin");
        vault.claimDebt(_random, 100e18);
        vm.stopPrank();
    }

    function testDepositCoinCapReached() public {
        vm.startPrank(whale);
        // set coin cap less than deposit amount
        vault.setCoinCapUSD(
            address(jonesToken),
            ((mockCoin1Balance / 2) * 20e4) / 1e18
        );
        vm.stopPrank();
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
        vm.expectRevert("Coin cap reached");
        router.processMintRequest(OracleParams(x, block.timestamp + 1 days));
        vm.stopPrank();
    }

    function testDepositBlockCapReached() public {
        vm.startPrank(whale);
        // set coin cap less than deposit amount
        vault.setBlockCap(((mockCoin1Balance / 2) * 20e4) / 1e18);
        vm.stopPrank();
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
        vm.expectRevert("Block cap reached");
        router.processMintRequest(OracleParams(x, block.timestamp + 1 days));
        vm.stopPrank();
    }

    function testWhithdrawBlockCapReached() public {
        vm.startPrank(whale);
        // set coin cap less than deposit amount
        vault.setBlockCap((((mockCoin1Balance * 3) / 2) * 20e4) / 1e18);
        vm.stopPrank();
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
        router.processMintRequest(OracleParams(x, block.timestamp + 1 days));

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

        vm.expectRevert("Block cap reached");
        router.processBurnRequest(OracleParams(x, block.timestamp + 1 days));
        vm.stopPrank();
    }

    function testApproveStrategy() public {
        vm.startPrank(whale);
        vm.expectRevert("invalid strategy address");
        vault.approveStrategy(IStrategy(address(0)), address(1), 1e18);

        vm.expectRevert("strategy is not whitelisted");
        vault.approveStrategy(IStrategy(address(1)), address(1), 1e18);

        address[] memory coins = new address[](2);
        coins[0] = address(new MockERC20("Test Token1", "TT1"));
        coins[1] = address(new MockERC20("Test Token2", "TT2"));

        ar.addStrategy(IStrategy(address(1)), coins);

        coins[1] = address(new MockERC20("Test Token4", "TT4"));

        ar.addStrategy(IStrategy(address(2)), coins);

        // strategy added but not whitelisted yet
        vm.expectRevert("strategy is not whitelisted");
        vault.approveStrategy(IStrategy(address(1)), coins[0], 1e18);

        vm.warp(block.timestamp + 2 days);

        vm.expectRevert("provided coin is not the part of strategy");
        vault.approveStrategy(IStrategy(address(1)), address(4), 1e18);

        vault.approveStrategy(IStrategy(address(2)), coins[0], 1e18);
        assertEq(
            IERC20(coins[0]).allowance(address(vault), address(2)),
            1e18,
            "!strategy allowance"
        );

        vm.stopPrank();
    }

    function testDepositETHToStrategy() public {
        vm.startPrank(whale);
        IStrategy strategy = IStrategy(address(1));
        vm.expectRevert("strategy is not whitelisted");
        vault.depositETHToStrategy(strategy, 1e18);

        address[] memory coins = new address[](2);
        coins[0] = address(new MockERC20("Test Token1", "TT1"));
        coins[1] = address(new MockERC20("Test Token2", "TT2"));

        ar.addStrategy(strategy, coins);

        vm.warp(block.timestamp + 2 days);

        vault.depositETHToStrategy(strategy, 1e18);
        assertEq(address(1).balance, 1e18, "!eth deposit");

        vm.expectRevert("Deposit failed");
        vault.depositETHToStrategy(strategy, 11e18);

        vm.stopPrank();
    }

    function testRebalancer() public {
        vm.startPrank(whale);
        vm.expectRevert("invalid destination");
        vault.rebalance(address(0), address(1), 1e18);

        vm.expectRevert("destination is not whitelisted");
        vault.rebalance(address(1), address(2), 1e18);

        ar.addRebalancer(address(1));

        vm.warp(block.timestamp + 2 days);

        vm.deal(address(vault), 10e18);

        vault.rebalance(address(1), address(0), 1e18);
        assertEq(address(1).balance, 1e18);

        vm.expectRevert("deposit to destination failed");
        vault.rebalance(address(1), address(0), 11e18);

        MockERC20 testCoin = new MockERC20("Test", "T");
        testCoin.mint(address(vault), 0.5e18);

        vm.expectRevert();
        vault.rebalance(address(1), address(testCoin), 1e18);
        vm.stopPrank();
    }

    function testGetAmountAcrossStrategies() public {
        assertEq(
            vault.getAmountAcrossStrategies(address(0)),
            address(vault).balance,
            "!vault eth amount"
        );

        MockERC20 testCoin = new MockERC20("Test Token", "TT");

        testCoin.mint(address(vault), 1e18);

        assertEq(
            vault.getAmountAcrossStrategies(address(testCoin)),
            1e18,
            "!1.vault test coin amount"
        );

        vm.startPrank(whale);
        address[] memory coins = new address[](2);
        coins[0] = address(testCoin);
        coins[1] = address(new MockERC20("Test Token2", "TT2"));

        ExampleStrategy strategy = new ExampleStrategy();

        ar.addStrategy(strategy, coins);

        vm.warp(block.timestamp + 2 days);
        vm.stopPrank();

        deal(address(testCoin), address(strategy), 1e18);

        assertEq(
            vault.getAmountAcrossStrategies(address(testCoin)),
            2e18,
            "!2.vault test coin amount"
        );
    }

    function multipleDeposit() internal {
        CoinPriceUSD[] memory x = new CoinPriceUSD[](2);

        /// submit user2 mint request
        vm.startPrank(user2);
        jonesToken.approve(address(router), mockUser2Balance);
        router.submitMintRequest(
            MintRequest(
                mockUser2Balance,
                1000000000000,
                jonesToken,
                user2,
                block.timestamp + 1 days
            )
        );
        vm.stopPrank();

        /// submit user1 mint request
        vm.startPrank(user1);
        jonesToken.approve(address(router), mockUser1Balance);
        router.submitMintRequest(
            MintRequest(
                mockUser1Balance,
                1000000000000,
                jonesToken,
                user1,
                block.timestamp + 1 days
            )
        );
        vm.stopPrank();

        vm.startPrank(whale);

        /// coin price usd for user1 deposit
        x[0] = CoinPriceUSD(address(0), 1600e4);
        x[1] = CoinPriceUSD(address(jonesToken), 20e4);

        /// depsosit fee params for user1 deposit
        FeeParams memory feeParams = FeeParams({
            cpu: x,
            vault: vault,
            expireTimestamp: block.timestamp + 1 days,
            position: 1,
            amount: mockUser2Balance
        });

        /// expected user1 vault balance after deposit
        uint256 expectedUser2VaultBalance = getExpectedDepositAmount(feeParams);

        /// process mint request in the queue for user1
        router.processMintRequest(OracleParams(x, block.timestamp + 1 days));

        /// coin price usd for user2 deposit
        x[0] = CoinPriceUSD(address(0), 1600e4);
        x[1] = CoinPriceUSD(address(jonesToken), 200e4);

        /// deposit fee params for user2 deposit
        feeParams = FeeParams({
            cpu: x,
            vault: vault,
            expireTimestamp: block.timestamp + 1 days,
            position: 1,
            amount: mockUser1Balance
        });

        /// expected user2 vault balance after deposit
        uint256 expectedUser1VaultBalance = getExpectedDepositAmount(feeParams);

        /// process mint request in the queue for user2
        router.processMintRequest(OracleParams(x, block.timestamp + 1 days));

        uint256 routerVaultBalance = vault.balanceOf(address(router));
        uint256 user1VaultBalance = vault.balanceOf(user1);
        uint256 user2VaultBalance = vault.balanceOf(user2);
        uint256 jonesTokenUser1Balance = jonesToken.balanceOf(user1);
        uint256 jonesTokenUser2Balance = jonesToken.balanceOf(user2);

        assertApproxEqAbs(
            user1VaultBalance,
            expectedUser1VaultBalance,
            uint256(10),
            "!user1 vault balance after deposit"
        );
        assertApproxEqAbs(
            user2VaultBalance,
            expectedUser2VaultBalance,
            uint256(10),
            "!user2 vault balance after deposit"
        );
        assertEq(routerVaultBalance, 0, "!router vault balance after deposit");
        assertEq(
            jonesTokenUser1Balance,
            0,
            "!user1 jonesToken balance after deposit"
        );
        assertEq(
            jonesTokenUser2Balance,
            0,
            "!user2 jonesToken balance after deposit"
        );
        vm.stopPrank();
    }

    function multipleWithdraw() internal {
        CoinPriceUSD[] memory x = new CoinPriceUSD[](2);
        uint256 initialUser1VaultBalance = vault.balanceOf(user1);
        uint256 initialUser2VaultBalance = vault.balanceOf(user2);

        /// submit user2 burn request
        vm.startPrank(user2);
        vault.approve(address(router), initialUser2VaultBalance);
        router.submitBurnRequest(
            BurnRequest(
                initialUser2VaultBalance,
                mockUser2Balance / 2,
                jonesToken,
                user2,
                block.timestamp + 1 days
            )
        );
        vm.stopPrank();

        /// submit user1 burn request
        vm.startPrank(user1);
        vault.approve(address(router), initialUser1VaultBalance);
        router.submitBurnRequest(
            BurnRequest(
                initialUser1VaultBalance,
                mockUser1Balance / 2,
                jonesToken,
                user1,
                block.timestamp + 1 days
            )
        );
        vm.stopPrank();

        vm.startPrank(whale);

        /// coin price usd for user1 withdraw
        x[0] = CoinPriceUSD(address(0), 1600e4);
        x[1] = CoinPriceUSD(address(jonesToken), 30e4);

        /// depsosit fee params for user1 withdraw
        FeeParams memory feeParams = FeeParams({
            cpu: x,
            vault: vault,
            expireTimestamp: block.timestamp + 1 days,
            position: 1,
            amount: mockUser2Balance / 2
        });

        /// expected user1 vault balance after withdraw
        uint256 expectedUser2VaultBalance = getExpectedWithdrawalAmount(
            feeParams
        );

        /// process burn request in the queue for user1
        router.processBurnRequest(OracleParams(x, block.timestamp + 1 days));

        /// coin price usd for user2 withdraw
        x[0] = CoinPriceUSD(address(0), 1600e4);
        x[1] = CoinPriceUSD(address(jonesToken), 200e4);

        /// withdraw fee params for user2 withdraw
        feeParams = FeeParams({
            cpu: x,
            vault: vault,
            expireTimestamp: block.timestamp + 1 days,
            position: 1,
            amount: mockUser1Balance / 2
        });

        /// expected user2 vault balance after withdraw
        uint256 expectedUser1VaultBalance = getExpectedWithdrawalAmount(
            feeParams
        );

        /// process burn request in the queue for user2
        router.processBurnRequest(OracleParams(x, block.timestamp + 1 days));

        uint256 routerVaultBalance = vault.balanceOf(address(router));
        uint256 user1VaultBalance = vault.balanceOf(user1);
        uint256 user2VaultBalance = vault.balanceOf(user2);
        uint256 jonesTokenUser1Balance = jonesToken.balanceOf(user1);
        uint256 jonesTokenUser2Balance = jonesToken.balanceOf(user2);

        assertApproxEqAbs(
            user1VaultBalance,
            initialUser1VaultBalance - expectedUser1VaultBalance,
            uint256(10),
            "!user1 vault balance after withdraw"
        );
        assertApproxEqAbs(
            user2VaultBalance,
            initialUser2VaultBalance - expectedUser2VaultBalance,
            uint256(10),
            "!user2 vault balance after withdraw"
        );
        assertEq(routerVaultBalance, 0, "!router vault balance after withdraw");
        assertEq(
            jonesTokenUser1Balance,
            mockUser1Balance / 2,
            "!user1 jonesToken balance after withdraw"
        );
        assertEq(
            jonesTokenUser2Balance,
            mockUser2Balance / 2,
            "!user2 jonesToken balance after withdraw"
        );
        vm.stopPrank();
    }

    function getExpectedDepositAmount(
        FeeParams memory feeParams
    ) internal view returns (uint256) {
        address coin = feeParams.cpu[feeParams.position].coin;
        uint256 __decimals = coin == address(0)
            ? 18
            : IERC20Metadata(coin).decimals();
        (int256 fee, , uint256 tvlUSD1e18X) = ar.feeOracle().getDepositFee(
            feeParams
        );
        uint256 expectedDepositValue = (feeParams.amount *
            feeParams.cpu[feeParams.position].price) / 10 ** __decimals;
        uint256 expectedPoolRatio = (expectedDepositValue * 1e18) / tvlUSD1e18X;

        uint256 expectedVaultBalance = (((expectedPoolRatio *
            vault.totalSupply()) / 1e18) * uint256(1e18 - fee)) / 1e18;
        return expectedVaultBalance;
    }

    function getExpectedWithdrawalAmount(
        FeeParams memory feeParams
    ) internal view returns (uint256) {
        address coin = feeParams.cpu[feeParams.position].coin;
        uint256 __decimals = coin == address(0)
            ? 18
            : IERC20Metadata(coin).decimals();
        (int256 fee, , uint256 tvlUSD1e18X) = ar.feeOracle().getWithdrawalFee(
            feeParams
        );
        uint256 expectedWithdrawalValue = (feeParams.amount *
            feeParams.cpu[feeParams.position].price) / 10 ** __decimals;
        uint256 expectedPoolRatio = (expectedWithdrawalValue * 1e18) /
            tvlUSD1e18X;

        uint256 expectedVaultBalance = (((expectedPoolRatio *
            vault.totalSupply()) / 1e18) * uint256(1e18 - fee)) / 1e18;
        return expectedVaultBalance;
    }
}
