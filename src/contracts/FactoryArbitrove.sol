pragma solidity 0.8.17;

import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "@vault/Vault.sol";
import "@/AddressRegistry.sol";
import "@/Rebalancer.sol";
import "@/TProxy.sol";

contract FactoryArbitrove is Ownable {
    address public addressRegistryAddress;
    address public vaultAddress;
    address public feeOracleAddress;
    address public rebalancerAddress;

    constructor() {
        AddressRegistry ar = new AddressRegistry();
        // ar.init(address(0), IVault(address(0)), FeeOracle(address(0)), address(0));
        TProxy arProxy = new TProxy(address(ar), address(this), "");
        addressRegistryAddress = address(arProxy);
        Vault v = new Vault();
        FeeOracle fO = new FeeOracle();
        Rebalancer rb = new Rebalancer();
        TProxy vProxy = new TProxy(address(v), address(this), "");
        TProxy fOProxy = new TProxy(address(fO), address(this), "");
        TProxy rbProxy = new TProxy(address(rb), address(this), "");
        vaultAddress = address(vProxy);
        feeOracleAddress = address(fOProxy);
        rebalancerAddress = address(rbProxy);
    }

    function upgradeImplementation(
        TProxy proxy,
        address newImplementation
    ) external onlyOwner {
        proxy.upgradeTo(newImplementation);
    }
}
