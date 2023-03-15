// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@vault/IVault.sol";
import "@strategy/IStrategy.sol";
import "@/AddressRegistry.sol";
import "@structs/structs.sol";

contract Vault is OwnableUpgradeable, IVault, ERC20Upgradeable {
    struct DepositParams {
        uint256 coinPositionInCPU;
        uint256 _amount;
        CoinPriceUSD[] cpu;
        uint256 expireTimestamp;
    }

    struct WithdrawalParams {
        uint256 coinPositionInCPU;
        uint256 _amount;
        CoinPriceUSD[] cpu;
        uint256 expireTimestamp;
    }

    AddressRegistry public addressRegistry;
    /// USD price cap for coin
    /// only process certain amount of USD per coin
    mapping(address => uint256) public coinCap;
    /// block cap USD for block number
    mapping(uint => uint256) public blockCapCounter;
    /// only process certain amount of tx in USD per block
    uint256 public blockCapUSD;
    /// claimable debt amount for routers
    mapping(address => uint256) public debt;
    /// pool ratio denominator for pool ratio calculation
    uint256 public poolRatioDenominator;

    event SET_ADDRESS_REGISTRY(AddressRegistry);

    constructor() {
        _disableInitializers();
    }

    receive() external payable {}

    modifier onlyRouter() {
        require(
            msg.sender == addressRegistry.router(),
            "only router has permitted"
        );
        _;
    }

    function init829(
        AddressRegistry _addressRegistry
    ) external payable initializer {
        require(
            address(_addressRegistry) != address(0),
            "_addressRegistry address can't be zero"
        );
        require(msg.value >= 1e15);

        __Ownable_init();
        __ERC20_init("ALP", "ALP");
        addressRegistry = _addressRegistry;
        _mint(msg.sender, msg.value);
        poolRatioDenominator = 1e18;
    }

    /// @notice Set addressRegistry
    /// @param _addressRegistry Address registry contract
    function setAddressRegistry(
        AddressRegistry _addressRegistry
    ) external onlyOwner {
        require(
            address(_addressRegistry) != address(0),
            "_addressRegistry address can't be zero"
        );

        addressRegistry = _addressRegistry;

        emit SET_ADDRESS_REGISTRY(_addressRegistry);
    }

    /// @notice Set coin cap usd
    /// @param coin Address of coin to set cap
    /// @param cap Amount of cap to set
    function setCoinCapUSD(address coin, uint256 cap) external onlyOwner {
        coinCap[coin] = cap;
    }

    /// @notice Set block cap for vault
    /// @param cap Amount of cap to set
    function setBlockCap(uint256 cap) external onlyOwner {
        blockCapUSD = cap;
    }

    function deposit(DepositParams memory params) external payable onlyRouter {
        DepositFeeParams memory depositFeeParams = DepositFeeParams({
            cpu: params.cpu,
            vault: this,
            expireTimestamp: params.expireTimestamp,
            position: params.coinPositionInCPU,
            amount: params._amount
        });
        address coin = params.cpu[params.coinPositionInCPU].coin;
        uint256 amount = coin == address(0) ? msg.value : params._amount;
        uint256 __decimals = coin == address(0)
            ? 18
            : IERC20Metadata(coin).decimals();
        require(
            getAmountAcrossStrategies(coin) + amount < coinCap[coin],
            "Coin cap reached"
        );

        uint256 newTvlUSD10000X = (params.cpu[params.coinPositionInCPU].price *
            params._amount) / 10 ** __decimals;
        require(
            newTvlUSD10000X + blockCapCounter[block.number] < blockCapUSD,
            "Block cap reached"
        );
        blockCapCounter[block.number] += newTvlUSD10000X;
        (int256 fee, , uint256 tvlUSD10000X) = addressRegistry
            .feeOracle()
            .getDepositFee(depositFeeParams);
        uint256 poolRatio = (newTvlUSD10000X * poolRatioDenominator) /
            tvlUSD10000X;

        /// vault token mint
        /// fomula: poolRatio * totalSupply / (poolRatio denomiator) * (100 - fee) / (fee decominator)
        _mint(
            msg.sender,
            (((poolRatio * totalSupply()) / poolRatioDenominator) *
                uint256(100 - fee)) / 100
        );
    }

    function withdraw(
        WithdrawalParams memory params
    ) external payable onlyRouter {
        WithdrawalFeeParams memory withdrawalFeeParams = WithdrawalFeeParams({
            cpu: params.cpu,
            vault: this,
            expireTimestamp: params.expireTimestamp,
            position: params.coinPositionInCPU,
            amount: params._amount
        });
        address coin = params.cpu[params.coinPositionInCPU].coin;
        uint256 amount = coin == address(0) ? msg.value : params._amount;
        uint256 __decimals = coin == address(0)
            ? 18
            : IERC20Metadata(coin).decimals();
        uint256 lessTvlUSD10000X = (params.cpu[params.coinPositionInCPU].price *
            params._amount) / 10 ** __decimals;
        require(
            lessTvlUSD10000X + blockCapCounter[block.number] < blockCapUSD,
            "Block cap reached"
        );
        blockCapCounter[block.number] += lessTvlUSD10000X;
        require(
            getAmountAcrossStrategies(coin) + amount < coinCap[coin],
            "Coin cap reached"
        );
        (int256 fee, , uint256 tvlUSD10000X) = addressRegistry
            .feeOracle()
            .getWithdrawalFee(withdrawalFeeParams);
        uint256 poolRatio = (lessTvlUSD10000X * poolRatioDenominator) /
            tvlUSD10000X;

        /// burn vault token
        /// formula: poolRatio * totalSupply * (100 + fee) / 100 (fee decominator) / 10000 (poolRatio denomiator)
        _burn(
            msg.sender,
            (((poolRatio * totalSupply()) / poolRatioDenominator) *
                uint256(100 + fee)) / 100
        );

        /// increase claimable debt amount for withdrawing amount of coin
        debt[coin] += amount;
    }

    /// @notice Claim `amount` debt from vault
    /// @param coin Address of coin to claim
    /// @param amount Amount of debt to claim
    function claimDebt(address coin, uint256 amount) external onlyRouter {
        require(debt[coin] >= amount, "insufficient debt amount for coin");
        debt[coin] -= amount;
        require(IERC20(coin).transfer(msg.sender, amount));
    }

    /// @notice Approve `amount` of coin for strategy to use
    /// @param strategy Address of Strategy
    /// @param coin Address of coin
    /// @param amount Amount of coin to approve
    function approveStrategy(
        IStrategy strategy,
        address coin,
        uint256 amount
    ) external onlyOwner {
        require(
            addressRegistry.getWhitelistedStrategies(strategy),
            "strategy is not whitelisted"
        );

        /// verify coin is part of the strategy
        IStrategy[] memory strategies = addressRegistry.getCoinToStrategy(coin);
        uint256 i;
        for (; i < strategies.length; i++) {
            if (address(strategies[i]) == address(strategy)) break;
        }
        require(
            i == strategies.length,
            "provided coin is not the part of strategy"
        );

        /// approve coin for strategy
        require(
            IERC20(coin).approve(address(strategy), amount),
            "approve failed"
        );
    }

    function depositETHToStrategy(
        IStrategy strategy,
        uint256 amount
    ) external onlyOwner {
        require(addressRegistry.getWhitelistedStrategies(strategy));
        (bool depositSuccess, ) = address(strategy).call{value: amount}("");
        require(depositSuccess, "Deposit failed");
    }

    /// @notice Withdraw `amount` of coin from vault
    /// @param coin Address of coin
    /// @param amount Amount of coin to withdraw
    function rebalance(address coin, uint256 amount) external onlyOwner {
        require(IERC20(coin).transfer(msg.sender, amount));
    }

    /// @notice Get aggregated amount of coin for vault and strategies
    /// @param coin Address of coin
    /// @return value Aggregated amount of coin
    function getAmountAcrossStrategies(
        address coin
    ) public view returns (uint256 value) {
        if (coin == address(0)) {
            value += address(this).balance;
        } else {
            value += IERC20(coin).balanceOf(address(this));
        }
        IStrategy[] memory strategies = addressRegistry.getCoinToStrategy(coin);
        for (uint256 i; i < strategies.length; ) {
            value += strategies[i].getComponentAmount(coin);
            unchecked {
                i++;
            }
        }
    }
}
