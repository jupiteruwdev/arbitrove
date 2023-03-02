# Folder structure
```
.
├── src/
│   ├── contracts/
│   │   ├── farm (Out of scope)
│   │   ├── strategy
│   │   ├── vault
│   │   └── tokens (Out of scope)
│   ├── mocks (Out of scope)
│   ├── structs
│   └── tests
└── script (Out of scope)
```

`FactoryTokens.sol` under `contracts` is also out of scope for Arbitrove audit.

# General compiling and deployment

Install vyper first before running deployment scripts

## Deploy Single

> forge create --rpc-url <your_rpc_url> --private-key <your_private_key> src/MyContract.sol:MyContract

## Deploy All
You may dry run without the `--broadcast` flag

### Arbitrove
> forge script script/FactoryArbitrove.s.sol:DeployFactory --broadcast --rpc-url ${GOERLI_RPC_URL} --private-key ${PRIVATE_KEY} --ffi

### Token staking
> forge script script/FactoryStaking.s.sol:DeployFactory --broadcast --rpc-url <your_rpc_url> --private-key <your_private_key>


## Compile Vyper Contracts

> pip3 install vyper

or

> docker run -v $(pwd):/code vyperlang/vyper /code/<contract_file.vy>

Add this to your `.zshrc`

This might work or not work depending on your system
```
vyper() {
    #do things with parameters like $1 such as
    docker run -v $(pwd):/code vyperlang/vyper /code/$1
}
```

## Enviroment variables
You might need to run `source .env` before running scripts depending on your system, an example for `.env` is in `.env.example`

```
GOERLI_RPC_URL=https://goerli.infura.io/v3/[INFURA_KEY]
ETHERSCAN_API_KEY=...
```