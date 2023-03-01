Deploy Single

> forge create --rpc-url <your_rpc_url> --private-key <your_private_key> src/MyContract.sol:MyContract

Deploy All

> forge script script/Factory.s.sol:DeployFactory --broadcast --rpc-url <your_rpc_url> --private-key <your_private_key>


Compile Vyper Contracts

> docker run -v $(pwd):/code vyperlang/vyper /code/<contract_file.vy>

Add this to your `.zshrc`

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