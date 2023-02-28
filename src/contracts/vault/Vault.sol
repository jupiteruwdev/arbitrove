// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@vault/IVault.sol";
import "@strategy/IStrategy.sol";
import "@/AddressRegistry.sol";
import "@structs/structs.sol";

// TODO: add snapshot capabilities

contract Vault is OwnableUpgradeable, IVault, ERC20Upgradeable {

  AddressRegistry addressRegistry;
  mapping(address => uint) coinCap;
  mapping(uint => uint) blockCapCounter;
  // only process certain amount of tx in USD per block
  uint256 public blockCapUSD;

  function init(AddressRegistry _addressRegistry) initializer payable external {
    __Ownable_init();
    __ERC20_init("ALP", "ALP");
    addressRegistry = _addressRegistry;
    require(msg.value >= 1e17);
    _mint(msg.sender, 1e18);
  }

  function setCoinCapUSD(address coin, uint cap) external{
    coinCap[coin] = cap;
  }

  function setBlockCap(uint cap) external{
    blockCapUSD = cap;
  }

  function getAmountAcrossStrategies(address coin) override public view returns (uint256 value) {
    if (coin == address(0)) {
      value += address(this).balance;
    } else {
      value += ERC20(coin).balanceOf(address(this));
    }
    IStrategy[] memory strategies = addressRegistry.getCoinToStrategy(coin);
    for (uint i; i < strategies.length;) {
      value += strategies[i].getComponentAmount(coin);
      unchecked {
        i++;
      }
    }
  }

  function deposit(uint256 coinPositionInCPU, uint256 _amount, CoinPriceUSD[] calldata cpu, uint256 expireTimestamp, bytes32 nonce, bytes32 r, bytes32 s, uint8 v) external payable {
    require(tx.origin == msg.sender, "No contracts please");
    address coin = cpu[coinPositionInCPU].coin;
    uint256 amount = coin == address(0) ? msg.value : _amount;
    require(getAmountAcrossStrategies(coin) + amount < coinCap[coin]);
    uint256 newTvlUSD10000X = cpu[coinPositionInCPU].price * _amount / 10**ERC20(cpu[coinPositionInCPU].coin).decimals();
    require(newTvlUSD10000X + blockCapCounter[block.number] < blockCapUSD);
    blockCapCounter[block.number] += newTvlUSD10000X;
    (int256 fee, , uint256 tvlUSD10000X) = addressRegistry.feeOracle().getDepositFee(cpu, this, expireTimestamp,nonce, r, s, v, coinPositionInCPU, _amount);
    uint256 poolRatio = newTvlUSD10000X * 10000 / (newTvlUSD10000X + tvlUSD10000X);
    _mint(msg.sender, poolRatio * totalSupply() / (10000 - poolRatio) / 10000 * uint256(100 - fee) / 100);
  }

  function withdrawal(uint256 coinPositionInCPU, uint256 _amount, CoinPriceUSD[] calldata cpu, uint256 expireTimestamp, bytes32 nonce, bytes32 r, bytes32 s, uint8 v) external payable {
    require(tx.origin == msg.sender, "No contracts please");
    address coin = cpu[coinPositionInCPU].coin;
    uint256 amount = coin == address(0) ? msg.value : _amount;
    uint256 lessTvlUSD10000X = cpu[coinPositionInCPU].price * _amount / 10**ERC20(cpu[coinPositionInCPU].coin).decimals();
    require(lessTvlUSD10000X + blockCapCounter[block.number] < blockCapUSD);
    blockCapCounter[block.number] += lessTvlUSD10000X;
    require(getAmountAcrossStrategies(coin) + amount < coinCap[coin]);
    (int256 fee, , uint256 tvlUSD10000X) = addressRegistry.feeOracle().getWithdrawalFee(cpu, this, expireTimestamp,nonce, r, s, v, coinPositionInCPU, _amount);
    
    uint256 poolRatio = lessTvlUSD10000X * 10000 / (tvlUSD10000X);
    _burn(msg.sender, poolRatio * totalSupply() / 10000 * uint256(100 + fee) / 100);
  }

  function approveStrategy(IStrategy strategy, address coin, uint256 amount) external onlyOwner {
    require(addressRegistry.getStrategyWhitelisted(strategy));
    IERC20(coin).approve(address(strategy), amount);
  }

  function depositETHToStrategy(IStrategy strategy, uint256 amount) external onlyOwner {
    require(addressRegistry.getStrategyWhitelisted(strategy));
    address(strategy).call{value: amount}("");
  }

  receive() external payable {

  }
}