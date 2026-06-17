<div align="center">

# Perihelion Protocol

**The shortest path between Stellar and every other chain.**

An open-source, intent-based cross-chain bridge connecting Stellar to
EVM-compatible networks.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)
[![Status: Early Development](https://img.shields.io/badge/status-early%20development-orange.svg)](#status)
[![Soroban](https://img.shields.io/badge/Stellar-Soroban-black.svg)](https://soroban.stellar.org)
[![Solidity](https://img.shields.io/badge/EVM-Solidity-363636.svg)](https://soliditylang.org)
[![TypeScript](https://img.shields.io/badge/SDK-TypeScript-3178c6.svg)](https://www.typescriptlang.org)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](./docs/CONTRIBUTING.md)

[Overview](#overview) ·
[How It Works](#how-it-works) ·
[Architecture](#architecture) ·
[Getting Started](#getting-started) ·
[Documentation](#documentation) ·
[Contributing](#contributing)

</div>

---

## Overview

Perihelion lets a user declare a simple intent — _"I want X amount of asset Y on
Stellar"_ — and a decentralized network of solvers competes to fulfill it,
atomically and at the best available rate. No manual bridging steps, no token
wrapping, no multi-transaction dance.

It is built natively on [Soroban](https://soroban.stellar.org), Stellar's smart
contract platform, and is designed for the way Stellar actually works: fast
finality, low fees, and a growing ecosystem of real-world assets that need
seamless liquidity connections to the rest of the blockchain world.

### The problem

Stellar has become critical financial infrastructure — over \$2B in tokenized
real-world assets, institutional-grade stablecoins (USDC, EURC, YLDS, MGUSD), and
payment rails used by MoneyGram, Franklin Templeton, and PayPal.

But moving assets _onto_ Stellar from Ethereum, Base, or any other major chain
still requires centralized exchanges, manual DEX hops, or fragile lock-and-mint
bridges that introduce custodial risk and poor UX. Capital that should be flowing
into Stellar's DeFi, lending, and RWA platforms sits on other chains because the
on-ramp is too hard. **Perihelion closes that gap.**

## How It Works

Perihelion uses an **intent + solver** architecture — the model behind UniswapX
and CoW Protocol on Ethereum, adapted for Stellar.

1. **The user declares an intent.** They sign a structured message off-chain
   specifying the asset and amount to receive on Stellar, the asset and chain to
   spend from, a deadline, and a slippage floor. No transaction, no gas yet.
2. **Solvers compete to fill it.** A decentralized network of solvers monitors
   the intent mempool and races to fill profitable orders. The winner earns the
   spread.
3. **Atomic settlement.** The user's funds are locked in the source-chain escrow
   against a cryptographic commitment; the solver fronts liquidity on Stellar;
   the escrow releases the locked funds to the solver once settlement is verified.
   If the deadline passes without a fill, the user is refunded in full.
4. **Cross-chain messaging** is carried by [LayerZero](https://layerzero.network),
   with Stellar's native ZK proof support (Protocol 24) used where applicable to
   minimize trust.

## Architecture

```
User Intent (signed off-chain)
        │
        ▼
Intent Mempool (open, permissionless)
        │
        ├──► Solver A evaluates
        ├──► Solver B evaluates
        └──► Solver C evaluates
                    │
                    ▼
        Winning Solver executes
                    │
         ┌──────────┴──────────┐
         ▼                     ▼
Source Chain Escrow     Soroban Settlement
(EVM Contract)          Contract (Stellar)
         │                     │
         └──── LayerZero ──────┘
              Message Relay
                    │
                    ▼
         User receives assets
         on Stellar ✓
```

A single value — the EIP-712 `intent_hash` — ties every leg together: it is the
commitment the escrow locks against, the id carried in each LayerZero message,
and the key the settlement contract uses for replay protection. For the full
design, see the
[Technical Architecture Specification](./docs/TECHNICAL-ARCHITECTURE.md).

## Repository Layout

| Path         | Description                                                         |
| ------------ | ------------------------------------------------------------------- |
| `contracts/` | Soroban (Rust) settlement contract + EVM (Solidity) escrow contract |
| `sdk/`       | TypeScript SDK for intent construction, signing, and submission     |
| `solver/`    | Reference solver node — monitors the mempool and fills intents      |
| `relayer/`   | LayerZero message relayer for the Stellar ↔ EVM path                |
| `docs/`      | Protocol specifications and integration guides                      |

This is an [npm workspaces](https://docs.npmjs.com/cli/using-npm/workspaces)
monorepo for the TypeScript packages (`sdk`, `solver`, `relayer`), a Cargo
workspace for the Soroban contracts, and a Foundry project for the EVM contracts.

## Tech Stack

| Layer                   | Technology                    |
| ----------------------- | ----------------------------- |
| Stellar smart contracts | Rust / Soroban                |
| EVM contracts           | Solidity / Foundry            |
| Cross-chain messaging   | LayerZero                     |
| ZK verification         | BN254 / Stellar Protocol 24   |
| Oracle pricing          | SEP-40 / RedStone             |
| Solver, SDK, relayer    | TypeScript / Node.js          |
| Intent standard         | EIP-712 style signed messages |

## Getting Started

### Prerequisites

| Tool                                                                 | Used for             | Required version |
| -------------------------------------------------------------------- | -------------------- | ---------------- |
| [Node.js](https://nodejs.org)                                        | SDK, solver, relayer | ≥ 20             |
| [Rust](https://rustup.rs) + `wasm32-unknown-unknown` target          | Soroban contracts    | stable           |
| [Stellar CLI](https://developers.stellar.org/docs/tools/stellar-cli) | Soroban build/deploy | latest           |
| [Foundry](https://book.getfoundry.sh)                                | EVM contracts        | latest           |

> The TypeScript packages build and test with only Node.js installed; the Rust
> and Foundry toolchains are needed solely for the contracts.

### Install & build

```bash
# 1. TypeScript workspaces (sdk, solver, relayer)
npm install
npm run build
npm test

# 2. Soroban settlement contract
cd contracts/soroban
cargo test
cargo build --target wasm32-unknown-unknown --release

# 3. EVM escrow contract
cd contracts/evm
forge install foundry-rs/forge-std   # one-time
forge build
forge test
```

### Use the SDK

```ts
import { PerihelionClient, buildIntent } from "@perihelion/sdk";

const client = new PerihelionClient({ mempoolUrl: "https://mempool.perihelion.xyz" });

const intent = buildIntent({
  user: account.address,
  destination: "GUSER...STELLAR",
  sourceChainId: 8453,            // Base
  sourceAsset: "0x833589...",     // USDC on Base
  sourceAmount: "1000000",        // 1 USDC (6 decimals)
  destAsset: "USDC:GA5Z...",      // USDC on Stellar
  minDestAmount: "9900000",       // accept >= 0.99 (7 decimals)
  deadline: Math.floor(Date.now() / 1000) + 600,
});

const signed = await client.signIntent(wallet, intent);
const hash = await client.submitIntent(signed);
const result = await client.waitForSettlement(hash);
```

See the [`sdk/` README](./sdk/README.md) for the full API.

## Documentation

| Document                                                                | Description                                                                 |
| ----------------------------------------------------------------------- | --------------------------------------------------------------------------- |
| [Technical Architecture](./docs/TECHNICAL-ARCHITECTURE.md)              | Full production spec: contracts, LayerZero V2, solver economics, security, testing, rollout |
| [Architecture Overview](./docs/architecture.md)                         | High-level settlement flow and trust model                                  |
| [Intent Specification](./docs/intent-spec.md)                           | The signable intent format and EIP-712 encoding                             |
| [Contributing Guide](./docs/CONTRIBUTING.md)                            | How to contribute and where the work lives                                  |
| Component READMEs                                                       | [contracts](./contracts/README.md) · [sdk](./sdk/README.md) · [solver](./solver/README.md) · [relayer](./relayer/README.md) |

## Status

Perihelion is in **active early development**. Current focus: the Soroban
settlement contract and the intent specification. The interfaces and on-chain
formats described here are not yet stable and may change before the first
audited release. **Do not use in production.**

We build in public — see the [roadmap](./docs/TECHNICAL-ARCHITECTURE.md#8-phased-rollout)
for the phased rollout and audit gates.

## Contributing

Contributions are welcome at every level — from architecture discussions to the
first lines of contract code. The project is structured around clearly scoped,
skill-tagged issues designed for [Drips Wave](https://stellar.org) sprint cycles.

Start with the [Contributing Guide](./docs/CONTRIBUTING.md) and the
[issue taxonomy](./docs/TECHNICAL-ARCHITECTURE.md#9-contribution-guide-for-drips-wave).

## Security

Perihelion is unaudited and under active development. If you discover a
vulnerability, please **do not open a public issue** — disclosure instructions
will be published in `SECURITY.md`. Until then, contact the maintainers directly.

## License

Licensed under the [MIT License](./LICENSE).

---

<div align="center">

_Perihelion — named for the point of closest approach between two orbiting
bodies. The shortest, most efficient path between Stellar and the rest of the
blockchain universe._

</div>
