// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "forge-std/Test.sol";
import "../contracts/KYCNFT.sol";

contract KYCNFTTest is Test {
    KYCNFT public nft;
    address public owner;
    address public user;
    address public authorizedMinter;
    address public unauthorizedMinter;

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
        user = address(0x1);
        authorizedMinter = address(0x2);
        unauthorizedMinter = address(0x3);

        nft = new KYCNFT("KYC Certificate", "KYC-CERT");
        
        // Authorize a minter
        nft.setAuthorizedMinter(authorizedMinter, true);
    }

    function test_MintNFT() public {
        vm.prank(authorizedMinter);
        nft.mint(user, "John", "Doe", "VERIFIED", "binance");

        assertEq(nft.ownerOf(0), user);
        assertEq(nft.balanceOf(user), 1);
        assertEq(nft.totalSupply(), 1);
    }

    function test_MintNFT_StoresData() public {
        vm.prank(authorizedMinter);
        nft.mint(user, "John", "Doe", "VERIFIED", "binance");

        KYCNFT.KYCData memory data = nft.getKYCData(0);
        assertEq(data.firstName, "John");
        assertEq(data.lastName, "Doe");
        assertEq(data.kycStatus, "VERIFIED");
        assertEq(data.platform, "binance");
        assertEq(data.verifiedAddress, user);
        assertGt(data.mintedAt, 0);
    }

    function test_MintNFT_EmitsEvent() public {
        vm.prank(authorizedMinter);
        vm.expectEmit(true, true, false, true);
        emit KYCNFTMinted(user, 0, "John", "Doe", "VERIFIED", "binance");
        nft.mint(user, "John", "Doe", "VERIFIED", "binance");
    }

    function test_MintNFT_UnauthorizedMinter() public {
        vm.prank(unauthorizedMinter);
        vm.expectRevert("Not authorized to mint");
        nft.mint(user, "John", "Doe", "VERIFIED", "binance");
    }

    function test_MintNFT_ZeroAddress() public {
        vm.prank(authorizedMinter);
        vm.expectRevert("Cannot mint to zero address");
        nft.mint(address(0), "John", "Doe", "VERIFIED", "binance");
    }

    function test_MintNFT_EmptyFields() public {
        vm.prank(authorizedMinter);
        vm.expectRevert("FirstName cannot be empty");
        nft.mint(user, "", "Doe", "VERIFIED", "binance");

        vm.prank(authorizedMinter);
        vm.expectRevert("LastName cannot be empty");
        nft.mint(user, "John", "", "VERIFIED", "binance");

        vm.prank(authorizedMinter);
        vm.expectRevert("KYC status cannot be empty");
        nft.mint(user, "John", "Doe", "", "binance");

        vm.prank(authorizedMinter);
        vm.expectRevert("Platform cannot be empty");
        nft.mint(user, "John", "Doe", "VERIFIED", "");
    }

    function test_GetTokenIdByAddress() public {
        vm.prank(authorizedMinter);
        nft.mint(user, "John", "Doe", "VERIFIED", "binance");

        assertEq(nft.getTokenIdByAddress(user), 0);
        assertEq(nft.getTokenIdByAddress(address(0x999)), 0);
    }

    function test_HasKYCNFT() public {
        assertFalse(nft.hasKYCNFT(user));

        vm.prank(authorizedMinter);
        nft.mint(user, "John", "Doe", "VERIFIED", "binance");

        assertTrue(nft.hasKYCNFT(user));
        assertFalse(nft.hasKYCNFT(address(0x999)));
    }

    function test_SetAuthorizedMinter() public {
        assertFalse(nft.authorizedMinters(unauthorizedMinter));

        nft.setAuthorizedMinter(unauthorizedMinter, true);
        assertTrue(nft.authorizedMinters(unauthorizedMinter));

        vm.prank(unauthorizedMinter);
        nft.mint(user, "John", "Doe", "VERIFIED", "binance");
        assertEq(nft.ownerOf(0), user);

        nft.setAuthorizedMinter(unauthorizedMinter, false);
        assertFalse(nft.authorizedMinters(unauthorizedMinter));
    }

    function test_SetAuthorizedMinter_OnlyOwner() public {
        vm.prank(user);
        vm.expectRevert();
        nft.setAuthorizedMinter(unauthorizedMinter, true);
    }

    function test_TotalSupply() public {
        assertEq(nft.totalSupply(), 0);

        vm.prank(authorizedMinter);
        nft.mint(user, "John", "Doe", "VERIFIED", "binance");
        assertEq(nft.totalSupply(), 1);

        address user2 = address(0x4);
        vm.prank(authorizedMinter);
        nft.mint(user2, "Jane", "Smith", "ADVANCED", "coinbase");
        assertEq(nft.totalSupply(), 2);
    }

    function test_TokenURI() public {
        vm.prank(authorizedMinter);
        nft.mint(user, "John", "Doe", "VERIFIED", "binance");

        string memory uri = nft.tokenURI(0);
        assertEq(bytes(uri).length, 0); // Returns empty string for now
    }

    function test_GetKYCData_NonExistentToken() public {
        vm.expectRevert("Token does not exist");
        nft.getKYCData(999);
    }
}

