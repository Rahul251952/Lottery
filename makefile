-include .env

.PHONY: all test deploy

build:; forge build

test:; forge test

install :; forge install cyfrin/foundry-devops@0.2.2 --commit && forge install smartcontractkit/chainlink-brownie-contracts@1.1.1 --commit && forge install foundry-rs/forge@1.8.2 --commit && forge install transmissions11/solmate@v6 --commit

deploy-sepolia:
  @forge script scripts/DeployRaffle.s.sol:DeployRaffle --rpc-url $(SEPOLIA_RPC_URL) --account default --broadcast --verify --etherscan--api-key $(ETHERSCAN_API_KEY) --verify-url https://sepolia.etherscan.io/ --max-fee-per-gas 1000000000 --max-priority-fee-per-gas 1000000000 --mnemonic $(MNEMONIC) --chain-id 11155111