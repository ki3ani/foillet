// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Bookstore.sol";

contract BookstoreMetadataTest is Test {
    Bookstore bs;
    address owner = address(0xDEAD);
    address seller = address(0xA11CE);
    address buyer = address(0xB0B);

    function setUp() public {
        vm.deal(owner, 100 ether);
        vm.deal(seller, 100 ether);
        vm.prank(owner);
        bs = new Bookstore();
    }

    function testSellerCanEditMetadata() public {
        vm.prank(seller);
        bs.createBook("OldTitle", "OldAuthor", 1 ether);
        (, string memory title, string memory author,,,,,) = bs.getBook(0);
        assertEq(title, "OldTitle");
        assertEq(author, "OldAuthor");

        vm.prank(seller);
        bs.updateBookMetadata(0, "NewTitle", "NewAuthor");
        (, string memory updatedTitle, string memory updatedAuthor,,,,,) = bs.getBook(0);
        assertEq(updatedTitle, "NewTitle");
        assertEq(updatedAuthor, "NewAuthor");
    }

    function testCannotEditAfterSoldOrCancelled() public {
        vm.prank(seller);
        bs.createBook("T", "A", 1 ether);
        vm.prank(seller);
        bs.cancelBook(0);
        vm.prank(seller);
        vm.expectRevert(bytes("Book cancelled"));
        bs.updateBookMetadata(0, "X", "Y");

        vm.prank(owner);
        bs = new Bookstore();
        vm.prank(seller);
        bs.createBook("T", "A", 1 ether);
        vm.deal(buyer, 100 ether);
        vm.prank(buyer);
        bs.buyBook{value: 1 ether}(0);
        vm.prank(seller);
        vm.expectRevert(bytes("Book already sold"));
        bs.updateBookMetadata(0, "X", "Y");
    }
}
