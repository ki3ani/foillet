// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Bookstore.sol";

contract BookstoreDelistPauseTest is Test {
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

    function testOwnerCanDelist() public {
        vm.prank(seller);
        bs.createBook("T", "A", 1 ether);
        vm.prank(owner);
        bs.delistBook(0);
        (,,,,,, bool isSold, bool isCancelled) = bs.getBook(0);
        assertTrue(isCancelled);
    }

    function testDelistPreventsBuying() public {
        vm.prank(seller);
        bs.createBook("T", "A", 1 ether);
        vm.prank(owner);
        bs.delistBook(0);
        vm.deal(buyer, 100 ether);
        vm.prank(buyer);
        vm.expectRevert(bytes("Book cancelled"));
        bs.buyBook{value: 1 ether}(0);
    }

    function testPauseDisablesCreate() public {
        vm.prank(seller);
        bs.createBook("T", "A", 1 ether);
        vm.prank(owner);
        bs.setPaused(true);
        vm.prank(seller);
        vm.expectRevert(bytes("Paused"));
        bs.createBook("X", "Y", 1 ether);
    }

    // function testPauseDisablesBuy() public {
    //     vm.prank(seller);
    //     bs.createBook("T", "A", 1 ether);
    //     vm.prank(owner);
    //     bs.setPaused(true);
    //     vm.prank(buyer);
    //     vm.expectRevert(bytes("Paused"));
    //     bs.buyBook{value: 1 ether}(0);
    // }

    function testPauseDisablesMetadataUpdate() public {
        vm.prank(seller);
        bs.createBook("T", "A", 1 ether);
        vm.prank(owner);
        bs.setPaused(true);
        vm.prank(seller);
        vm.expectRevert(bytes("Paused"));
        bs.updateBookMetadata(0, "X", "Y");
    }

    function testUnpauseEnablesMetadataUpdate() public {
        vm.prank(seller);
        bs.createBook("T", "A", 1 ether);
        vm.prank(owner);
        bs.setPaused(true);
        vm.prank(owner);
        bs.setPaused(false);
        vm.prank(seller);
        bs.updateBookMetadata(0, "X", "Y"); // should succeed now
    }
}
