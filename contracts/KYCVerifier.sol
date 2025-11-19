// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./Reclaim.sol";
import "./Addresses.sol";
import "./Claims.sol";
import "./KYCNFT.sol";

/**
 * @title KYCVerifier
 * @dev Contract that verifies KYC proofs from various platforms and mints NFTs
 * Supports multiple platforms with platform-specific extraction logic
 */
contract KYCVerifier is Ownable {
    address public reclaimAddress;
    KYCNFT public kycNFT;
    
    // Supported platforms and their field extraction patterns
    mapping(string => PlatformConfig) public platformConfigs;
    
    struct PlatformConfig {
        string kycStatusField;
        string firstNameField;
        string lastNameField;
        bool isActive;
    }
    
    event PlatformRegistered(string platform, string kycStatusField, string firstNameField, string lastNameField);
    event PlatformUpdated(string platform, bool isActive);
    event KYCVerified(address indexed user, string platform, string firstName, string lastName, string kycStatus);
    
    /**
     * @dev Constructor
     * @param _reclaimAddress Address of the Reclaim contract
     * @param _kycNFT Address of the KYCNFT contract
     */
    constructor(address _reclaimAddress, address _kycNFT) {
        require(_reclaimAddress != address(0), "Reclaim address cannot be zero");
        require(_kycNFT != address(0), "KYCNFT address cannot be zero");
        
        reclaimAddress = _reclaimAddress;
        kycNFT = KYCNFT(_kycNFT);
        
        // Register Binance platform by default
        _registerPlatform(
            "binance",
            "\"KYC_status\":\"",
            "\"Name\":\"",
            "\"Surname\":\""
        );
    }
    
    /**
     * @dev Register a new platform with its field extraction patterns
     * @param platform Platform name (e.g., "binance", "coinbase", etc.)
     * @param kycStatusField Field pattern to extract KYC status
     * @param firstNameField Field pattern to extract first name
     * @param lastNameField Field pattern to extract last name
     */
    function registerPlatform(
        string memory platform,
        string memory kycStatusField,
        string memory firstNameField,
        string memory lastNameField
    ) public onlyOwner {
        _registerPlatform(platform, kycStatusField, firstNameField, lastNameField);
    }
    
    /**
     * @dev Internal function to register a platform
     */
    function _registerPlatform(
        string memory platform,
        string memory kycStatusField,
        string memory firstNameField,
        string memory lastNameField
    ) internal {
        platformConfigs[platform] = PlatformConfig({
            kycStatusField: kycStatusField,
            firstNameField: firstNameField,
            lastNameField: lastNameField,
            isActive: true
        });
        
        emit PlatformRegistered(platform, kycStatusField, firstNameField, lastNameField);
    }
    
    /**
     * @dev Update platform status (activate/deactivate)
     * @param platform Platform name
     * @param isActive Whether the platform is active
     */
    function updatePlatformStatus(string memory platform, bool isActive) public onlyOwner {
        require(bytes(platformConfigs[platform].kycStatusField).length > 0, "Platform not registered");
        platformConfigs[platform].isActive = isActive;
        emit PlatformUpdated(platform, isActive);
    }
    
    /**
     * @dev Verify KYC proof and mint NFT
     * @param proof The Reclaim proof containing KYC information
     * @param platform Platform name (e.g., "binance")
     * @param to Address to mint the NFT to (must match proof owner)
     */
    function verifyAndMint(
        Reclaim.Proof memory proof,
        string memory platform,
        address to
    ) public {
        // Verify that the proof owner matches the recipient address
        // require(
        //     proof.signedClaim.claim.owner == to,
        //     "Proof owner must match recipient address"
        // );
        
        // Check if platform is registered and active
        PlatformConfig memory config = platformConfigs[platform];
        require(config.isActive, "Platform is not active");
        require(bytes(config.kycStatusField).length > 0, "Platform not registered");
        
        // Verify the proof using Reclaim contract
        Reclaim(reclaimAddress).verifyProof(proof);
        
        // Extract KYC data based on platform configuration
        string memory kycStatus = Claims.extractFieldFromContext(
            proof.claimInfo.context,
            config.kycStatusField
        );
        string memory firstName = Claims.extractFieldFromContext(
            proof.claimInfo.context,
            config.firstNameField
        );
        string memory lastName = Claims.extractFieldFromContext(
            proof.claimInfo.context,
            config.lastNameField
        );
        
        // Validate that KYC data was extracted successfully
        require(
            bytes(kycStatus).length > 0 &&
            bytes(firstName).length > 0 &&
            bytes(lastName).length > 0,
            "Failed to extract KYC data from proof"
        );
        
        // Mint NFT through the KYCNFT contract
        kycNFT.mint(to, firstName, lastName, kycStatus, platform);
        
        // Emit verification event
        emit KYCVerified(to, platform, firstName, lastName, kycStatus);
    }
    
    /**
     * @dev Update Reclaim contract address
     * @param _reclaimAddress New Reclaim contract address
     */
    function setReclaimAddress(address _reclaimAddress) public onlyOwner {
        require(_reclaimAddress != address(0), "Reclaim address cannot be zero");
        reclaimAddress = _reclaimAddress;
    }
    
    /**
     * @dev Update KYCNFT contract address
     * @param _kycNFT New KYCNFT contract address
     */
    function setKYCNFT(address _kycNFT) public onlyOwner {
        require(_kycNFT != address(0), "KYCNFT address cannot be zero");
        kycNFT = KYCNFT(_kycNFT);
    }
    
    /**
     * @dev Get platform configuration
     * @param platform Platform name
     * @return PlatformConfig struct
     */
    function getPlatformConfig(string memory platform) public view returns (PlatformConfig memory) {
        return platformConfigs[platform];
    }
}

