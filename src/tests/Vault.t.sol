// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;
import "forge-std/Test.sol";
import "@mocks/MockERC20.sol";
import "@/FactoryArbitrove.sol";
import "../../script/FactoryArbitrove.s.sol";

struct MintRequest{
    uint256 inputTokenAmount;
    uint256 minAlpAmount;
    IERC20 coin;
    address requester;
    uint256 expire;
}

interface Router {
    function submitMintRequest(MintRequest calldata mr) external;
}

contract VaultTest is Test, VyperDeployer {
    Vault vault;
    MockERC20 public jonesToken;
    Router router;

    function setUp() public {
        address someRandomUser = vm.addr(1);
        vm.startPrank(someRandomUser);
        vm.deal(someRandomUser, 1 ether);

        FactoryArbitrove factory = new FactoryArbitrove();
        router = Router(deployContract("src/contracts/Router.vy"));
        AddressRegistry(factory.addressRegistryAddress()).init(IVault(factory.vaultAddress()), FeeOracle(factory.feeOracleAddress()), address(router));
        Vault(payable(factory.vaultAddress())).init{value: 1e18}(AddressRegistry(factory.addressRegistryAddress()));
        FeeOracle(factory.feeOracleAddress()).init(AddressRegistry(factory.addressRegistryAddress()), 20, 0);

        vault = Vault(payable(factory.vaultAddress()));
        jonesToken = new MockERC20("Jones Token", "JONES");
        jonesToken.mint(someRandomUser, 1e18);
    }

    function test_setup() public {
        address someRandomUser = vm.addr(1);
        assertEq(vault.balanceOf(someRandomUser), 1e18);
    }

    function testDeposit() public {
        jonesToken.approve(address(router), 1e18);
        router.submitMintRequest(MintRequest(1e18, 1e18, jonesToken, vm.addr(1), block.timestamp + 1 hours));
    }
}
