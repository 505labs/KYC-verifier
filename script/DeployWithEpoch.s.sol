// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

// import "forge-std/Script.sol";
// import "../contracts/Reclaim.sol";
// import "../contracts/Claims.sol";
// import "../contracts/KYCNFT.sol";
// import "../contracts/KYCVerifier.sol";

// /**
//  * @title DeployWithEpoch
//  * @dev Deployment script that also sets up witnesses and epochs for testing
//  * This is useful for local development and testing
//  */
// contract DeployWithEpoch is Script {
//     function run() public {
//         uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
//         address deployer = vm.addr(deployerPrivateKey);

//         console.log("Deploying contracts with epoch setup...");
//         console.log("Deployer address:", deployer);

//         vm.startBroadcast(deployerPrivateKey);

//         // Deploy Claims library
//          console.log("\n1. Deploying Claims library...");
//         address claimsAddress = deployCode("Claims.sol:Claims");
//         console.log("Claims library deployed at:", claimsAddress);

//         // Deploy Reclaim contract
//         Reclaim reclaim = new Reclaim();
//         console.log("Reclaim contract:", address(reclaim));

//         // Deploy KYCNFT
//         KYCNFT kycNFT = new KYCNFT("KYC Certificate", "KYC-CERT");
//         console.log("KYCNFT contract:", address(kycNFT));

//         // Deploy KYCVerifier
//         KYCVerifier kycVerifier = new KYCVerifier(address(reclaim), address(kycNFT));
//         console.log("KYCVerifier contract:", address(kycVerifier));

//         // Authorize verifier
//         kycNFT.setAuthorizedMinter(address(kycVerifier), true);

//         // Set up witnesses for testing
//         // Generate 5 test witness addresses
//         Reclaim.Witness[] memory witnesses = new Reclaim.Witness[](5);
//         for (uint256 i = 0; i < 5; i++) {
//             // Use deterministic addresses for testing
//             address witnessAddr = address(uint160(1000 + i));
//             witnesses[i] = Reclaim.Witness({
//                 addr: witnessAddr,
//                 host: bytes.concat("localhost:", bytes(vm.toString(5550 + i)))
//             });
//         }

//         // Add epoch with witnesses
//         reclaim.addNewEpoch(witnesses, 5);
//         console.log("Epoch added with 5 witnesses");

//         vm.stopBroadcast();

//         console.log("\n=== Deployment Complete ===");
//         console.log("All contracts deployed and epoch configured");
//     }
// }

