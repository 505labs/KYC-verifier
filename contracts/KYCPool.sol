// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./KYCNFT.sol";

/**
 * @title KYCPool
 * @dev Example pool contract that requires users to have a KYC NFT before depositing
 * This demonstrates how to integrate KYC verification into DeFi protocols
 */
contract KYCPool is Ownable {
    KYCNFT public kycNFT;
    
    // Mapping from user address to their deposit balance
    mapping(address => uint256) public deposits;
    
    // Total deposits in the pool
    uint256 public totalDeposits;
    
    // Events
    event Deposit(address indexed user, uint256 amount, uint256 totalDeposit);
    event Withdrawal(address indexed user, uint256 amount, uint256 remainingDeposit);
    
    /**
     * @dev Constructor
     * @param _kycNFT Address of the KYCNFT contract
     */
    constructor(address _kycNFT) {
        require(_kycNFT != address(0), "KYCNFT address cannot be zero");
        kycNFT = KYCNFT(_kycNFT);
    }
    
    /**
     * @dev Deposit funds into the pool
     * Requires the caller to have a KYC NFT
     */
    function deposit() public payable {
        require(msg.value > 0, "Deposit amount must be greater than zero");
        
        // Check if user has a KYC NFT
        require(
            kycNFT.hasKYCNFT(msg.sender),
            "KYC NFT required to deposit"
        );
        
        // Update user's deposit balance
        deposits[msg.sender] += msg.value;
        totalDeposits += msg.value;
        
        emit Deposit(msg.sender, msg.value, deposits[msg.sender]);
    }
    
    /**
     * @dev Withdraw funds from the pool
     * @param amount Amount to withdraw
     */
    function withdraw(uint256 amount) public {
        require(amount > 0, "Withdrawal amount must be greater than zero");
        require(deposits[msg.sender] >= amount, "Insufficient balance");
        
        // Update balances
        deposits[msg.sender] -= amount;
        totalDeposits -= amount;
        
        // Transfer funds
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Transfer failed");
        
        emit Withdrawal(msg.sender, amount, deposits[msg.sender]);
    }
    
    /**
     * @dev Get deposit balance for a user
     * @param user Address to query
     * @return uint256 Deposit balance
     */
    function getDeposit(address user) public view returns (uint256) {
        return deposits[user];
    }
    
    /**
     * @dev Check if an address can deposit (has KYC NFT)
     * @param user Address to check
     * @return bool True if the address has a KYC NFT
     */
    function canDeposit(address user) public view returns (bool) {
        return kycNFT.hasKYCNFT(user);
    }
    
    /**
     * @dev Update KYCNFT contract address (only owner)
     * @param _kycNFT New KYCNFT contract address
     */
    function setKYCNFT(address _kycNFT) public onlyOwner {
        require(_kycNFT != address(0), "KYCNFT address cannot be zero");
        kycNFT = KYCNFT(_kycNFT);
    }
    
    /**
     * @dev Emergency withdraw function for owner (only owner)
     * This should be used only in emergency situations
     */
    function emergencyWithdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");
        
        (bool success, ) = payable(owner()).call{value: balance}("");
        require(success, "Transfer failed");
    }
}

