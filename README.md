#  Veil.Cash

Veil Cash is a non-custodial privacy protocol deployed on the Base Layer 2 (L2) blockchain. It leverages zk-SNARKs (Zero-Knowledge Succinct Non-Interactive Arguments of Knowledge) to enable users to achieve on-chain privacy and anonymity within trusted pools.

## Overview

Veil is a fork of Tornado Cash with several key changes:
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
## Links

**Website:**  [Veil Cash](https://veil.cash)

**Docs:**  [Gitbook Docs](https://docs.veil.cash)

**Twitter / X:**  [@veildotcash](https://x.com/veildotcash)