pragma solidity 0.8.17;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@/vault/FeeOracle.sol";
import "@/FactoryArbitrove.sol";
import "@/FactoryTokens.sol";

contract SetTargets is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        FactoryArbitrove factory = FactoryArbitrove(
            0x24d1aBfB33B546d11e2947928368304190ad3C2E
        );
        CoinWeight[] memory weights = new CoinWeight[](2);
        weights[0] = CoinWeight(address(0), 50);
        weights[1] = CoinWeight(0xf531B8F309Be94191af87605CfBf600D71C2cFe0, 50);
        FeeOracle(factory.feeOracleAddress()).setTargets(weights);

        vm.stopBroadcast();
    }
}
