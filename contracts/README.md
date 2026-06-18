# contracts/

The heart of the protocol — two coordinated contract sets that together provide
atomic cross-chain settlement.

```
contracts/
├── soroban/     # Stellar settlement contract (Rust / Soroban)
│   └── settlement/
└── evm/         # Source-chain escrow contract (Solidity / Foundry)
    ├── src/
    ├── test/
    └── script/
```

## Soroban settlement contract (`soroban/`)

Written in Rust, deployed on Stellar. Receives LayerZero messages, verifies that
each intent is settled at most once, and releases assets from its pre-funded
balance to the user's Stellar address. Designed to plug into the SEP-40 oracle
standard for accurate pricing at settlement time.

```bash
cd soroban
cargo test                                              # run unit tests
cargo build --target wasm32-unknown-unknown --release   # build deployable wasm
```

Key entrypoints (`settlement/src/lib.rs`):

| Function       | Purpose                                                  |
| -------------- | -------------------------------------------------------- |
| `initialize`   | Set admin + trusted LayerZero endpoint                   |
| `lz_receive`   | Endpoint-only; verify + settle an intent, release funds  |
| `is_settled`   | Replay-guard view                                        |
| `set_endpoint` | Admin-only endpoint rotation                             |

## EVM escrow contract (`evm/`)

Deployed on Ethereum, Base, and Arbitrum. A winning solver locks the user's
funds against the EIP-712 hash of their signed intent; funds are released to the
solver once Stellar settlement is confirmed via LayerZero, or refunded to the
user after the deadline.

```bash
cd evm
forge install foundry-rs/forge-std   # one-time: fetch test/script deps
forge build
forge test
```

Key functions (`src/PerihelionEscrow.sol`):

| Function        | Purpose                                                                  |
| --------------- | ------------------------------------------------------------------------ |
| `lock`          | Solver claims an intent, pulling the user's signed funds and dispatching a FillInstruction to Stellar over LayerZero |
| `lzReceive`     | Endpoint-only, peer-checked; releases to the solver on `FillConfirmed` or refunds the user on `CancelIntent` |
| `cancelExpired` | Permissionless local-timeout refund once `deadline + confirmationGrace` passes |
| `setPaused`     | Admin emergency halt — blocks new locks and local refunds (in-flight settlement still resolves) |
| `hashIntent`    | EIP-712 intent hash — identical to `@perihelion/sdk`                      |

> The EVM `DOMAIN_SEPARATOR` and `INTENT_TYPEHASH` are kept byte-for-byte
> consistent with the SDK's `PERIHELION_DOMAIN` / `INTENT_TYPES` so an intent
> signed off-chain by the SDK verifies on-chain without re-signing.
