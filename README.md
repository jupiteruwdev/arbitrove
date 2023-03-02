# General compiling and deployment

Install vyper first before running deployment scripts

## Deploy Single

> forge create --rpc-url <your_rpc_url> --private-key <your_private_key> src/MyContract.sol:MyContract

## Deploy All

Arbitrove
> forge script script/FactoryArbitrove.s.sol:DeployFactory --broadcast --rpc-url ${GOERLI_RPC_URL} --private-key ${PRIVATE_KEY} --ffi

Token staking
> forge script script/Factory.s.sol:DeployFactory --broadcast --rpc-url <your_rpc_url> --private-key <your_private_key>


## Compile Vyper Contracts

> docker run -v $(pwd):/code vyperlang/vyper /code/<contract_file.vy>

Add this to your `.zshrc`

This might work or not work depending on your system
```
vyper() {
    #do things with parameters like $1 such as
    docker run -v $(pwd):/code vyperlang/vyper /code/$1
}
```

```
GOERLI_RPC_URL=https://goerli.infura.io/v3/[INFURA_KEY]
ETHERSCAN_API_KEY=...
```