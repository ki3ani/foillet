// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Bookstore.sol";

contract BookstoreValidationTest is Test {
    Bookstore bs;
    address owner = address(0xDEAD);
    address seller = address(0xA11CE);
    address buyer = address(0xB0B);

    function setUp() public {
        vm.deal(owner, 100 ether);
        vm.deal(seller, 100 ether);
        vm.deal(buyer, 100 ether);
        vm.prank(owner);
        bs = new Bookstore();
    }

    function testCannotCreateWithEmptyTitleOrAuthor() public {
        vm.prank(seller);
        vm.expectRevert(bytes("Title required"));
        bs.createBook("", "Author", 1 ether);
        vm.prank(seller);
        vm.expectRevert(bytes("Author required"));
        bs.createBook("Title", "", 1 ether);
    }

    function testCannotUpdateMetadataToEmpty() public {
        vm.prank(seller);
        bs.createBook("T", "A", 1 ether);
        vm.prank(seller);
        vm.expectRevert(bytes("Title required"));
        bs.updateBookMetadata(0, "", "A");
        vm.prank(seller);
        vm.expectRevert(bytes("Author required"));
        bs.updateBookMetadata(0, "T", "");
    }

    function testSellerCannotBuyOwnBook() public {
        vm.prank(seller);
        bs.createBook("T", "A", 1 ether);
        vm.prank(seller);
        vm.expectRevert(bytes("Seller cannot buy own book"));
        bs.buyBook{value: 1 ether}(0);
    }
}
