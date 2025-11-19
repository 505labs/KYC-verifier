# Deployment Guide

## Setup

Load environment variables from the `.env` file:

```bash
source .env
```


### 1. Deploy Core Contracts

Deploy and broadcast the core contracts:

```bash
forge script script/Deploy.s.sol:Deploy --broadcast --rpc-url $RAILS_RPC_URL -vv 
```

### 2. Deploy KYCPool

Deploy the KYCPool contract:
```bash
forge script script/DeployPool.s.sol:DeployPool --broadcast --rpc-url $RAILS_RPC_URL -vv
```


### 3. Verify Contract
Verify the deployed contracts:


#### NFTS
```bash
ARGS=$(cast abi-encode "constructor(string,string)" \
  "KYC Certificate" \
  "KYC-CERT")

forge verify-contract \
  --rpc-url https://devnet-explorer.rayls.com/api/eth-rpc \
  --verifier blockscout \
  --verifier-url 'https://devnet-explorer.rayls.com/api/' \
  --constructor-args $ARGS \
  0x996dA15db8b9E938d8bEc848E27f6567990493BB \
  contracts/KYCNFT.sol:KYCNFT 
```


#### Verifier
```bash
ARGS=$(cast abi-encode "constructor(address,address)" \
  0x8714241997B67FF3896303C5aBD4399584d61131 \
  0x996dA15db8b9E938d8bEc848E27f6567990493BB)

forge verify-contract \
  --rpc-url https://devnet-explorer.rayls.com/api/eth-rpc \
  --verifier blockscout \
  --verifier-url 'https://devnet-explorer.rayls.com/api/' \
  --constructor-args $ARGS \
  0xa399869468Ba49c6f7a0b65Df06adE96e5CC0D0f \
  contracts/KYCVerifier.sol:KYCVerifier 

# forge verify-contract \
#   --constructor-args $ARGS \
#   --chain-id 123123 \
#   --verifier sourcify \
#   --verifier-url https://sourcify.parsec.finance/verify \
#   0xa399869468Ba49c6f7a0b65Df06adE96e5CC0D0f \
#   contracts/KYCVerifier.sol:KYCVerifier 
```

#### Pool
```bash
ARGS=$(cast abi-encode "constructor(address)" \
  0x996dA15db8b9E938d8bEc848E27f6567990493BB)

forge verify-contract \
  --rpc-url https://devnet-explorer.rayls.com/api/eth-rpc \
  --verifier blockscout \
  --verifier-url 'https://devnet-explorer.rayls.com/api/' \
  --constructor-args $ARGS \
  0x51cF4466D36C073091A6E5Cb2BfCac3dc6B7BADB \
  contracts/KYCPool.sol:KYCPool
```


## Addresses

Claims Library: 0xC375E241aDcde8181dF7D0C3306591CE8a51abA5
Reclaim Contract: 0x8714241997B67FF3896303C5aBD4399584d61131
KYCNFT Contract: 0x996dA15db8b9E938d8bEc848E27f6567990493BB
KYCVerifier Contract: 0xa399869468Ba49c6f7a0b65Df06adE96e5CC0D0f
KYCPool Contract: 0x51cF4466D36C073091A6E5Cb2BfCac3dc6B7BADB


## Mint KYC NFTs

### Using the Mint Script (Recommended)

Mint a KYC NFT using the deployment script:

```bash
export RECIPIENT_ADDRESS=0xabc4cbf716472c47a61c8c2c5076895600f3cf10
export FIRST_NAME="John"
export LAST_NAME="Doe"
export KYC_STATUS="ADVANCED"
export PLATFORM="binance"

forge script script/MintKYCNFT.s.sol:MintKYCNFT --broadcast --rpc-url $RAILS_RPC_URL -vv
```

**Note:** The script will automatically authorize the deployer if they are the owner of the KYCNFT contract.

### Using Cast (Alternative)

You can also mint directly using `cast send`:

```bash
# Encode the mint function call
DATA=$(cast calldata "mint(address,string,string,string,string)" \
  0xabc4cbf716472c47a61c8c2c5076895600f3cf10 \
  "John" \
  "Doe" \
  "ADVANCED" \
  "binance")

cast send 0x996dA15db8b9E938d8bEc848E27f6567990493BB "$DATA" \
  --private-key $PRIVATE_KEY \
  --rpc-url $RAILS_RPC_URL \
  --chain 123123 \
  --gas-limit 200000 \
  --gas-price 5gwei
```