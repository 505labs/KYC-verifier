// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "forge-std/Script.sol";
import "../contracts/KYCVerifier.sol";

/**
 * @title UpdatePlatformStatus
 * @dev Script to activate or deactivate a platform
 * 
 * Usage:
 * forge script script/UpdatePlatformStatus.s.sol:UpdatePlatformStatus --rpc-url <RPC_URL> --broadcast
 * 
 * Set environment variables:
 * - PRIVATE_KEY: Deployer private key
 * - KYC_VERIFIER_ADDRESS: Address of deployed KYCVerifier contract
 * - PLATFORM_NAME: Name of the platform
 * - IS_ACTIVE: "true" or "false"
 */
contract UpdatePlatformStatus is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address kycVerifierAddress = vm.envAddress("KYC_VERIFIER_ADDRESS");
        string memory platformName = vm.envString("PLATFORM_NAME");
        bool isActive = vm.envBool("IS_ACTIVE");

        console.log("Updating platform status...");
        console.log("KYCVerifier address:", kycVerifierAddress);
        console.log("Platform name:", platformName);
        console.log("Is active:", isActive);

        vm.startBroadcast(deployerPrivateKey);

        KYCVerifier verifier = KYCVerifier(kycVerifierAddress);
        verifier.updatePlatformStatus(platformName, isActive);

        vm.stopBroadcast();

        // Verify update
        KYCVerifier.PlatformConfig memory config = verifier.getPlatformConfig(platformName);
        console.log("\nPlatform status updated!");
        console.log("Platform active:", config.isActive);
    }
}

