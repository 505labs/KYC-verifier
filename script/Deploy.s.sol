// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "forge-std/Script.sol";
import "../contracts/Reclaim.sol";
import "../contracts/Claims.sol";
import "../contracts/KYCNFT.sol";
import "../contracts/KYCVerifier.sol";
import "../contracts/Addresses.sol";

/**
 * @title Deploy
 * @dev Deployment script for KYC NFT system
 * 
 * Deployment order:
 * 1. Deploy Claims library
 * 2. Deploy Reclaim contract
 * 3. Deploy KYCNFT contract
 * 4. Deploy KYCVerifier contract (with linked Claims library)
 * 5. Authorize KYCVerifier to mint NFTs
 * 6. Set up initial platforms (Binance is already registered in constructor)
 */
contract Deploy is Script {
    // Contract addresses
    address public reclaimAddress;
    address public claimsAddress;
    address public kycNFTAddress;
    address public kycVerifierAddress;

    // Configuration
    string public constant NFT_NAME = "KYC Certificate";
    string public constant NFT_SYMBOL = "KYC-CERT";

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deploying contracts...");
        console.log("Deployer address:", deployer);
        console.log("Deployer balance:", deployer.balance / 1e18, "ETH");

        vm.startBroadcast(deployerPrivateKey);

        // Step 1: Deploy Claims library
        console.log("\n1. Deploying Claims library...");
        claimsAddress = deployCode("Claims.sol:Claims");
        console.log("Claims library deployed at:", claimsAddress);

        // Step 2: Deploy Reclaim contract
        console.log("\n2. Deploying Reclaim contract...");
        Reclaim reclaim = new Reclaim();
        reclaimAddress = address(reclaim);
        console.log("Reclaim contract deployed at:", reclaimAddress);

        // Step 3: Deploy KYCNFT contract
        console.log("\n3. Deploying KYCNFT contract...");
        KYCNFT kycNFT = new KYCNFT(NFT_NAME, NFT_SYMBOL);
        kycNFTAddress = address(kycNFT);
        console.log("KYCNFT contract deployed at:", kycNFTAddress);

        // Step 4: Deploy KYCVerifier contract
        // Note: Foundry handles library linking automatically during compilation
        // The Claims library must be deployed, but linking happens at compile time
        console.log("\n4. Deploying KYCVerifier contract...");
        KYCVerifier kycVerifier = new KYCVerifier(reclaimAddress, kycNFTAddress);
        kycVerifierAddress = address(kycVerifier);
        console.log("KYCVerifier contract deployed at:", kycVerifierAddress);

        // Step 5: Authorize KYCVerifier to mint NFTs
        console.log("\n5. Authorizing KYCVerifier to mint NFTs...");
        kycNFT.setAuthorizedMinter(kycVerifierAddress, true);
        console.log("KYCVerifier authorized to mint NFTs");

        // Step 6: Verify Binance platform is registered
        console.log("\n6. Verifying Binance platform registration...");
        KYCVerifier.PlatformConfig memory binanceConfig = kycVerifier.getPlatformConfig("binance");
        require(binanceConfig.isActive, "Binance platform should be active");
        console.log("Binance platform is registered and active");

        // Set up epoch with witness from the proof
        Reclaim.Witness[] memory witnesses = new Reclaim.Witness[](1);
        witnesses[0] = Reclaim.Witness({
            addr: address(0x244897572368Eadf65bfBc5aec98D8e5443a9072),
            host: "wss://attestor.reclaimprotocol.org:444/ws"
        });
        
        // Add epoch with 1 witness (matching the proof)
        reclaim.addNewEpoch(witnesses, 1);

        vm.stopBroadcast();

        // Print summary
        console.log("\n=== Deployment Summary ===");
        console.log("Claims Library:", claimsAddress);
        console.log("Reclaim Contract:", reclaimAddress);
        console.log("KYCNFT Contract:", kycNFTAddress);
        console.log("KYCVerifier Contract:", kycVerifierAddress);
        console.log("========================\n");

        // Save addresses to file for easy reference
        // _saveAddresses();
    }

    // function _saveAddresses() internal {
    //     bytes memory json = bytes.concat(
    //         "{\n",
    //         '  "claimsLibrary": "', bytes(vm.toString(claimsAddress)), '",\n',
    //         '  "reclaim": "', bytes(vm.toString(reclaimAddress)), '",\n',
    //         '  "kycNFT": "', bytes(vm.toString(kycNFTAddress)), '",\n',
    //         '  "kycVerifier": "', bytes(vm.toString(kycVerifierAddress)), '"\n',
    //         "}\n"
    //     );
    //     vm.writeFile("./deployments.json", json.toString());
    //     console.log("Addresses saved to deployments.json");
    // }
}

