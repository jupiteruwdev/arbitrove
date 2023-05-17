// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "forge-std/Test.sol";

import "forge-std/StdUtils.sol";

import "@mocks/MockERC20.sol";

import "@mocks/MockStrategy.sol";

import "../../script/FactoryArbitrove.s.sol";

import "../contracts/IRouter.sol";

contract RouterTest is Test, VyperDeployer {
    Vault public vault;
    MockERC20 public jonesToken;
    IRouter public router;
    AddressRegistry public ar;
    FeeOracle public feeOracle;

    address public whale = vm.addr(1);
    address public user1 = vm.addr(2);
    address public user2 = vm.addr(3);
    uint256 public mockCoin1Balance = 10e18;
    uint256 public mockUser1Balance = 10e18;
    uint256 public mockUser2Balance = 10e18;
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

        router = IRouter(
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
        jonesToken.mint(address(this), 10e18);
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

    function testSetFee() public {
        vm.expectRevert("Not a permitted user");
        router.setFee(0.5e18);

        vm.startPrank(whale);
        vm.expectRevert("Invalid fee amount");
        router.setFee(0.6e18);

        router.setFee(0.3e18);
        assertEq(router.fee(), 0.3e18, "!setFee");
        vm.stopPrank();
    }

    function testSubmmitMintRequest() public {
        vm.startPrank(whale);

        MintRequest memory mr = MintRequest(
            10e18,
            1000000000000,
            MockERC20(address(1)),
            whale,
            block.timestamp + 1 days
        );
        vm.expectRevert("Invalid coin for oracle");
        router.submitMintRequest(mr);

        mr = MintRequest(
            10e18,
            1000000000000,
            jonesToken,
            address(this),
            block.timestamp + 1 days
        );
        vm.expectRevert("Invalid requester");
        router.submitMintRequest(mr);

        mr = MintRequest(
            10e18,
            1000000000000,
            MockERC20(address(0)),
            whale,
            block.timestamp + 1 days
        );
        vm.expectRevert("Eth deposit is not allowed");
        router.submitMintRequest(mr);

        mr = MintRequest(
            10e18,
            1000000000000,
            jonesToken,
            whale,
            block.timestamp + 1 days
        );
        vm.expectRevert("ERC20: insufficient allowance");
        router.submitMintRequest(mr);

        jonesToken.approve(address(router), 10e18);
        for (uint256 i = 1; i <= 100; i++) {
            mr = MintRequest(
                10e18 / 1000,
                1000000000000,
                jonesToken,
                whale,
                block.timestamp + 1 days
            );
            router.submitMintRequest(mr);

            assertEq(
                jonesToken.balanceOf(address(router)),
                ((10e18 * i) / 1000),
                "!jonesToken blanace"
            );
            assertEq(router.mintQueueBack(), i, "!mintQueueBack");
        }
        assertEq(router.mintQueueFront(), 1, "!mintQueueFront");

        vm.expectRevert("Mint queue limited");
        router.submitMintRequest(mr);

        vm.stopPrank();
    }

    function testSubmitBurnRequest() public {
        BurnRequest memory br = BurnRequest(
            10e18,
            10e18,
            MockERC20(address(1)),
            whale,
            block.timestamp + 1 days
        );
        vm.expectRevert("Invalid coin for oracle");
        router.submitBurnRequest(br);

        br = BurnRequest(
            10e18,
            10e18,
            jonesToken,
            whale,
            block.timestamp + 1 days
        );
        vm.expectRevert("Invalid requester");
        router.submitBurnRequest(br);

        br = BurnRequest(
            10e18,
            10e18,
            MockERC20(address(0)),
            address(this),
            block.timestamp + 1 days
        );
        vm.expectRevert("Eth withdraw is not allowed");
        router.submitBurnRequest(br);

        deal(address(vault), address(this), 10e18);
        br = BurnRequest(
            10e18,
            10e18,
            jonesToken,
            address(this),
            block.timestamp + 1 days
        );
        vm.expectRevert("ERC20: insufficient allowance");
        router.submitBurnRequest(br);

        vault.approve(address(router), 10e18);
        for (uint256 i = 1; i <= 100; i++) {
            br = BurnRequest(
                10e18 / 1000,
                10e18 / 1000,
                jonesToken,
                address(this),
                block.timestamp + 1 days
            );
            router.submitBurnRequest(br);

            assertEq(
                vault.balanceOf(address(router)),
                ((10e18 * i) / 1000),
                "!ALP blanace"
            );
            assertEq(router.burnQueueBack(), i, "!burnQueueBack");
        }
        assertEq(router.burnQueueFront(), 1, "!burnQueueFront");

        vm.expectRevert("Burn queue limited");
        router.submitBurnRequest(br);
    }

    function testRefundMintRequest() public {
        vm.expectRevert("No mint request");
        router.refundMintRequest();

        MintRequest memory mr = MintRequest(
            10e18,
            1000000000000,
            jonesToken,
            address(this),
            block.timestamp
        );
        jonesToken.approve(address(router), 10e18);
        router.submitMintRequest(mr);

        assertEq(jonesToken.balanceOf(address(router)), 10e18);

        vm.expectRevert("Not a permitted user");
        router.refundMintRequest();

        vm.startPrank(whale);
        router.refundMintRequest();

        assertEq(jonesToken.balanceOf(address(router)), 0);
        assertEq(jonesToken.balanceOf(address(this)), 10e18);
        vm.stopPrank();

        mr = MintRequest(
            10e18,
            1000000000000,
            jonesToken,
            address(this),
            block.timestamp
        );
        jonesToken.approve(address(router), 10e18);
        router.submitMintRequest(mr);

        vm.warp(block.timestamp + 1 days);

        router.refundMintRequest();

        assertEq(router.mintQueueBack(), 0, "!mintQueueBack");
        assertEq(router.mintQueueFront(), 0, "!mintQueueFront");

        assertEq(jonesToken.balanceOf(address(router)), 0);
        assertEq(jonesToken.balanceOf(address(this)), 10e18);
    }

    function testRefundBurnRequest() public {
        vm.expectRevert("No burn request");
        router.refundBurnRequest();

        deal(address(vault), address(this), 10e18);

        BurnRequest memory br = BurnRequest(
            10e18,
            10e18,
            jonesToken,
            address(this),
            block.timestamp
        );
        vault.approve(address(router), 10e18);
        router.submitBurnRequest(br);

        assertEq(vault.balanceOf(address(router)), 10e18);

        vm.expectRevert("Not a permitted user");
        router.refundBurnRequest();

        vm.startPrank(whale);
        router.refundBurnRequest();

        assertEq(vault.balanceOf(address(router)), 0);
        assertEq(vault.balanceOf(address(this)), 10e18);
        vm.stopPrank();

        br = BurnRequest(
            10e18,
            10e18,
            jonesToken,
            address(this),
            block.timestamp
        );
        vault.approve(address(router), 10e18);
        router.submitBurnRequest(br);

        vm.warp(block.timestamp + 1 days);

        router.refundBurnRequest();

        assertEq(router.burnQueueBack(), 0, "!burnQueueBack");
        assertEq(router.burnQueueFront(), 0, "!burnQueueFront");

        assertEq(vault.balanceOf(address(router)), 0);
        assertEq(vault.balanceOf(address(this)), 10e18);
    }

    function testRescueStuckTokens() public {
        vm.startPrank(address(1));
        vm.expectRevert("Not a permitted user");
        router.rescueStuckTokens(jonesToken, 10e18);
        vm.stopPrank();

        vm.startPrank(whale);
        router.setFee(0.1e18);

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

        CoinPriceUSD[] memory x = new CoinPriceUSD[](2);
        x[0] = CoinPriceUSD(address(0), 1600e4);
        x[1] = CoinPriceUSD(address(jonesToken), 20e4);
        assertEq(feeOracle.getTargets()[0].coin, x[0].coin);

        /// process mint request in the queue
        router.processMintRequest(OracleParams(x, block.timestamp + 1 days));

        assertEq(router.mintQueueBack(), 0, "!mintQueueBack");
        assertEq(router.mintQueueFront(), 0, "!mintQueueFront");

        vm.expectRevert("Too much amount to rescue");
        router.rescueStuckTokens(jonesToken, 10e18);

        uint256 beforeWhaleBalance = jonesToken.balanceOf(whale);
        router.rescueStuckTokens(jonesToken, 10e18 / 100);
        assertEq(
            jonesToken.balanceOf(whale),
            10e18 / 100 + beforeWhaleBalance,
            "!joneToken whale balance after rescue"
        );
        assertEq(
            jonesToken.balanceOf(address(router)),
            0.9e18,
            "!joneToken router balance after rescue"
        );
        vm.stopPrank();
    }

    function testSuicide() public {
        vm.expectRevert("Not a permitted user");
        router.suicide();

        vm.startPrank(whale);

        vm.deal(address(router), 1e18);
        vm.expectRevert("Too many eth");
        router.suicide();

        vm.deal(address(router), 0);

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

        vm.expectRevert("Mint queue is not empty");
        router.suicide();

        router.refundMintRequest();

        deal(address(vault), whale, 10e18);
        vault.approve(address(router), 10e18);
        BurnRequest memory br = BurnRequest(
            mockCoin1Balance,
            mockCoin1Balance,
            jonesToken,
            whale,
            block.timestamp + 1 days
        );
        router.submitBurnRequest(br);

        vm.expectRevert("Burn queue is not empty");
        router.suicide();

        router.refundBurnRequest();

        router.suicide();

        vm.stopPrank();
    }

    function testProcessMintRequest() public {
        CoinPriceUSD[] memory x = new CoinPriceUSD[](2);
        x[0] = CoinPriceUSD(address(1), 1600e4);
        x[1] = CoinPriceUSD(address(jonesToken), 20e4);

        OracleParams memory op = OracleParams(x, block.timestamp + 1 days);
        vm.expectRevert("Invalid coin for oracle");
        router.processMintRequest(op);

        x[0] = CoinPriceUSD(address(0), 1600e4);
        op = OracleParams(x, block.timestamp + 1 days);
        vm.expectRevert("Not a permitted user");
        router.processMintRequest(op);

        vm.startPrank(whale);

        vm.expectRevert("No mint request");
        router.processMintRequest(op);
        router.setFee(0.1e18);

        jonesToken.approve(address(router), mockCoin1Balance);

        /// submit mint request to the router
        router.submitMintRequest(
            MintRequest(
                mockCoin1Balance,
                1000000000000,
                jonesToken,
                whale,
                block.timestamp
            )
        );

        vm.warp(block.timestamp + 10);

        vm.expectRevert("Request expired");
        router.processMintRequest(op);

        router.refundMintRequest();

        jonesToken.approve(address(router), mockCoin1Balance);

        /// submit mint request to the router
        router.submitMintRequest(
            MintRequest(
                mockCoin1Balance,
                mockCoin1Balance,
                jonesToken,
                whale,
                block.timestamp + 1 days
            )
        );

        vm.expectRevert("Not enough ALP minted");
        router.processMintRequest(op);

        router.refundMintRequest();

        jonesToken.approve(address(router), mockCoin1Balance);

        router.submitMintRequest(
            MintRequest(
                mockCoin1Balance,
                1000000000000,
                jonesToken,
                whale,
                block.timestamp + 1 days
            )
        );

        vm.mockCall(
            address(jonesToken),
            abi.encodeWithSelector(
                IERC20.transfer.selector,
                address(vault),
                (mockCoin1Balance * 0.9e18) / 1e18
            ),
            abi.encode(false)
        );

        vm.expectRevert("Coin transfer failed");
        router.processMintRequest(op);

        router.refundMintRequest();
        vm.clearMockedCalls();

        jonesToken.approve(address(router), mockCoin1Balance);

        router.submitMintRequest(
            MintRequest(
                mockCoin1Balance,
                1000000000000,
                jonesToken,
                whale,
                block.timestamp + 1 days
            )
        );

        vm.mockCall(
            address(vault),
            abi.encodeWithSelector(IERC20.transfer.selector),
            abi.encode(false)
        );

        vm.expectRevert("ALP transfer failed");
        router.processMintRequest(op);

        vm.clearMockedCalls();

        vm.stopPrank();
    }

    function testProcessBurnRequest() public {
        CoinPriceUSD[] memory x = new CoinPriceUSD[](2);
        x[0] = CoinPriceUSD(address(1), 1600e4);
        x[1] = CoinPriceUSD(address(jonesToken), 20e4);

        OracleParams memory op = OracleParams(x, block.timestamp + 1 days);
        vm.expectRevert("Invalid coin for oracle");
        router.processBurnRequest(op);

        x[0] = CoinPriceUSD(address(0), 1600e4);
        op = OracleParams(x, block.timestamp + 1 days);
        vm.expectRevert("Not a permitted user");
        router.processBurnRequest(op);

        vm.startPrank(whale);

        vm.expectRevert("No burn request");
        router.processBurnRequest(op);
        router.setFee(0.1e18);

        deal(address(vault), whale, 10e18);

        BurnRequest memory br = BurnRequest(
            10e18,
            10e18,
            jonesToken,
            whale,
            block.timestamp
        );
        vault.approve(address(router), 10e18);
        router.submitBurnRequest(br);

        vm.warp(block.timestamp + 10);

        vm.expectRevert("Request expired");
        router.processBurnRequest(op);

        router.refundBurnRequest();

        jonesToken.approve(address(router), 10e18);

        router.submitMintRequest(
            MintRequest(
                10e18,
                1000000000000,
                jonesToken,
                whale,
                block.timestamp + 1 days
            )
        );
        router.processMintRequest(op);

        deal(address(vault), address(router), 10e18);

        br = BurnRequest(
            1e15,
            1e18,
            jonesToken,
            whale,
            block.timestamp + 1 days
        );
        vault.approve(address(router), 10e18);
        router.submitBurnRequest(br);

        vm.expectRevert("Too much ALP burned");
        router.processBurnRequest(op);

        router.refundBurnRequest();

        br = BurnRequest(
            1e18,
            1e18,
            jonesToken,
            whale,
            block.timestamp + 1 days
        );
        vault.approve(address(router), 10e18);
        router.submitBurnRequest(br);

        vm.mockCall(
            address(jonesToken),
            abi.encodeWithSelector(IERC20.transfer.selector, whale, 1e18),
            abi.encode(false)
        );

        vm.expectRevert("Coin transfer failed");
        router.processBurnRequest(op);

        router.refundBurnRequest();

        vm.clearMockedCalls();

        br = BurnRequest(
            1e18,
            1e18,
            jonesToken,
            whale,
            block.timestamp + 1 days
        );
        vault.approve(address(router), 10e18);
        router.submitBurnRequest(br);

        vm.mockCall(
            address(vault),
            abi.encodeWithSelector(IERC20.transfer.selector),
            abi.encode(false)
        );

        vm.expectRevert("ALP transfer failed");
        router.processBurnRequest(op);

        vm.clearMockedCalls();

        vm.stopPrank();
    }
}
