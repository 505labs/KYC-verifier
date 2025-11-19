// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "forge-std/Test.sol";
import "../contracts/KYCVerifier.sol";
import "../contracts/KYCNFT.sol";
import "../contracts/Reclaim.sol";
import "../contracts/Claims.sol";

contract KYCVerifierTest is Test {
    KYCVerifier public verifier;
    KYCNFT public nft;
    Reclaim public reclaim;
    address public claimsAddress;
    
    address public owner;
    address public user;
    
    // Mock proof data structure
    Reclaim.Proof public mockProof;

    event PlatformRegistered(string platform, string kycStatusField, string firstNameField, string lastNameField);
    event PlatformUpdated(string platform, bool isActive);
    event KYCVerified(address indexed user, string platform, string firstName, string lastName, string kycStatus);

    function setUp() public {
        owner = address(this);
        user = address(0x1);

        // Deploy Reclaim contract
        reclaim = new Reclaim();

        // "MyLib.sol:MyLib" = <file>:<contract/library name>
        claimsAddress = deployCode("Claims.sol:Claims");
        
        // Deploy KYCNFT
        nft = new KYCNFT("KYC Certificate", "KYC-CERT");
        
        // Deploy KYCVerifier
        // Foundry automatically links the Claims library during compilation
        verifier = new KYCVerifier(address(reclaim), address(nft));
        
        // Authorize verifier to mint
        nft.setAuthorizedMinter(address(verifier), true);
    }

    function test_Constructor() public view {
        assertEq(address(verifier.reclaimAddress()), address(reclaim));
        assertEq(address(verifier.kycNFT()), address(nft));
    }

    function test_BinancePlatform_Registered() public view {
        KYCVerifier.PlatformConfig memory config = verifier.getPlatformConfig("binance");
        assertTrue(config.isActive);
        assertEq(config.kycStatusField, "\"KYC_status\":\"");
        assertEq(config.firstNameField, "\"Name\":\"");
        assertEq(config.lastNameField, "\"Surname\":\"");
    }

    function test_RegisterPlatform() public {
        verifier.registerPlatform(
            "coinbase",
            "\"kycLevel\":\"",
            "\"firstName\":\"",
            "\"lastName\":\""
        );

        KYCVerifier.PlatformConfig memory config = verifier.getPlatformConfig("coinbase");
        assertTrue(config.isActive);
        assertEq(config.kycStatusField, "\"kycLevel\":\"");
        assertEq(config.firstNameField, "\"firstName\":\"");
        assertEq(config.lastNameField, "\"lastName\":\"");
    }

    function test_RegisterPlatform_OnlyOwner() public {
        vm.prank(user);
        vm.expectRevert();
        verifier.registerPlatform("coinbase", "\"kycLevel\":\"", "\"firstName\":\"", "\"lastName\":\"");
    }

    function test_UpdatePlatformStatus() public {
        // Deactivate binance
        vm.expectEmit(true, false, false, true);
        emit PlatformUpdated("binance", false);
        verifier.updatePlatformStatus("binance", false);

        KYCVerifier.PlatformConfig memory config = verifier.getPlatformConfig("binance");
        assertFalse(config.isActive);

        // Reactivate
        vm.expectEmit(true, false, false, true);
        emit PlatformUpdated("binance", true);
        verifier.updatePlatformStatus("binance", true);

        config = verifier.getPlatformConfig("binance");
        assertTrue(config.isActive);
    }

    function test_UpdatePlatformStatus_OnlyOwner() public {
        vm.prank(user);
        vm.expectRevert();
        verifier.updatePlatformStatus("binance", false);
    }

    function test_UpdatePlatformStatus_NotRegistered() public {
        vm.expectRevert("Platform not registered");
        verifier.updatePlatformStatus("nonexistent", false);
    }

    function test_SetReclaimAddress() public {
        address newReclaim = address(0x999);
        verifier.setReclaimAddress(newReclaim);
        assertEq(address(verifier.reclaimAddress()), newReclaim);
    }

    function test_SetReclaimAddress_OnlyOwner() public {
        vm.prank(user);
        vm.expectRevert();
        verifier.setReclaimAddress(address(0x999));
    }

    function test_SetReclaimAddress_ZeroAddress() public {
        vm.expectRevert("Reclaim address cannot be zero");
        verifier.setReclaimAddress(address(0));
    }

    function test_SetKYCNFT() public {
        KYCNFT newNFT = new KYCNFT("New NFT", "NEW");
        verifier.setKYCNFT(address(newNFT));
        assertEq(address(verifier.kycNFT()), address(newNFT));
    }

    function test_SetKYCNFT_OnlyOwner() public {
        vm.prank(user);
        vm.expectRevert();
        verifier.setKYCNFT(address(0x999));
    }

    function test_SetKYCNFT_ZeroAddress() public {
        vm.expectRevert("KYCNFT address cannot be zero");
        verifier.setKYCNFT(address(0));
    }

    function test_GetPlatformConfig_NotRegistered() public view returns (KYCVerifier.PlatformConfig memory) {
        KYCVerifier.PlatformConfig memory config = verifier.getPlatformConfig("nonexistent");
        assertEq(bytes(config.kycStatusField).length, 0);
        assertFalse(config.isActive);
    }
}

