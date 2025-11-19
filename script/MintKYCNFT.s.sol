// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "forge-std/Script.sol";
import "../contracts/KYCNFT.sol";

/**
 * @title MintKYCNFT
 * @dev Script to mint a KYC NFT to a given address
 * 
 * Usage:
 * forge script script/MintKYCNFT.s.sol:MintKYCNFT --rpc-url <RPC_URL> --broadcast
 * 
 * Set environment variables:
 * - PRIVATE_KEY: Private key of authorized minter (must be owner or authorized minter)
 * - KYC_NFT_ADDRESS: Address of deployed KYCNFT contract (default: 0x996dA15db8b9E938d8bEc848E27f6567990493BB)
 * - RECIPIENT_ADDRESS: Address to mint the NFT to
 * - FIRST_NAME: First name for the KYC data
 * - LAST_NAME: Last name for the KYC data
 * - KYC_STATUS: KYC status (e.g., "ADVANCED", "VERIFIED")
 * - PLATFORM: Platform name (e.g., "binance", "coinbase")
 * 
 * Example:
 * export PRIVATE_KEY=<your_key>
 * export RECIPIENT_ADDRESS=0x1234...
 * export FIRST_NAME="John"
 * export LAST_NAME="Doe"
 * export KYC_STATUS="ADVANCED"
 * export PLATFORM="binance"
 * forge script script/MintKYCNFT.s.sol:MintKYCNFT --broadcast --rpc-url $RAILS_RPC_URL -vv
 */
contract MintKYCNFT is Script {
    // Default KYCNFT address (can be overridden with env variable)
    address public constant DEFAULT_KYC_NFT_ADDRESS = 0x996dA15db8b9E938d8bEc848E27f6567990493BB;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        // Get KYCNFT address (use env var if set, otherwise use default)
        address kycNFTAddress = vm.envOr("KYC_NFT_ADDRESS", DEFAULT_KYC_NFT_ADDRESS);
        
        // Get recipient address
        address recipient = vm.envAddress("RECIPIENT_ADDRESS");
        
        // Get KYC data from environment variables
        string memory firstName = vm.envString("FIRST_NAME");
        string memory lastName = vm.envString("LAST_NAME");
        string memory kycStatus = vm.envString("KYC_STATUS");
        string memory platform = vm.envString("PLATFORM");

        console.log("Minting KYC NFT...");
        console.log("KYCNFT address:", kycNFTAddress);
        console.log("Recipient address:", recipient);
        console.log("First Name:", firstName);
        console.log("Last Name:", lastName);
        console.log("KYC Status:", kycStatus);
        console.log("Platform:", platform);
        console.log("Minter address:", deployer);

        vm.startBroadcast(deployerPrivateKey);

        KYCNFT kycNFT = KYCNFT(kycNFTAddress);
        
        // Check if deployer is authorized to mint
        bool isAuthorized = kycNFT.authorizedMinters(deployer);
        if (!isAuthorized) {
            console.log("\nWarning: Deployer is not authorized to mint.");
            console.log("Attempting to authorize deployer as owner...");
            
            // Try to authorize the deployer (only works if deployer is owner)
            try kycNFT.setAuthorizedMinter(deployer, true) {
                console.log("Deployer authorized successfully");
            } catch {
                revert("Deployer must be owner or already authorized to mint");
            }
        }

        // Mint the NFT
        kycNFT.mint(recipient, firstName, lastName, kycStatus, platform);

        vm.stopBroadcast();

        // Verify minting
        uint256 tokenId = kycNFT.getTokenIdByAddress(recipient);
        bool hasNFT = kycNFT.hasKYCNFT(recipient);
        KYCNFT.KYCData memory data = kycNFT.getKYCData(tokenId);

        console.log("\n=== Minting Summary ===");
        console.log("NFT minted successfully!");
        console.log("Token ID:", tokenId);
        console.log("Recipient has NFT:", hasNFT);
        console.log("First Name:", data.firstName);
        console.log("Last Name:", data.lastName);
        console.log("KYC Status:", data.kycStatus);
        console.log("Platform:", data.platform);
        console.log("Minted At:", data.mintedAt);
        console.log("======================\n");
    }
}

