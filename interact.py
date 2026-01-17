import json
from web3 import Web3

# 1. CONNECT TO LOCAL BLOCKCHAIN (Anvil)
# Run 'anvil' in a separate terminal window first!
rpc_url = "http://127.0.0.1:8545"
w3 = Web3(Web3.HTTPProvider(rpc_url))

if not w3.is_connected():
    print("❌ Failed to connect to Anvil. Did you run 'anvil' in the terminal?")
    exit()

print("✅ Connected to Local Blockchain")

# 2. SETUP ACCOUNTS (Anvil gives you 10 fake accounts with 10,000 ETH)
# Seller = Account[0]
# Buyer = Account[1]
seller_address = w3.eth.accounts[0]
buyer_address = w3.eth.accounts[1]

print(f"👨‍🏫 Seller: {seller_address}")
print(f"💰 Buyer:  {buyer_address}")


def send_tx(txn, tx_params, label: str):
    """Send a transaction and wait for receipt (prints a friendly status)."""
    try:
        tx_hash = txn.transact(tx_params)
        receipt = w3.eth.wait_for_transaction_receipt(tx_hash)
        print(f"✅ {label} (tx: {tx_hash.hex()})")
        return receipt
    except Exception as e:
        print(f"❌ {label} failed")
        print(f"   ↳ {e}")
        return None


def expect_revert(txn, tx_params, label: str):
    """Attempt a tx that should revert and print the error."""
    try:
        tx_hash = txn.transact(tx_params)
        w3.eth.wait_for_transaction_receipt(tx_hash)
        print(f"❌ Expected revert but tx succeeded: {label} (tx: {tx_hash.hex()})")
    except Exception as e:
        print(f"✅ Reverted as expected: {label}")
        print(f"   ↳ {e}")

# 3. DEPLOY THE CONTRACT
# We read the compiled JSON that Foundry created
try:
    with open('out/Bookstore.sol/Bookstore.json', 'r') as f:
        contract_json = json.load(f)
        abi = contract_json['abi']
        bytecode = contract_json['bytecode']['object']
except FileNotFoundError:
    print("❌ Could not find compiled contract. Run 'forge build' first!")
    exit()

# Deploy
print("\n🚀 Deploying Bookstore Contract...")
Bookstore = w3.eth.contract(abi=abi, bytecode=bytecode)
tx_hash = Bookstore.constructor().transact({'from': seller_address})
tx_receipt = w3.eth.wait_for_transaction_receipt(tx_hash)
contract_address = tx_receipt.contractAddress
print(f"✅ Bookstore deployed at: {contract_address}")

# Create Contract Instance
bookstore = w3.eth.contract(address=contract_address, abi=abi)

# 4. LIST A BOOK (Seller Action)
print("\n📖 Listing Book #0: 'The Logic of Finance' for 1 ETH...")
send_tx(
    bookstore.functions.createBook(
        "The Logic of Finance",
        "Kimani",
        w3.to_wei(1, "ether"),
    ),
    {"from": seller_address},
    "Book #0 listed",
)

# Verify it's there
book_count = bookstore.functions.getBookCount().call()
print(f"📚 Total Books in Store: {book_count}")

print("\n🔎 Reading Book #0 details (getBook)...")
book0 = bookstore.functions.getBook(0).call()
print(f"Book #0: {book0}")

print("\n🏷️ Seller updates Book #0 price to 2 ETH...")
send_tx(
    bookstore.functions.updateBookPrice(0, w3.to_wei(2, "ether")),
    {"from": seller_address},
    "Book #0 price updated to 2 ETH",
)

print("\n🔎 Reading Book #0 details after price update...")
book0_after_price = bookstore.functions.getBook(0).call()
print(f"Book #0: {book0_after_price}")

print("\n🧪 Buyer tries to update price (should revert)...")
expect_revert(
    bookstore.functions.updateBookPrice(0, w3.to_wei(3, "ether")),
    {"from": buyer_address},
    "Buyer updateBookPrice(0, 3 ETH)",
)

# 5. BUY THE BOOK (Buyer Action)
print("\n💸 Buyer tries to purchase Book #0 with WRONG amount (1 ETH, should revert)...")
expect_revert(
    bookstore.functions.buyBook(0),
    {"from": buyer_address, "value": w3.to_wei(1, "ether")},
    "buyBook(0) with 1 ETH",
)

print("\n💸 Buyer purchasing Book #0 with correct amount (2 ETH)...")

# Check Seller Balance BEFORE
seller_balance_before = w3.eth.get_balance(seller_address)
print(f"Before: Seller has {w3.from_wei(seller_balance_before, 'ether')} ETH")

send_tx(
    bookstore.functions.buyBook(0),
    {"from": buyer_address, "value": w3.to_wei(2, "ether")},
    "Book #0 purchased",
)

# Check Seller Balance AFTER
seller_balance_after = w3.eth.get_balance(seller_address)
print(f"After:  Seller has {w3.from_wei(seller_balance_after, 'ether')} ETH")


# Withdraw pattern: seller must claim funds
print("\n🔎 Seller's pending withdrawals (should be > 0 ETH)...")
pending = bookstore.functions.pendingWithdrawals(seller_address).call()
print(f"Seller pendingWithdrawals: {w3.from_wei(pending, 'ether')} ETH")

print("\n💸 Seller calls withdraw() to claim funds...")
seller_balance_before_withdraw = w3.eth.get_balance(seller_address)
tx_hash = bookstore.functions.withdraw().transact({'from': seller_address})
w3.eth.wait_for_transaction_receipt(tx_hash)
seller_balance_after_withdraw = w3.eth.get_balance(seller_address)
print(f"Seller balance before withdraw: {w3.from_wei(seller_balance_before_withdraw, 'ether')} ETH")
print(f"Seller balance after withdraw:  {w3.from_wei(seller_balance_after_withdraw, 'ether')} ETH")

pending_after = bookstore.functions.pendingWithdrawals(seller_address).call()
print(f"Seller pendingWithdrawals after withdraw: {w3.from_wei(pending_after, 'ether')} ETH")

print("\n🔎 Reading Book #0 details after purchase...")
book0_after_buy = bookstore.functions.getBook(0).call()
print(f"Book #0: {book0_after_buy}")

print("\n🧪 Seller tries to cancel sold book (should revert)...")
expect_revert(
    bookstore.functions.cancelBook(0),
    {"from": seller_address},
    "cancelBook(0) after sold",
)

print("\n📖 Listing Book #1: 'Solidity 101' for 1 ETH...")
send_tx(
    bookstore.functions.createBook(
        "Solidity 101",
        "Kimani",
        w3.to_wei(1, "ether"),
    ),
    {"from": seller_address},
    "Book #1 listed",
)

print("\n🛑 Seller cancels Book #1...")
send_tx(
    bookstore.functions.cancelBook(1),
    {"from": seller_address},
    "Book #1 cancelled",
)

print("\n🧪 Buyer tries to buy cancelled book (should revert)...")
expect_revert(
    bookstore.functions.buyBook(1),
    {"from": buyer_address, "value": w3.to_wei(1, "ether")},
    "buyBook(1) after cancel",
)

print("\n✅ Done. You’ve exercised: createBook, getBookCount, getBook, updateBookPrice, buyBook, cancelBook.")