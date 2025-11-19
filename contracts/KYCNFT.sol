// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/**
 * @title KYCNFT
 * @dev Simple NFT contract that mints tokens with KYC information
 * This contract only handles minting - verification is done by KYCVerifier
 */
contract KYCNFT is ERC721, Ownable {
    using Counters for Counters.Counter;
    
    Counters.Counter private _tokenIdCounter;
    
    // Mapping from user address to token ID (to prevent duplicate minting per address)
    mapping(address => uint256) public addressToTokenId;
    
    // Mapping from token ID to KYC data
    mapping(uint256 => KYCData) public tokenKYCData;
    
    // Struct to store KYC information
    struct KYCData {
        string firstName;
        string lastName;
        string kycStatus;
        string platform;
        address verifiedAddress;
        uint256 mintedAt;
    }
    
    // Events
    event KYCNFTMinted(
        address indexed to,
        uint256 indexed tokenId,
        string firstName,
        string lastName,
        string kycStatus,
        string platform
    );
    
    // Modifier to restrict minting to authorized contracts
    mapping(address => bool) public authorizedMinters;
    
    /**
     * @dev Constructor
     * @param _name Name of the NFT collection
     * @param _symbol Symbol of the NFT collection
     */
    constructor(
        string memory _name,
        string memory _symbol
    ) ERC721(_name, _symbol) {
        // Owner can mint directly if needed
        authorizedMinters[msg.sender] = true;
    }
    
    /**
     * @dev Mint an NFT with KYC data (only callable by authorized minters)
     * @param to Address to mint the NFT to
     * @param firstName First name from KYC
     * @param lastName Last name from KYC
     * @param kycStatus KYC status (e.g., "ADVANCED")
     * @param platform Platform name (e.g., "binance")
     */
    function mint(
        address to,
        string memory firstName,
        string memory lastName,
        string memory kycStatus,
        string memory platform
    ) public {
        require(authorizedMinters[msg.sender], "Not authorized to mint");
        require(to != address(0), "Cannot mint to zero address");
        
        // Check if address already has an NFT
        uint256 existingTokenId = addressToTokenId[to];
        require(
            existingTokenId == 0 || !_exists(existingTokenId),
            "Address already has a KYC NFT"
        );
        
        // Validate input data
        require(bytes(firstName).length > 0, "FirstName cannot be empty");
        require(bytes(lastName).length > 0, "LastName cannot be empty");
        require(bytes(kycStatus).length > 0, "KYC status cannot be empty");
        require(bytes(platform).length > 0, "Platform cannot be empty");
        
        // Mint the NFT
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
        
        // Store KYC data
        tokenKYCData[tokenId] = KYCData({
            firstName: firstName,
            lastName: lastName,
            kycStatus: kycStatus,
            platform: platform,
            verifiedAddress: to,
            mintedAt: block.timestamp
        });
        
        // Map address to token ID
        addressToTokenId[to] = tokenId;
        
        // Emit event
        emit KYCNFTMinted(to, tokenId, firstName, lastName, kycStatus, platform);
    }
    
    /**
     * @dev Get KYC data for a specific token ID
     * @param tokenId The token ID to query
     * @return KYCData struct containing the KYC information
     */
    function getKYCData(uint256 tokenId) public view returns (KYCData memory) {
        require(_exists(tokenId), "Token does not exist");
        return tokenKYCData[tokenId];
    }
    
    /**
     * @dev Get token ID for a specific address
     * @param userAddress The address to query
     * @return tokenId The token ID associated with the address, or 0 if none
     */
    function getTokenIdByAddress(address userAddress) public view returns (uint256) {
        return addressToTokenId[userAddress];
    }
    
    /**
     * @dev Check if an address has a KYC NFT
     * @param userAddress The address to check
     * @return bool True if the address has a KYC NFT
     */
    function hasKYCNFT(address userAddress) public view returns (bool) {
        uint256 tokenId = addressToTokenId[userAddress];
        // If tokenId is 0, we need to distinguish between:
        // 1. No token mapped (default value 0, token doesn't exist)
        // 2. Token ID is actually 0 (token exists)
        // We check if token exists and is owned by the user
        if (tokenId == 0) {
            return _exists(0) && ownerOf(0) == userAddress;
        }
        // For non-zero tokenIds, just check if token exists
        return _exists(tokenId);
    }
    
    /**
     * @dev Override tokenURI to return metadata URI
     * For now, returns an empty string. Can be extended to return IPFS or other metadata URIs
     * @param tokenId The token ID
     * @return string The token URI
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "Token does not exist");
        // Return empty string for now - can be extended to return IPFS URI with metadata
        return "";
    }
    
    /**
     * @dev Authorize an address to mint NFTs (only owner)
     * @param minter Address to authorize
     * @param authorized Whether the address is authorized
     */
    function setAuthorizedMinter(address minter, bool authorized) public onlyOwner {
        authorizedMinters[minter] = authorized;
    }
    
    /**
     * @dev Get total number of minted tokens
     * @return uint256 Total supply
     */
    function totalSupply() public view returns (uint256) {
        return _tokenIdCounter.current();
    }
}

