# Foundry Setup and Usage

This project uses Foundry for testing and deployment. This guide explains how to use the Foundry tests and deployment scripts.

## Prerequisites

1. Install Foundry: https://book.getfoundry.sh/getting-started/installation
2. Install dependencies:
   ```bash
   forge install
   ```

## Running Tests

### Run all tests
```bash
forge test
```

### Run specific test file
```bash
forge test --match-path test/KYCNFT.t.sol
forge test --match-path test/KYCVerifier.t.sol
```

### Run with verbosity
```bash
forge test -vvv
```

### Run specific test function
```bash
forge test --match-test test_MintNFT
```

## Deployment Scripts

### 1. Deploy All Contracts

Deploy all contracts (Reclaim, Claims library, KYCNFT, KYCVerifier):

```bash
forge script script/Deploy.s.sol:Deploy --rpc-url <RPC_URL> --broadcast --verify
```

Set environment variables:
- `PRIVATE_KEY`: Your deployer private key

The script will:
1. Deploy Claims library
2. Deploy Reclaim contract
3. Deploy KYCNFT contract
4. Deploy KYCVerifier contract
5. Authorize KYCVerifier to mint NFTs
6. Save deployment addresses to `deployments.json`

### 2. Deploy with Epoch Setup (for testing)

Deploy contracts and set up test witnesses/epochs:

```bash
forge script script/DeployWithEpoch.s.sol:DeployWithEpoch --rpc-url <RPC_URL> --broadcast
```

### 3. Register New Platform

Register a new platform on an existing KYCVerifier:

```bash
forge script script/RegisterPlatform.s.sol:RegisterPlatform --rpc-url <RPC_URL> --broadcast
```

Set environment variables:
- `PRIVATE_KEY`: Deployer private key
- `KYC_VERIFIER_ADDRESS`: Address of deployed KYCVerifier
- `PLATFORM_NAME`: Platform name (e.g., "coinbase")
- `KYC_STATUS_FIELD`: Field pattern (e.g., "\"kycLevel\":\"")
- `FIRST_NAME_FIELD`: Field pattern (e.g., "\"firstName\":\"")
- `LAST_NAME_FIELD`: Field pattern (e.g., "\"lastName\":\"")

Example:
```bash
export PRIVATE_KEY=0x...
export KYC_VERIFIER_ADDRESS=0x...
export PLATFORM_NAME=coinbase
export KYC_STATUS_FIELD="\"kycLevel\":\""
export FIRST_NAME_FIELD="\"firstName\":\""
export LAST_NAME_FIELD="\"lastName\":\""

forge script script/RegisterPlatform.s.sol:RegisterPlatform --rpc-url http://localhost:8545 --broadcast
```

### 4. Update Platform Status

Activate or deactivate a platform:

```bash
forge script script/UpdatePlatformStatus.s.sol:UpdatePlatformStatus --rpc-url <RPC_URL> --broadcast
```

Set environment variables:
- `PRIVATE_KEY`: Deployer private key
- `KYC_VERIFIER_ADDRESS`: Address of deployed KYCVerifier
- `PLATFORM_NAME`: Platform name
- `IS_ACTIVE`: "true" or "false"

## Local Development

### Start Anvil (local node)
```bash
anvil
```

### Deploy to local Anvil
```bash
forge script script/Deploy.s.sol:Deploy --rpc-url http://localhost:8545 --broadcast --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

## Environment Variables

Create a `.env` file for local development:

```bash
PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
RPC_URL=http://localhost:8545
```

Then use:
```bash
source .env
forge script script/Deploy.s.sol:Deploy --rpc-url $RPC_URL --broadcast
```

## Contract Addresses

After deployment, addresses are saved to `deployments.json`:

```json
{
  "claimsLibrary": "0x...",
  "reclaim": "0x...",
  "kycNFT": "0x...",
  "kycVerifier": "0x..."
}
```

## Notes

- The Claims library must be deployed before KYCVerifier (for linking)
- KYCVerifier is automatically authorized to mint NFTs during deployment
- Binance platform is pre-registered in KYCVerifier constructor
- All scripts use `vm.startBroadcast()` and `vm.stopBroadcast()` for transaction simulation

## Troubleshooting

### Library Linking Issues
If you encounter library linking errors, ensure:
1. Claims library is deployed first
2. Foundry automatically handles library linking during compilation

### Test Failures
- Ensure all dependencies are installed: `forge install`
- Check that contracts compile: `forge build`
- Run with higher verbosity: `forge test -vvvv`

