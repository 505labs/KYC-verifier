// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "forge-std/Test.sol";
import "../contracts/KYCVerifier.sol";
import "../contracts/KYCNFT.sol";
import "../contracts/Reclaim.sol";
import "../contracts/Claims.sol";
import "../contracts/StringUtils.sol";

/**
 * @title KYCVerifierProofTest
 * @dev Test contract for verifying actual proofs from example-binance-claim.json
 */
contract KYCVerifierProofTest is Test {
    KYCVerifier public verifier;
    KYCNFT public nft;
    Reclaim public reclaim;
    
    address public owner;
    address public user; // 0x07dc42bcfa668d08213339ca4b155f666b0c879e from JSON
    
    // Test data from example-binance-claim.json
    bytes32 constant EXPECTED_IDENTIFIER = 0x4083dd33701aed8ef074fe76d28ba4085895b8124933080e7fa1da729d503a7d;
    address constant PROOF_OWNER = address(0x07dC42bCFA668D08213339Ca4B155f666b0C879e);
    uint32 constant PROOF_TIMESTAMP = 1763504829;
    uint32 constant PROOF_EPOCH = 1;
    
    // Witness from JSON
    address constant WITNESS_ADDRESS = address(0x244897572368Eadf65bfBc5aec98D8e5443a9072);
    string constant WITNESS_HOST = "wss://attestor.reclaimprotocol.org:444/ws";
    
    // KYC data from context
    string constant EXPECTED_FIRST_NAME = "Jure";
    string constant EXPECTED_LAST_NAME = "Snoj";
    string constant EXPECTED_KYC_STATUS = "ADVANCED";
    
    // Private keys for witnesses (we'll use these to generate signatures)
    uint256 constant WITNESS_PRIVATE_KEY = 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef;

    event KYCVerified(address indexed user, string platform, string firstName, string lastName, string kycStatus);
    event KYCNFTMinted(
        address indexed to,
        uint256 indexed tokenId,
        string firstName,
        string lastName,
        string kycStatus,
        string platform
    );

    function setUp() public {
        owner = address(this);
        user = PROOF_OWNER;

        // Deploy Reclaim contract
        reclaim = new Reclaim();
        
        // Deploy KYCNFT
        nft = new KYCNFT("KYC Certificate", "KYC-CERT");
        
        // Deploy KYCVerifier
        verifier = new KYCVerifier(address(reclaim), address(nft));
        
        // Authorize verifier to mint
        nft.setAuthorizedMinter(address(verifier), true);
        
        // Set up epoch with witness from the proof
        Reclaim.Witness[] memory witnesses = new Reclaim.Witness[](1);
        witnesses[0] = Reclaim.Witness({
            addr: WITNESS_ADDRESS,
            host: WITNESS_HOST
        });
        
        // Add epoch with 1 witness (matching the proof)
        reclaim.addNewEpoch(witnesses, 1);
    }

    /**
     * @dev Helper function to create the serialized claim data for signing
     * Format matches Claims.serialise(): identifier\nowner\ntimestampS\nepoch
     * Uses StringUtils to match exact format
     */
    function _createClaimDataForSigning(
        bytes32 identifier,
        address ownerAddr,
        uint32 timestampS,
        uint32 epoch
    ) internal pure returns (bytes memory) {
        // Use StringUtils to match exact serialization format
        string memory identifierStr = StringUtils.bytes2str(abi.encodePacked(identifier));
        string memory ownerStr = StringUtils.address2str(ownerAddr);
        string memory timestampStr = StringUtils.uint2str(timestampS);
        string memory epochStr = StringUtils.uint2str(epoch);
        
        // Serialize: identifier\nowner\ntimestampS\nepoch
        return abi.encodePacked(
            identifierStr,
            "\n",
            ownerStr,
            "\n",
            timestampStr,
            "\n",
            epochStr
        );
    }

    /**
     * @dev Helper to sign a message (Ethereum signed message format)
     * Matches Claims.verifySignature format exactly
     * Note: Cannot be pure because vm.sign is a cheatcode
     */
    function _signMessage(bytes memory message, uint256 privateKey) internal returns (bytes memory) {
        // Create Ethereum signed message hash
        // Format: "\x19Ethereum Signed Message:\n" + length + message
        string memory lengthStr = StringUtils.uint2str(message.length);
        bytes32 messageHash = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n",
                lengthStr,
                message
            )
        );
        
        // Sign with vm.sign (Foundry cheatcode)
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, messageHash);
        return abi.encodePacked(r, s, v);
    }

    /**
     * @dev Test verifying a proof with actual data from example-binance-claim.json
     * Note: This test uses mock signatures since we can't easily recover the original
     * private keys. For a full integration test, you'd need the actual witness private keys.
     */
    function test_VerifyProof_WithExampleData() public {
        // Construct claim info from JSON
        Claims.ClaimInfo memory claimInfo = Claims.ClaimInfo({
            provider: "http",
            parameters: "{\"additionalClientOptions\":{},\"body\":\"\",\"geoLocation\":\"PT\",\"headers\":{\"Sec-Fetch-Mode\":\"same-origin\",\"Sec-Fetch-Site\":\"same-origin\",\"User-Agent\":\"Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Mobile Safari/537.36\"},\"method\":\"POST\",\"paramValues\":{\"DOB\":\"2002-02-26\",\"KYC_status\":\"ADVANCED\",\"Name\":\"Jure\",\"Surname\":\"Snoj\"},\"responseMatches\":[{\"invert\":false,\"type\":\"contains\",\"value\":\"\\\"currentKycLevel\\\":\\\"{{KYC_status}}\\\"\"},{\"invert\":false,\"type\":\"contains\",\"value\":\"\\\"lastName\\\":\\\"{{Surname}}\\\"\"},{\"invert\":false,\"type\":\"contains\",\"value\":\"\\\"dob\\\":\\\"{{DOB}}\\\"\"},{\"invert\":false,\"type\":\"contains\",\"value\":\"\\\"firstName\\\":\\\"{{Name}}\\\"\"}],\"responseRedactions\":[{\"jsonPath\":\"$.data.currentKycLevel\",\"regex\":\"\\\"currentKycLevel\\\":\\\"(.*)\\\"\",\"xPath\":\"\"},{\"jsonPath\":\"$.data.fillInfo.lastName\",\"regex\":\"\\\"lastName\\\":\\\"(.*)\\\"\",\"xPath\":\"\"},{\"jsonPath\":\"$.data.fillInfo.dob\",\"regex\":\"\\\"dob\\\":\\\"(.*)\\\"\",\"xPath\":\"\"},{\"jsonPath\":\"$.data.fillInfo.firstName\",\"regex\":\"\\\"firstName\\\":\\\"(.*)\\\"\",\"xPath\":\"\"}],\"url\":\"https://www.binance.com/bapi/kyc/v2/private/certificate/user-kyc/current-kyc-status\"}",
            context: "{\"contextAddress\":\"0x0\",\"contextMessage\":\"sample context\",\"extractedParameters\":{\"DOB\":\"2002-02-26\",\"KYC_status\":\"ADVANCED\",\"Name\":\"Jure\",\"Surname\":\"Snoj\"},\"providerHash\":\"0x71a168281f37a849f6fab2e097ecc7e623e1d77c98f75eae0c1e7abadfd7e422\"}"
        });

        // Verify the identifier matches
        bytes32 computedIdentifier = Claims.hashClaimInfo(claimInfo);
        assertEq(computedIdentifier, EXPECTED_IDENTIFIER, "Identifier mismatch");

        // Create claim data for signing
        Claims.CompleteClaimData memory claimData = Claims.CompleteClaimData({
            identifier: EXPECTED_IDENTIFIER,
            owner: PROOF_OWNER,
            timestampS: PROOF_TIMESTAMP,
            epoch: PROOF_EPOCH
        });

        // Generate signature from witness
        // Note: We use a test private key here. In production, you'd use the actual witness private key
        bytes memory claimDataBytes = _createClaimDataForSigning(
            EXPECTED_IDENTIFIER,
            PROOF_OWNER,
            PROOF_TIMESTAMP,
            PROOF_EPOCH
        );
        
        // Use vm.sign with a private key that corresponds to the witness address
        // For testing, we'll use a known private key and update the witness address
        uint256 witnessKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80; // Anvil default
        address witnessAddr = vm.addr(witnessKey);
        
        // Update the epoch to use this witness
        Reclaim.Witness[] memory testWitnesses = new Reclaim.Witness[](1);
        testWitnesses[0] = Reclaim.Witness({
            addr: witnessAddr,
            host: "test-host"
        });
        reclaim.addNewEpoch(testWitnesses, 1);

        bytes memory signature = _signMessage(claimDataBytes, witnessKey);

        // Construct signatures array
        bytes[] memory signatures = new bytes[](1);
        signatures[0] = signature;

        // Construct signed claim
        Claims.SignedClaim memory signedClaim = Claims.SignedClaim({
            claim: claimData,
            signatures: signatures
        });

        // Construct proof
        Reclaim.Proof memory proof = Reclaim.Proof({
            claimInfo: claimInfo,
            signedClaim: signedClaim
        });

        // Verify and mint
        vm.expectEmit(true, true, false, true);
        emit KYCVerified(PROOF_OWNER, "binance", EXPECTED_FIRST_NAME, EXPECTED_LAST_NAME, EXPECTED_KYC_STATUS);
        
        // vm.expectEmit(true, true, false, true);
        // emit KYCNFTMinted(PROOF_OWNER, 0, EXPECTED_FIRST_NAME, EXPECTED_LAST_NAME, EXPECTED_KYC_STATUS, "binance");

        verifier.verifyAndMint(proof, "binance", PROOF_OWNER);

        // Verify NFT was minted
        assertEq(nft.ownerOf(0), PROOF_OWNER);
        assertTrue(nft.hasKYCNFT(PROOF_OWNER));

        // Verify KYC data
        KYCNFT.KYCData memory kycData = nft.getKYCData(0);
        assertEq(kycData.firstName, EXPECTED_FIRST_NAME);
        assertEq(kycData.lastName, EXPECTED_LAST_NAME);
        assertEq(kycData.kycStatus, EXPECTED_KYC_STATUS);
        assertEq(kycData.platform, "binance");
    }

}

