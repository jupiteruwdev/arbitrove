// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Test.sol";

import "@mocks/MockERC20.sol";

import "@mocks/MockStrategy.sol";

import "../../script/FactoryArbitrove.s.sol";

contract FeeOracleTest is Test, VyperDeployer {
    Vault public vault;
    MockERC20 public jonesToken;
    Router public router;
    AddressRegistry public ar;
    FeeOracle public feeOracle;

    function setUp() public {
        /// pre required contracts deployments
        FactoryArbitrove factory = new FactoryArbitrove();
        factory.upgradeImplementation(
            TProxy(payable(factory.vaultAddress())),
            address(new Vault())
        );
        jonesToken = new MockERC20("Jones Token", "JONES");

        feeOracle = FeeOracle(factory.feeOracleAddress());

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
        Vault(payable(factory.vaultAddress())).init829{value: 1e18}(
            AddressRegistry(factory.addressRegistryAddress())
        );
        FeeOracle(factory.feeOracleAddress()).init(0.07e18);

        /// setting up initial data
        CoinWeight[] memory cw = new CoinWeight[](2);

        feeOracle = FeeOracle(factory.feeOracleAddress());
        vault = Vault(payable(factory.vaultAddress()));
        /// set vault pool ratio denominator
        jonesToken = new MockERC20("Jones Token", "JONES");
        jonesToken.mint(address(this), 100e18);
        jonesToken.mint(address(vault), 10e18);
        vault.setCoinCapUSD(address(jonesToken), 1000e18);
        vault.setBlockCap(100000e18);
        ExampleStrategy st = new ExampleStrategy();
        address[] memory x = new address[](1);
        x[0] = address(jonesToken);
        AddressRegistry(factory.addressRegistryAddress()).addStrategy(st, x);
    }

    function testInit() public {
        FactoryArbitrove factory = new FactoryArbitrove();
        factory.upgradeImplementation(
            TProxy(payable(factory.vaultAddress())),
            address(new Vault())
        );

        FeeOracle _feeOracle = FeeOracle(factory.feeOracleAddress());

        vm.expectRevert("_maxFee can't be greater than 0.5e18");
        FeeOracle(address(_feeOracle)).init(0.7e18);

        FeeOracle(address(_feeOracle)).init(0.07e18);
    }

    function testSetMaxFee() public {
        vm.expectRevert("_maxFee can't be greater than 0.5e18");
        feeOracle.setMaxFee(0.7e18);

        feeOracle.setMaxFee(0.1e18);
        assertEq(feeOracle.maxFee(), 0.1e18, "!maxFee");
    }

    function testIsInTarget() public {
        assertEq(feeOracle.isInTarget(address(1)), false, "!isInTarget");
    }

    function testGetCoinWeights() public {
        CoinPriceUSD[] memory x = new CoinPriceUSD[](2);
        x[0] = CoinPriceUSD(address(0), 1600e4);
        x[1] = CoinPriceUSD(address(jonesToken), 20e4);

        CoinWeightsParams memory params = CoinWeightsParams({
            cpu: x,
            vault: IVault(address(1)),
            expireTimestamp: block.timestamp
        });

        vm.expectRevert("Execution window passed");
        feeOracle.getCoinWeights(params);

        params.expireTimestamp = block.timestamp + 1 days;

        vm.expectRevert("Oracle length error");
        feeOracle.getCoinWeights(params);

        x[1] = CoinPriceUSD(address(0), 1600e4);
        x[0] = CoinPriceUSD(address(jonesToken), 20e4);

        CoinWeight[] memory cw = new CoinWeight[](2);
        cw[0] = CoinWeight(address(0), 0.5e18);
        cw[1] = CoinWeight(address(jonesToken), 0.5e18);

        feeOracle.setTargets(cw);

        params = CoinWeightsParams({
            cpu: x,
            vault: IVault(address(1)),
            expireTimestamp: block.timestamp + 1 days
        });

        vm.expectRevert("Oracle order error");
        feeOracle.getCoinWeights(params);
    }

    function testSetTargets() public {
        CoinWeight[] memory weights = new CoinWeight[](51);
        vm.expectRevert("too many weights");
        feeOracle.setTargets(weights);

        CoinWeight[] memory weights1 = new CoinWeight[](2);
        weights1[0] = CoinWeight(address(0), 0.4e18);
        weights1[1] = CoinWeight(address(jonesToken), 0.6e18);

        feeOracle.setTargets(weights1);

        (address coin1, ) = feeOracle.targets(0);
        (address coin2, ) = feeOracle.targets(1);

        assertEq(coin1, weights1[0].coin, "!1.coin");
        assertEq(coin2, weights1[1].coin, "!2.coin");

        weights1[0] = CoinWeight(address(0), 0.4e18);
        weights1[1] = CoinWeight(address(jonesToken), 0.5e18);

        vm.expectRevert("Weight error");
        feeOracle.setTargets(weights1);

        weights1[0] = CoinWeight(address(0), 0.4e18);
        weights1[1] = CoinWeight(address(jonesToken), 0.7e18);

        vm.expectRevert("Weight error 2");
        feeOracle.setTargets(weights1);
    }

    function testGetDepositWithdrawalFee() public {
        CoinWeight[] memory cw = new CoinWeight[](2);
        cw[0] = CoinWeight(address(0), 0.7e18);
        cw[1] = CoinWeight(address(jonesToken), 0.3e18);

        feeOracle.setTargets(cw);

        cw[0] = CoinWeight(address(0), 0.5e18);
        cw[1] = CoinWeight(address(jonesToken), 0.5e18);

        CoinPriceUSD[] memory x = new CoinPriceUSD[](2);
        x[0] = CoinPriceUSD(address(0), 1600e4);
        x[1] = CoinPriceUSD(address(jonesToken), 20e4);

        jonesToken.approve(address(router), 100e18);

        /// submit mint request to the router
        router.submitMintRequest(
            MintRequest(
                100e18,
                1000000000000,
                jonesToken,
                address(this),
                block.timestamp + 1 days
            )
        );

        router.processMintRequest(OracleParams(x, block.timestamp + 1 days));

        cw[0] = CoinWeight(address(0), 0.8e18);
        cw[1] = CoinWeight(address(jonesToken), 0.2e18);
        feeOracle.setTargets(cw);

        FeeParams memory params = FeeParams(
            x,
            vault,
            block.timestamp + 1 days,
            1,
            1e18
        );

        vm.expectRevert("Too far away from target");
        feeOracle.getDepositFee(params);

        cw[0] = CoinWeight(address(0), 1e18);
        cw[1] = CoinWeight(address(jonesToken), 0e18);
        feeOracle.setTargets(cw);

        // disable deposit when target weight is zero
        vm.expectRevert("Too far away from target");
        feeOracle.getDepositFee(params);

        cw[0] = CoinWeight(address(0), 0.8e18);
        cw[1] = CoinWeight(address(jonesToken), 0.2e18);
        feeOracle.setTargets(cw);

        deal(address(vault), address(this), 100e18);

        vault.approve(address(router), 100e18);

        /// submit burn request to the router
        router.submitBurnRequest(
            BurnRequest(
                100e18,
                100e18,
                jonesToken,
                address(this),
                block.timestamp + 1 days
            )
        );

        router.processBurnRequest(OracleParams(x, block.timestamp + 1 days));

        cw[0] = CoinWeight(address(0), 0.99e18);
        cw[1] = CoinWeight(address(jonesToken), 0.01e18);
        feeOracle.setTargets(cw);

        vm.expectRevert("Too far away from target");
        feeOracle.getWithdrawalFee(params);

        cw[0] = CoinWeight(address(0), 1e18);
        cw[1] = CoinWeight(address(jonesToken), 0e18);
        feeOracle.setTargets(cw);

        (int256 withdrawalFee, , ) = feeOracle.getWithdrawalFee(params);
        assertEq(
            withdrawalFee,
            0,
            "!withdrawal fee should be zero when target is zero"
        );
    }
}
