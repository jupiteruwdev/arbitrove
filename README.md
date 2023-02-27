> Deploy Single
forge create --rpc-url <your_rpc_url> --private-key <your_private_key> src/MyContract.sol:MyContract

> Deploy All
forge script script/Factory.s.sol:DeployFactory --broadcast --rpc-url <your_rpc_url> --private-key <your_private_key>

GOERLI_RPC_URL=https://goerli.infura.io/v3/[INFURA_KEY]
ETHERSCAN_API_KEY=...