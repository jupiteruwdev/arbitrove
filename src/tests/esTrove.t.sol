pragma solidity 0.8.17;

import "ds-test/test.sol";
import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "../contracts/tokens/esTrove.sol";

contract esTroveTest is DSTest {
    using SafeERC20Upgradeable for ERC20Upgradeable;

    esTROVE esTrove;
    address trove;
    address stakingAddress;
    uint256 maxStakes;

    function setUp() public {
        esTrove = new esTROVE();
        trove = address(0x2);
        stakingAddress = address(0x3);
        maxStakes = 1000;
    }

    function init_estrove() internal {
        esTrove.init(trove, maxStakes, stakingAddress);
        // esTrove.unpause();
    }
}
