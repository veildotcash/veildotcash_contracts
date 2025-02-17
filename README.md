# Veil Validator Setup and Testing Guide

## Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- Node.js and npm

---

## Installation Steps

1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd <repository-folder>
   ```
2. Install Foundry dependencies:
   ```bash
   forge install
   ```
3. Install Node.js dependencies:
   ```bash
   npm install
   ```

---

## Running Tests

- **Run all tests:**
  ```bash
  forge clean && forge build && forge test
  ```
- **Run a single test:**
  ```bash
  forge clean && forge build && forge test --match-test <testName>
  ```

---

## Veil Cash Overview

Veil is a fork of Tornado Cash with several key changes:
- Merge of Tornado.sol + ETHTornado.sol (https://github.com/tornadocash/tornado-core) + (https://github.com/nkrishang/tornado-cash-rebuilt)
- Deposits can only be made through the proxy contract (`VeilValidator.sol`).
- Withdrawals are handled at the pool contracts following Tornado Cash protocol.
- Deposits are **not** allowed directly at the pool contracts.
- `VeilValidator.sol` is upgradable via the proxy contract.
- `VeilValidator` determines the type of users allowed to deposit:
  - **Onchain Verification:** Users can be verified on-chain via [Ethereum Attestation Service (EAS)](https://eas.ethereum.org) with a helper contract (`VeilVerifiedOnchain.sol`).
  - **Whitelisting:** Specific users can be added as allowed depositors.

---

## Contracts on Base Mainnet

### Validator Contracts
- **Validator Proxy:** `0xdFEc9441C1827319538CCCDEEEDfbdAa66295792`
- **Validator Implementation:** `0xb2E6D312c6378a4b9847A79F0947Ce651F0e8DF3`
- **Validator Admin:** `0x2DC1e210D48582a1266863D247387Be45C378914`

### Pool Contracts
- **VEIL 0.0005 ETH Contract:** `0x6c206B5389de4e5a23FdF13BF38104CE8Dd2eD5f`
- **VEIL 0.005 ETH Contract:** `0xC53510D6F535Ba0943b1007f082Af3410fBeA4F7`
- **VEIL 0.01 ETH Contract:** `0x844bB2917dD363Be5567f9587151c2aAa2E345D2`
- **VEIL 0.1 ETH Contract:** `0xD3560eF60Dd06E27b699372c3da1b741c80B7D90`
- **VEIL 1 ETH Contract:** `0x9cCdFf5f69d93F4Fcd6bE81FeB7f79649cb6319b`

### Verifier Contracts
- **MiMC Contract:** `0x69eBe2b99d656D5473D64e293f2aB693B405fACa`
- **Verifier Contract:** `0x1E65C075989189E607ddaFA30fa1a0001c376cfd`

---

## Project Structure

1. **Main Contract:** `src/proxy/VeilValidator.sol`
2. **Pool Contracts:** `src/pools/`
3. **Test Suite:** `test/proxy/`
4. **Supporting Scripts:** Located in `forge-ffi-scripts/`
   - **`generateWitness.js`**: Generates witness data for zero-knowledge proofs during withdrawal.
   - **`generateCommitment.js`**: Generates commitment data for deposits.

---

## Key Notes 

- **Fork Origin:** Tornado Cash L2 deployment (Arbitrum).
- **Modified Deposit Logic:** Deposits are restricted to the proxy contract.
- **Additional Features:**
  - Extra logging and commitment capturing.
  - Verification of user eligibility through EAS or whitelisting.

---