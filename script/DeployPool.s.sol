// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "forge-std/Script.sol";
import "../contracts/KYCPool.sol";
import "../contracts/KYCNFT.sol";

/**
 * @title DeployPool
 * @dev Deployment script for KYCPool contract
 * 
 * Usage:
 * - Set KYCNFT_ADDRESS environment variable to use an existing KYCNFT contract
 * - Or set DEPLOY_ALL=true to deploy KYCNFT first, then KYCPool
 * 
 * Example:
 *   forge script script/DeployPool.s.sol:DeployPool --broadcast --rpc-url $RPC_URL -vv
 */
contract DeployPool is Script {
    address public kycNFTAddress = 0x996dA15db8b9E938d8bEc848E27f6567990493BB;
    address public poolAddress;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deploying KYCPool contract...");
        console.log("Deployer address:", deployer);
        console.log("Deployer balance:", deployer.balance / 1e18, "ETH");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy KYCPool contract
        console.log("\n2. Deploying KYCPool contract...");
        KYCPool pool = new KYCPool(kycNFTAddress);
        poolAddress = address(pool);
        console.log("KYCPool contract deployed at:", poolAddress);

        vm.stopBroadcast();

        // Print summary
        console.log("\n=== Deployment Summary ===");
        console.log("KYCNFT Contract:", kycNFTAddress);
        console.log("KYCPool Contract:", poolAddress);
        console.log("========================\n");
    }
}

