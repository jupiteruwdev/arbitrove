// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@vault/IVault.sol";
import "@strategy/IStrategy.sol";
import "@/AddressRegistry.sol";
import "@structs/structs.sol";

contract Vault is OwnableUpgradeable, IVault, ERC20Upgradeable {

  AddressRegistry addressRegistry;
  mapping(address => uint) coinCap;
  mapping(uint => uint) blockCapCounter;
  // only process certain amount of tx in USD per block
  uint256 public blockCapUSD;
  mapping(address => uint) public debt;

    constructor() {
      _disableInitializers();
    }

  function init829(AddressRegistry _addressRegistry) initializer payable external {
    __Ownable_init();
    __ERC20_init("ALP", "ALP");
    addressRegistry = _addressRegistry;
    require(msg.value >= 1e15);
    _mint(msg.sender, msg.value);
  }

  function setAddressRegistry(AddressRegistry _addressRegistry) external onlyOwner {
    addressRegistry = _addressRegistry;
  }

  function setCoinCapUSD(address coin, uint cap) external onlyOwner{
    coinCap[coin] = cap;
  }

  function setBlockCap(uint cap) external onlyOwner {
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

  struct DepositParams {
    uint256 coinPositionInCPU;
    uint256 _amount;
    CoinPriceUSD[] cpu;
    uint256 expireTimestamp;
  }

  function deposit(DepositParams memory params) external payable {
    DepositFeeParams memory depositFeeParams = DepositFeeParams({
      cpu: params.cpu,
      vault: this,
      expireTimestamp: params.expireTimestamp,
      position: params.coinPositionInCPU,
      amount: params._amount
    });
    require(msg.sender == addressRegistry.router());
    address coin = params.cpu[params.coinPositionInCPU].coin;
    uint256 amount = coin == address(0) ? msg.value : params._amount;
    uint256 __decimals = coin == address(0) ? 18 : ERC20(coin).decimals();
    require(getAmountAcrossStrategies(coin) + amount < coinCap[coin], "Coin cap reached");
    
    uint256 newTvlUSD10000X = params.cpu[params.coinPositionInCPU].price * params._amount / 10**__decimals;
    require(newTvlUSD10000X + blockCapCounter[block.number] < blockCapUSD, "Block cap reached");
    blockCapCounter[block.number] += newTvlUSD10000X;
    (int256 fee, , uint256 tvlUSD10000X) = addressRegistry.feeOracle().getDepositFee(depositFeeParams);
    uint256 poolRatio = newTvlUSD10000X * 10000 / (newTvlUSD10000X + tvlUSD10000X);
    _mint(msg.sender, poolRatio * totalSupply() / (10000 - poolRatio) / 10000 * uint256(100 - fee) / 100);
  }

  struct WithdrawalParams {
    uint256 coinPositionInCPU;
    uint256 _amount;
    CoinPriceUSD[] cpu;
    uint256 expireTimestamp;
  }

  function withdraw(WithdrawalParams memory params) external payable {
    WithdrawalFeeParams memory withdrawalFeeParams = WithdrawalFeeParams({
      cpu: params.cpu,
      vault: this,
      expireTimestamp: params.expireTimestamp,
      position: params.coinPositionInCPU,
      amount: params._amount
    });
    require(msg.sender == addressRegistry.router());
    address coin = params.cpu[params.coinPositionInCPU].coin;
    uint256 amount = coin == address(0) ? msg.value : params._amount;
    uint256 __decimals = coin == address(0) ? 18 : ERC20(coin).decimals();
    uint256 lessTvlUSD10000X = params.cpu[params.coinPositionInCPU].price * params._amount / 10**__decimals;
    require(lessTvlUSD10000X + blockCapCounter[block.number] < blockCapUSD, "Block cap reached");
    blockCapCounter[block.number] += lessTvlUSD10000X;
    require(getAmountAcrossStrategies(coin) + amount < coinCap[coin], "Coin cap reached");
    (int256 fee, , uint256 tvlUSD10000X) = addressRegistry.feeOracle().getWithdrawalFee(withdrawalFeeParams);
    // uint256 poolRatio = lessTvlUSD10000X * 10000 / (tvlUSD10000X);
    // _burn(msg.sender, poolRatio * totalSupply() / 10000 * uint256(100 + fee) / 100);
    debt[coin] += amount;
  }

  function claimDebt(address coin, uint256 amount) external {
    require(msg.sender == addressRegistry.router());
    debt[coin] -= amount;
    require(IERC20(coin).transfer(msg.sender, amount));
  }

  function approveStrategy(IStrategy strategy, address coin, uint256 amount) external onlyOwner {
    require(addressRegistry.getWhitelistedStrategies(strategy));
    IERC20(coin).approve(address(strategy), amount);
  }

  function depositETHToStrategy(IStrategy strategy, uint256 amount) external onlyOwner {
    require(addressRegistry.getWhitelistedStrategies(strategy));
    (bool depositSuccess,) = address(strategy).call{value: amount}("");
    require(depositSuccess, "Deposit failed");
  }

  function rebalance(address coin, uint256 amount) external onlyOwner {
    require(IERC20(coin).transfer(msg.sender, amount));
  }

  receive() external payable {

  }
}