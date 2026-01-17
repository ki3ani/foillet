// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Bookstore.sol";

contract BookstoreListingHelpersTest is Test {
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

    function testActiveBookIdsAndPagination() public {
        vm.prank(seller);
        bs.createBook("A", "A", 1 ether);
        bs.createBook("B", "B", 1 ether);
        bs.createBook("C", "C", 1 ether);
        bs.createBook("D", "D", 1 ether);
        // Cancel book 1, sell book 2
        bs.cancelBook(1);
        vm.deal(buyer, 100 ether);
        vm.prank(buyer);
        bs.buyBook{value: 1 ether}(2);
        // Active: 0, 3
        uint256[] memory active = bs.getActiveBookIds();
        assertEq(active.length, 2);
        assertEq(active[0], 0);
        assertEq(active[1], 3);
        // Pagination
        uint256[] memory page = bs.getActiveBookIdsSlice(0, 1);
        assertEq(page.length, 1);
        assertEq(page[0], 0);
        page = bs.getActiveBookIdsSlice(1, 1);
        assertEq(page.length, 1);
        assertEq(page[0], 3);
        page = bs.getActiveBookIdsSlice(2, 1);
        assertEq(page.length, 0);
    }
}
