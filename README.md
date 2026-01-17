
# Bookstore Solidity dApp

This project is a simple on-chain Bookstore written in Solidity, with Python and Foundry tooling for local development, testing, and interaction.

## Features

- List books for sale (title, author, price, seller)
- Update price or cancel listing (seller only)
- Buy books with ETH (buyer pays, seller receives funds)
- View all books, book details, and status (sold/cancelled)
- Emits events for all major actions
- Fully tested with Foundry

## Quickstart

### 1. Install dependencies

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- Python 3, `web3` (`pip install web3`)

### 2. Start a local blockchain

```
anvil
```

### 3. Build and test the contract

```
forge build
forge test -vv
```

### 4. Interact with the contract (Python)

In a new terminal:

```
python3 interact.py
```

This script will:
- Deploy the contract
- List a book
- Update price, buy, cancel, and show expected reverts
- Print book details and balances

You can also run interactively:

```
python3 -i interact.py
```
and call contract functions from the Python shell.

## Contract Overview

- `createBook(title, author, priceWei)` — List a new book
- `getBookCount()` — Total books
- `getBook(id)` — Book details (tuple)
- `updateBookPrice(id, newPriceWei)` — Seller only
- `cancelBook(id)` — Seller only
- `buyBook(id)` — Buyer pays exact price in ETH

## Testing

All core behaviors are covered in [test/Bookstore.t.sol](test/Bookstore.t.sol):
- Create/read, buy, update price, cancel, and revert cases

## Advanced

- Use Foundry `cast` to interact from the CLI
- Use Remix for GUI-based interaction

---

Made with ❤️ using Solidity, Foundry, and Python.
