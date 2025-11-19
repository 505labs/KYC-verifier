# Deployment Guide

## Setup

Load environment variables from the `.env` file:

```bash
source .env
```


### 1. Deploy

Deploy and broadcast the contract:

```bash
forge script script/Deploy.s.sol:Deploy --broadcast --rpc-url $RAILS_RPC_URL -vv 
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


## Addreeses

Claims Library: 0xC375E241aDcde8181dF7D0C3306591CE8a51abA5
Reclaim Contract: 0x8714241997B67FF3896303C5aBD4399584d61131
KYCNFT Contract: 0x996dA15db8b9E938d8bEc848E27f6567990493BB
KYCVerifier Contract: 0xa399869468Ba49c6f7a0b65Df06adE96e5CC0D0f


