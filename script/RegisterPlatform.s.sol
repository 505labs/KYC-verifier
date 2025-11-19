// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "forge-std/Script.sol";
import "../contracts/KYCVerifier.sol";

/**
 * @title RegisterPlatform
 * @dev Script to register a new platform on an existing KYCVerifier contract
 * 
 * Usage:
 * forge script script/RegisterPlatform.s.sol:RegisterPlatform --rpc-url <RPC_URL> --broadcast
 * 
 * Set environment variables:
 * - PRIVATE_KEY: Deployer private key
 * - KYC_VERIFIER_ADDRESS: Address of deployed KYCVerifier contract
 * - PLATFORM_NAME: Name of the platform (e.g., "coinbase")
 * - KYC_STATUS_FIELD: Field pattern for KYC status (e.g., "\"kycLevel\":\"")
 * - FIRST_NAME_FIELD: Field pattern for first name (e.g., "\"firstName\":\"")
 * - LAST_NAME_FIELD: Field pattern for last name (e.g., "\"lastName\":\"")
 */
contract RegisterPlatform is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address kycVerifierAddress = vm.envAddress("KYC_VERIFIER_ADDRESS");
        
        string memory platformName = vm.envString("PLATFORM_NAME");
        string memory kycStatusField = vm.envString("KYC_STATUS_FIELD");
        string memory firstNameField = vm.envString("FIRST_NAME_FIELD");
        string memory lastNameField = vm.envString("LAST_NAME_FIELD");

        console.log("Registering platform on KYCVerifier...");
        console.log("KYCVerifier address:", kycVerifierAddress);
        console.log("Platform name:", platformName);

        vm.startBroadcast(deployerPrivateKey);

        KYCVerifier verifier = KYCVerifier(kycVerifierAddress);
        verifier.registerPlatform(
            platformName,
            kycStatusField,
            firstNameField,
            lastNameField
        );

        vm.stopBroadcast();

        // Verify registration
        KYCVerifier.PlatformConfig memory config = verifier.getPlatformConfig(platformName);
        console.log("\nPlatform registered successfully!");
        console.log("Platform active:", config.isActive);
        console.log("KYC Status Field:", config.kycStatusField);
        console.log("First Name Field:", config.firstNameField);
        console.log("Last Name Field:", config.lastNameField);
    }
}

