enum PairType {
    USDC,
    WETH
}

struct CoinPriceUSD {
    address coin;
    uint256 price;
}

struct CoinWeight {
    address coin;
    uint256 weight;
}

struct CoinValue{
    address coin;
    uint256 value;
}