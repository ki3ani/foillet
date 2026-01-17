// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Bookstore {
    // --- Admin ---
    address public owner;
    uint256 public feeBps; // fee in basis points (e.g. 200 = 2%)

    event FeeUpdated(uint256 oldFee, uint256 newFee);
    // --- Reentrancy Guard ---
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status = _NOT_ENTERED;

    function _nonReentrantBefore() private {
        require(_status == _NOT_ENTERED, "ReentrancyGuard: reentrant call");
        _status = _ENTERED;
    }

    function _nonReentrantAfter() private {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    // --- 1. THE DATA MODELS ---
    struct Book {
        uint256 id;
        string title;
        string author;
        uint256 price; // Price in Wei (smallest unit of ETH)
        address seller; // Who is selling it
        address buyer; // Who bought it (zero if unsold)
        bool isSold; // Is it available?
        bool isCancelled;
    }

    // --- 2. THE DATABASE ---
    // List of all books
    Book[] public books;

    // --- Withdraw pattern ---
    mapping(address => uint256) public pendingWithdrawals;

    // --- 3. THE LOGS (Events) ---
    // We emit these so your Python script knows what happened
    event BookCreated(uint256 id, string title, uint256 price);
    event BookSold(uint256 id, address buyer, uint256 price);
    event BookPriceUpdated(uint256 id, uint256 oldPrice, uint256 newPrice);
    event BookCancelled(uint256 id);

    // --- 4. THE ACTIONS ---

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    constructor() {
        owner = msg.sender;
        feeBps = 200; // default 2%
    }

    function setFeeBps(uint256 newFeeBps) public onlyOwner {
        require(newFeeBps <= 1000, "Fee too high"); // max 10%
        uint256 oldFee = feeBps;
        feeBps = newFeeBps;
        emit FeeUpdated(oldFee, newFeeBps);
    }

    // POST /books
    function createBook(string memory _title, string memory _author, uint256 _price) public {
        require(_price > 0, "Price must be > 0");
        uint256 newId = books.length; // Auto-increment ID

        Book memory newBook = Book({
            id: newId,
            title: _title,
            author: _author,
            price: _price,
            seller: msg.sender,
            buyer: address(0),
            isSold: false,
            isCancelled: false
        });

        books.push(newBook);

        emit BookCreated(newId, _title, _price);
    }

    // POST /books/{id}/buy
    // 'payable' means this function accepts Crypto
    function buyBook(uint256 _id) public payable nonReentrant {
        require(_id < books.length, "Invalid book id");

        // Fetch the book from storage (Pointer to DB)
        Book storage book = books[_id];

        require(!book.isCancelled, "Book cancelled");
        require(!book.isSold, "Book already sold");
        require(msg.value == book.price, "Incorrect payment amount");

        // Effects
        book.isSold = true;
        book.buyer = msg.sender;

        // Calculate fee
        uint256 fee = (msg.value * feeBps) / 10000;
        uint256 sellerAmount = msg.value - fee;

        // Store ETH for seller and owner to withdraw later
        pendingWithdrawals[book.seller] += sellerAmount;
        pendingWithdrawals[owner] += fee;

        emit BookSold(_id, msg.sender, msg.value);
    }

    // Seller withdraws their funds
    function withdraw() public nonReentrant {
        uint256 amount = pendingWithdrawals[msg.sender];
        require(amount > 0, "No funds to withdraw");
        pendingWithdrawals[msg.sender] = 0;
        (bool ok, ) = payable(msg.sender).call{value: amount}("");
        require(ok, "Withdraw transfer failed");
    }

    // --- Extra interactions for learning ---

    function updateBookPrice(uint256 _id, uint256 _newPrice) public {
        require(_id < books.length, "Invalid book id");
        require(_newPrice > 0, "Price must be > 0");

        Book storage book = books[_id];

        require(msg.sender == book.seller, "Only seller");
        require(!book.isCancelled, "Book cancelled");
        require(!book.isSold, "Book already sold");

        uint256 oldPrice = book.price;
        book.price = _newPrice;

        emit BookPriceUpdated(_id, oldPrice, _newPrice);
    }

    function cancelBook(uint256 _id) public {
        require(_id < books.length, "Invalid book id");

        Book storage book = books[_id];

        require(msg.sender == book.seller, "Only seller");
        require(!book.isSold, "Book already sold");
        require(!book.isCancelled, "Already cancelled");

        book.isCancelled = true;

        emit BookCancelled(_id);
    }

    function getBook(uint256 _id)
        public
        view
        returns (
            uint256 id,
            string memory title,
            string memory author,
            uint256 price,
            address seller,
            address buyer,
            bool isSold,
            bool isCancelled
        )
    {
        require(_id < books.length, "Invalid book id");
        Book storage b = books[_id];
        return (b.id, b.title, b.author, b.price, b.seller, b.buyer, b.isSold, b.isCancelled);
    }

    // GET /books
    // Helper to get total book count
    function getBookCount() public view returns (uint256) {
        return books.length;
    }
}
