// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Bookstore.sol";

contract BookstoreTest is Test {
    Bookstore bs;

    address seller = address(0xA11CE);
    address buyer = address(0xB0B);
    address stranger = address(0xC0FFEE);

    function setUp() public {
        vm.txGasPrice(0);
        bs = new Bookstore();

        vm.deal(seller, 100 ether);
        vm.deal(buyer, 100 ether);
        vm.deal(stranger, 100 ether);
    }

    function testCreateAndReadBook() public {
        vm.prank(seller);
        bs.createBook("Title", "Author", 1 ether);

        assertEq(bs.getBookCount(), 1);

        (
            uint256 id,
            string memory title,
            string memory author,
            uint256 price,
            address gotSeller,
            address gotBuyer,
            bool isSold,
            bool isCancelled
        ) = bs.getBook(0);

        assertEq(id, 0);
        assertEq(title, "Title");
        assertEq(author, "Author");
        assertEq(price, 1 ether);
        assertEq(gotSeller, seller);
        assertEq(gotBuyer, address(0));
        assertEq(isSold, false);
        assertEq(isCancelled, false);
    }

    function testBuyBookTransfersEthAndMarksSold() public {
        vm.prank(seller);
        bs.createBook("T", "A", 1 ether);

        uint256 sellerBefore = seller.balance;

        vm.prank(buyer);
        bs.buyBook{value: 1 ether}(0);

        assertEq(seller.balance, sellerBefore + 1 ether);

        (,,,,, address gotBuyer, bool isSold, bool isCancelled) = bs.getBook(0);
        assertEq(gotBuyer, buyer);
        assertTrue(isSold);
        assertTrue(!isCancelled);
    }

    function testBuyWrongValueReverts() public {
        vm.prank(seller);
        bs.createBook("T", "A", 1 ether);

        vm.prank(buyer);
        vm.expectRevert(bytes("Incorrect payment amount"));
        bs.buyBook{value: 0.5 ether}(0);
    }

    function testCannotBuyTwice() public {
        vm.prank(seller);
        bs.createBook("T", "A", 1 ether);

        vm.prank(buyer);
        bs.buyBook{value: 1 ether}(0);

        vm.prank(buyer);
        vm.expectRevert(bytes("Book already sold"));
        bs.buyBook{value: 1 ether}(0);
    }

    function testUpdatePriceOnlySeller() public {
        vm.prank(seller);
        bs.createBook("T", "A", 1 ether);

        vm.prank(stranger);
        vm.expectRevert(bytes("Only seller"));
        bs.updateBookPrice(0, 2 ether);

        vm.prank(seller);
        bs.updateBookPrice(0, 2 ether);

        (,,, uint256 price,,,,) = bs.getBook(0);
        assertEq(price, 2 ether);
    }

    function testCancelPreventsBuying() public {
        vm.prank(seller);
        bs.createBook("T", "A", 1 ether);

        vm.prank(seller);
        bs.cancelBook(0);

        vm.prank(buyer);
        vm.expectRevert(bytes("Book cancelled"));
        bs.buyBook{value: 1 ether}(0);
    }
}
