// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "forge-std/Test.sol";
import "../contracts/KYCPool.sol";
import "../contracts/KYCNFT.sol";

contract KYCPoolTest is Test {
    KYCPool public pool;
    KYCNFT public nft;
    address public owner;
    address public kycUser;
    address public nonKycUser;
    address public authorizedMinter;

    event Deposit(address indexed user, uint256 amount, uint256 totalDeposit);
    event Withdrawal(address indexed user, uint256 amount, uint256 remainingDeposit);

    function setUp() public {
        owner = address(this);
        kycUser = address(0x1);
        nonKycUser = address(0x2);
        authorizedMinter = address(0x3);

        // Deploy KYCNFT contract
        nft = new KYCNFT("KYC Certificate", "KYC-CERT");
        nft.setAuthorizedMinter(authorizedMinter, true);

        // Deploy KYCPool contract
        pool = new KYCPool(address(nft));

        // Mint KYC NFT for kycUser
        vm.prank(authorizedMinter);
        nft.mint(kycUser, "John", "Doe", "VERIFIED", "binance");

        // Give users some ETH
        vm.deal(kycUser, 10 ether);
        vm.deal(nonKycUser, 10 ether);
    }

    function test_Deposit_WithKYCNFT() public {
        uint256 depositAmount = 1 ether;
        
        vm.prank(kycUser);
        vm.expectEmit(true, false, false, true);
        emit Deposit(kycUser, depositAmount, depositAmount);
        pool.deposit{value: depositAmount}();

        assertEq(pool.getDeposit(kycUser), depositAmount);
        assertEq(pool.totalDeposits(), depositAmount);
        assertEq(address(pool).balance, depositAmount);
    }

    function test_Deposit_WithoutKYCNFT() public {
        uint256 depositAmount = 1 ether;
        
        vm.prank(nonKycUser);
        vm.expectRevert("KYC NFT required to deposit");
        pool.deposit{value: depositAmount}();

        assertEq(pool.getDeposit(nonKycUser), 0);
        assertEq(pool.totalDeposits(), 0);
    }

    function test_Deposit_ZeroAmount() public {
        vm.prank(kycUser);
        vm.expectRevert("Deposit amount must be greater than zero");
        pool.deposit{value: 0}();
    }

    function test_Deposit_Multiple() public {
        uint256 firstDeposit = 1 ether;
        uint256 secondDeposit = 2 ether;
        
        vm.prank(kycUser);
        pool.deposit{value: firstDeposit}();
        
        vm.prank(kycUser);
        pool.deposit{value: secondDeposit}();

        assertEq(pool.getDeposit(kycUser), firstDeposit + secondDeposit);
        assertEq(pool.totalDeposits(), firstDeposit + secondDeposit);
    }

    function test_Withdraw() public {
        uint256 depositAmount = 2 ether;
        uint256 withdrawAmount = 1 ether;
        
        // Deposit first
        vm.prank(kycUser);
        pool.deposit{value: depositAmount}();
        
        uint256 initialBalance = kycUser.balance;
        
        // Withdraw
        vm.prank(kycUser);
        vm.expectEmit(true, false, false, true);
        emit Withdrawal(kycUser, withdrawAmount, depositAmount - withdrawAmount);
        pool.withdraw(withdrawAmount);

        assertEq(pool.getDeposit(kycUser), depositAmount - withdrawAmount);
        assertEq(pool.totalDeposits(), depositAmount - withdrawAmount);
        assertEq(kycUser.balance, initialBalance + withdrawAmount);
    }

    function test_Withdraw_InsufficientBalance() public {
        uint256 depositAmount = 1 ether;
        uint256 withdrawAmount = 2 ether;
        
        vm.prank(kycUser);
        pool.deposit{value: depositAmount}();
        
        vm.prank(kycUser);
        vm.expectRevert("Insufficient balance");
        pool.withdraw(withdrawAmount);
    }

    function test_Withdraw_ZeroAmount() public {
        vm.prank(kycUser);
        pool.deposit{value: 1 ether}();
        
        vm.prank(kycUser);
        vm.expectRevert("Withdrawal amount must be greater than zero");
        pool.withdraw(0);
    }

    function test_CanDeposit() public {
        assertTrue(pool.canDeposit(kycUser));
        assertFalse(pool.canDeposit(nonKycUser));
    }

    function test_GetDeposit() public {
        assertEq(pool.getDeposit(kycUser), 0);
        
        vm.prank(kycUser);
        pool.deposit{value: 1 ether}();
        
        assertEq(pool.getDeposit(kycUser), 1 ether);
    }

    function test_SetKYCNFT() public {
        // Create new NFT contract
        KYCNFT newNFT = new KYCNFT("New KYC Certificate", "NEW-KYC");
        newNFT.setAuthorizedMinter(authorizedMinter, true);
        
        // Update pool's NFT contract
        pool.setKYCNFT(address(newNFT));
        
        assertEq(address(pool.kycNFT()), address(newNFT));
    }

    function test_SetKYCNFT_OnlyOwner() public {
        KYCNFT newNFT = new KYCNFT("New KYC Certificate", "NEW-KYC");
        
        vm.prank(kycUser);
        vm.expectRevert();
        pool.setKYCNFT(address(newNFT));
    }

    function test_SetKYCNFT_ZeroAddress() public {
        vm.expectRevert("KYCNFT address cannot be zero");
        pool.setKYCNFT(address(0));
    }

    function test_EmergencyWithdraw() public {
        uint256 depositAmount = 1 ether;
        
        vm.prank(kycUser);
        pool.deposit{value: depositAmount}();
        
        uint256 ownerBalance = owner.balance;
        pool.emergencyWithdraw();
        
        assertEq(owner.balance, ownerBalance + depositAmount);
        assertEq(address(pool).balance, 0);
    }

    function test_EmergencyWithdraw_OnlyOwner() public {
        vm.prank(kycUser);
        vm.expectRevert();
        pool.emergencyWithdraw();
    }

    function test_EmergencyWithdraw_NoFunds() public {
        vm.expectRevert("No funds to withdraw");
        pool.emergencyWithdraw();
    }

    function test_MultipleUsers() public {
        // Create another KYC user
        address kycUser2 = address(0x4);
        vm.deal(kycUser2, 10 ether);
        
        vm.prank(authorizedMinter);
        nft.mint(kycUser2, "Jane", "Smith", "ADVANCED", "coinbase");
        
        // Both users deposit
        vm.prank(kycUser);
        pool.deposit{value: 1 ether}();
        
        vm.prank(kycUser2);
        pool.deposit{value: 2 ether}();
        
        assertEq(pool.getDeposit(kycUser), 1 ether);
        assertEq(pool.getDeposit(kycUser2), 2 ether);
        assertEq(pool.totalDeposits(), 3 ether);
    }
}

