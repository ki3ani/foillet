// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Bookstore.sol";

contract BookstoreTest is Test {
    Bookstore bs;

    address owner = address(0xDEAD);
    address seller = address(0xA11CE);
    address buyer = address(0xB0B);
    address stranger = address(0xC0FFEE);

    function setUp() public {
        vm.txGasPrice(0);
        vm.deal(owner, 100 ether);
        vm.deal(seller, 100 ether);
        vm.deal(buyer, 100 ether);
        vm.deal(stranger, 100 ether);
        vm.prank(owner);
        bs = new Bookstore();
    }

    function testOwnerAndFeeLogic() public {
        assertEq(bs.owner(), owner);
        assertEq(bs.feeBps(), 200);

        // Only owner can set fee
        vm.prank(seller);
        vm.expectRevert(bytes("Only owner"));
        bs.setFeeBps(500);

        vm.prank(owner);
        bs.setFeeBps(500);
        assertEq(bs.feeBps(), 500);
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
        uint256 ownerBefore = owner.balance;

        vm.prank(buyer);
        bs.buyBook{value: 1 ether}(0);

        // Seller's balance should NOT change until withdraw
        assertEq(seller.balance, sellerBefore);
        // Owner's balance should NOT change until withdraw
        assertEq(owner.balance, ownerBefore);

        // Seller gets net, owner gets fee
        uint256 fee = (1 ether * bs.feeBps()) / 10000;
        uint256 net = 1 ether - fee;
        assertEq(bs.pendingWithdrawals(seller), net);
        assertEq(bs.pendingWithdrawals(owner), fee);

        (,,,,, address gotBuyer, bool isSold, bool isCancelled) = bs.getBook(0);
        assertEq(gotBuyer, buyer);
        assertTrue(isSold);
        assertTrue(!isCancelled);

        // Seller withdraws
        vm.prank(seller);
        bs.withdraw();
        assertEq(seller.balance, sellerBefore + net);
        assertEq(bs.pendingWithdrawals(seller), 0);

        // Owner withdraws
        vm.prank(owner);
        bs.withdraw();
        assertEq(owner.balance, ownerBefore + fee);
        assertEq(bs.pendingWithdrawals(owner), 0);
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
