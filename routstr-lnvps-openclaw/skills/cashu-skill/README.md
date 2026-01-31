# Cashu Wallet CLI

A lightweight, robust CLI for managing [Cashu](https://cashu.space) ecash tokens and interacting with Bitcoin Lightning mints. Built with Node.js and SQLite.

## ⚡ Quick Start

### Installation

```bash
git clone <repo-url>
cd cashu-wallet/cli
npm install
```

### Usage

Run commands via `node cli/wallet.mjs <command>`.

**Manage Wallet**
- `balance` - Show total balance.
- `history [limit] [offset]` - View transaction logs.
- `restore <mint-url>` - Restore funds from seed.

**Mint Management**
- `mints` - List trusted mints.
- `add-mint <url>` - Add a new mint.

**Incoming (Receive/Mint)**
- `invoice <amount>` - Create Lightning invoice to mint tokens.
- `check-invoice <quote-id>` - Check status of pending mint.
- `receive <token>` - Import a Cashu token string.

**Outgoing (Send/Melt)**
- `pay-invoice <bolt11>` - Pay a Lightning invoice.
- `send <amount>` - Generate a token to send.

## 🛠 Tech Stack

- **Runtime:** Node.js (>=18.0.0) ES Modules
- **Core:** `coco-cashu-core`
- **Storage:** `~/.cashu-wallet/wallet.db` (SQLite) & `seed.txt`

## ℹ️ Notes for Agents

- **Entry Point:** `cli/wallet.mjs`
- **Data Dir:** `~/.cashu-wallet` (auto-migrates from `.coco-wallet`)
- **Testing:** No test runner. Use `npm test` for balance check or run commands manually against a test mint.
- **Conventions:** `camelCase` for code, `snake_case` for files. Use `path.join` for paths.
