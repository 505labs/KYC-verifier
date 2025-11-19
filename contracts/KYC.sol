// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;
 
import "./Reclaim.sol";
import "./Addresses.sol";
import "./Claims.sol";
 
contract KYCAttestor {
   address public reclaimAddress;

   constructor(address _reclaimAddress) {
      // If no address provided, use the default network address
      if (_reclaimAddress == address(0)) {
         reclaimAddress = Addresses.ETHEREUM;
      } else {
         reclaimAddress = _reclaimAddress;
      }
   }
 
   function verifyProof(Reclaim.Proof memory proof) public view {
       Reclaim(reclaimAddress).verifyProof(proof);
       
       // Extract and validate KYC data (values are extracted but not used in this function)
       extractBinanceKYCStatus(proof);
       extractBinanceKYCLevel(proof);
   }

   function extractBinanceKYCStatus(Reclaim.Proof memory proof) public view returns (string memory kycStatus, string memory firstName, string memory lastName) {
        kycStatus = Claims.extractFieldFromContext(proof.claimInfo.context, "\"KYC_status\":\"");
        firstName = Claims.extractFieldFromContext(proof.claimInfo.context, "\"Name\":\"");
        lastName = Claims.extractFieldFromContext(proof.claimInfo.context, "\"Surname\":\"");
        return (kycStatus, firstName, lastName);
    }


    function extractBinanceKYCLevel(Reclaim.Proof memory proof) public view returns (string memory kycStatus, string memory firstName, string memory lastName) {
        kycStatus = Claims.extractFieldFromContext(proof.claimInfo.context, "\"KYC_status\":\"");
        firstName = Claims.extractFieldFromContext(proof.claimInfo.context, "\"Name\":\"");
        lastName = Claims.extractFieldFromContext(proof.claimInfo.context, "\"Surname\":\"");
        return (kycStatus, firstName, lastName);
    }

   

}