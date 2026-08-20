## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

- **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
- **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
- **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
- **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Bank.s.sol:BankScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```




# Bank Contract — Foundry Deployment Guide

A step-by-step guide to building, testing, deploying, and verifying the `Bank` smart contract on the Ethereum **Sepolia** testnet using [Foundry](https://book.getfoundry.sh/).

---

## Prerequisites

Before you start, make sure you have:

- **Foundry installed** — run `foundryup` to install/update. Verify with `forge --version`.
- **A test-only wallet** — create a *separate* wallet (e.g. in MetaMask) used only for testing. **Never use a wallet holding real funds, and never commit or share a private key.**
- **Sepolia test ETH** — free, from a Sepolia faucet (needed to pay gas).
- **An RPC URL** — free from a provider such as Alchemy or Infura.
- **An Etherscan API key** — free from [etherscan.io](https://etherscan.io) (needed only for verification).

---

## Project Structure

```
bank_project/
├── foundry.toml
├── remappings.txt
├── .env                  # secrets — NEVER commit this
├── .gitignore
├── src/
│   └── Bank.sol
├── test/
│   └── Bank.t.sol
├── script/
│   └── Bank.s.sol
└── lib/
    └── forge-std/
```

---

## Step 1 — Install Dependencies

The tests and scripts depend on `forge-std`:

```bash
forge install foundry-rs/forge-std
```

Confirm your `remappings.txt` contains:

```
forge-std/=lib/forge-std/src/
```

---

## Step 2 — Configure Secrets (`.env`)

Create a `.env` file in the project root:

```bash
SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/YOUR_API_KEY
PRIVATE_KEY=0xyour_test_wallet_private_key
ETHERSCAN_API_KEY=your_etherscan_api_key
```

> **Rules**
> - No spaces around the `=` sign.
> - `.env` must be listed in `.gitignore` so it is never committed.

Add these entries to `.gitignore`:

```
cache/
out/
broadcast/
.env
```

Load the variables into your shell (run this in every new terminal session):

```bash
source .env
```

Confirm they loaded (should print a value, not a blank line):

```bash
echo $SEPOLIA_RPC_URL
```

---

## Step 3 — Build

Compile the contract and catch any errors:

```bash
forge build
```

Expected output:

```
Compiler run successful!
```

---

## Step 4 — Test

Run the full test suite. **Never deploy a contract whose tests fail** — once a contract is on-chain, it cannot be edited.

```bash
forge test -vvv
```

Useful variations:

```bash
forge test --match-test test_Deposit -vvv   # run a single test
forge test --gas-report                      # show gas usage
```

---

## Step 5 — Deployment Script

The `Bank` constructor requires an `owner` address, so the deployment script must pass one. Example `script/Bank.s.sol`:

```solidity
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Bank} from "../src/Bank.sol";

contract BankScript is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerKey);

        address owner = vm.addr(deployerKey);   // deployer is the owner
        Bank bank = new Bank(owner);

        console.log("Bank deployed at:", address(bank));
        console.log("Owner set to:", owner);

        vm.stopBroadcast();
    }
}
```

---

## Step 6 — Dry Run (Simulation)

Run the script **without** `--broadcast` first. This simulates the deployment locally — nothing is sent on-chain and no gas is spent:

```bash
forge script script/Bank.s.sol:BankScript --rpc-url $SEPOLIA_RPC_URL
```

If the simulation succeeds, the script is correct and you're ready to deploy for real.

---

## Step 7 — Deploy to Sepolia

Add `--broadcast` to send the real transaction:

```bash
forge script script/Bank.s.sol:BankScript \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast
```

On success, the output includes the deployed address:

```
Bank deployed at: 0xE580e34d8D5DC331487119D3C9C7Af8e99f41ABd
Owner set to:     0xc1390394...3f33Aa077
```

> **Note:** each `--broadcast` run deploys a **new** contract at a new address. On-chain contracts cannot be deleted; old deployments simply remain and cause no harm.

---

## Step 8 — Confirm on the Explorer

View the contract on the **Sepolia** explorer (note the `sepolia.` prefix — mainnet Etherscan will not show it):

```
https://sepolia.etherscan.io/address/<YOUR_CONTRACT_ADDRESS>
```

A successful deploy shows the `Contract` label, the creator address, and the contract bytecode.

---

## Step 9 — Verify the Source Code

Verification publishes your Solidity source so others can read it and interact through the explorer UI. It is a separate step from deployment.

First, get the exact `owner` value the contract was deployed with (verification fails if constructor args don't match):

```bash
cast call <YOUR_CONTRACT_ADDRESS> "owner()(address)" --rpc-url $SEPOLIA_RPC_URL
```

Then verify:

```bash
forge verify-contract \
  <YOUR_CONTRACT_ADDRESS> \
  src/Bank.sol:Bank \
  --chain sepolia \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --constructor-args $(cast abi-encode "constructor(address)" <OWNER_ADDRESS>) \
  --watch
```

**Tip:** for future deploys you can verify automatically during deployment by adding `--verify` to the `forge script` command; Foundry then handles the constructor args for you:

```bash
forge script script/Bank.s.sol:BankScript \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY
```

After verification, the explorer shows a green check plus **Read Contract** and **Write Contract** tabs.

---

## Step 10 — Interact with the Contract

Use `cast` (bundled with Foundry) to call functions.

Read the owner:

```bash
cast call <YOUR_CONTRACT_ADDRESS> "owner()(address)" \
  --rpc-url $SEPOLIA_RPC_URL
```

Deposit 0.01 test ETH (sends a real transaction):

```bash
cast send <YOUR_CONTRACT_ADDRESS> "deposit()" \
  --value 0.01ether \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY
```

Check a bank balance:

```bash
cast call <YOUR_CONTRACT_ADDRESS> "balanceOf(address)(uint256)" <ADDRESS> \
  --rpc-url $SEPOLIA_RPC_URL
```

Withdraw 0.01 ETH:

```bash
cast send <YOUR_CONTRACT_ADDRESS> "withdraw(uint256)" 10000000000000000 \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY
```

---

## Generated Files

`forge script` creates these folders (keep them git-ignored):

```
broadcast/
└── Bank.s.sol/
    └── 11155111/                 # 11155111 = Sepolia chain ID
        ├── run-latest.json       # latest run: address, tx hash, gas
        └── run-<timestamp>.json
cache/
```

Inspect the latest deployment record:

```bash
cat broadcast/Bank.s.sol/11155111/run-latest.json
```

Look for a transaction `hash` and a `success` status to confirm a real (non-simulated) deploy.

---

## Quick Command Reference

| Step | Command |
|------|---------|
| Install deps | `forge install foundry-rs/forge-std` |
| Load env | `source .env` |
| Build | `forge build` |
| Test | `forge test -vvv` |
| Dry run | `forge script script/Bank.s.sol:BankScript --rpc-url $SEPOLIA_RPC_URL` |
| Deploy | `forge script script/Bank.s.sol:BankScript --rpc-url $SEPOLIA_RPC_URL --broadcast` |
| Verify | `forge verify-contract <ADDR> src/Bank.sol:Bank --chain sepolia --etherscan-api-key $ETHERSCAN_API_KEY --constructor-args $(cast abi-encode "constructor(address)" <OWNER>) --watch` |
| Read owner | `cast call <ADDR> "owner()(address)" --rpc-url $SEPOLIA_RPC_URL` |
| Deposit | `cast send <ADDR> "deposit()" --value 0.01ether --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY` |

---

## Safety Checklist

- [ ] Using a **test-only** wallet (no real funds).
- [ ] `.env` is listed in `.gitignore` and never committed.
- [ ] `forge build` compiles cleanly.
- [ ] `forge test` passes.
- [ ] Dry run (no `--broadcast`) succeeds before the real deploy.
- [ ] Wallet holds Sepolia test ETH for gas.
- [ ] Deployed address confirmed on `sepolia.etherscan.io`.
- [ ] Constructor args match when verifying.

---

## Chain Reference

| Network | Chain ID | Explorer |
|---------|----------|----------|
| Sepolia Testnet | 11155111 | https://sepolia.etherscan.io |
| Ethereum Mainnet | 1 | https://etherscan.io |

> The same commands deploy to mainnet — just swap in a mainnet RPC URL and use real ETH. Do **not** do this until you are confident, as mainnet costs real money.