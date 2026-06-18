# Cross-chain wire-format conformance vectors

Golden test vectors for the two **Stellar → source-chain** LayerZero messages —
the fund-moving payloads. These are the single source of truth for the binary
layout: the Soroban encoder (`contracts/soroban/.../messages.rs`) and the EVM
decoder (`contracts/evm/.../PerihelionEscrow.sol`) each have a conformance test
that reads these exact files, so the two implementations cannot drift apart
without a test going red.

Both files hold one `0x`-prefixed hex string, no trailing newline.

## `fill_confirmed.hex` (90 bytes)

`version(1) | type(1) | intent_hash(32) | solver_evm(32) | amount(16) | ledger(8)`

| Field         | Canonical value                                  |
| ------------- | ------------------------------------------------ |
| `version`     | `0x01`                                           |
| `type`        | `0x02` (FillConfirmed)                            |
| `intent_hash` | 32 bytes of `0x11`                               |
| `solver_evm`  | 32-byte word; low 20 bytes = the EVM address `0xAA…AA` |
| `amount`      | `1_000_000` (u128, big-endian)                   |
| `ledger`      | `42` (u64, big-endian)                           |

## `cancel_intent.hex` (35 bytes)

`version(1) | type(1) | intent_hash(32) | reason(1)`

| Field         | Canonical value             |
| ------------- | --------------------------- |
| `version`     | `0x01`                      |
| `type`        | `0x03` (CancelIntent)       |
| `intent_hash` | 32 bytes of `0x22`          |
| `reason`      | `0x00` (`CANCEL_REASON_EXPIRED`) |

> The **inbound** FillInstruction (source → Stellar) is not pinned here: it
> carries variable-length Stellar addresses and its raw codec is finalized at
> the adapter boundary once the Soroban LayerZero ABI is GA (architecture spec
> §3.3). Only the fully-specified, fixed-length outbound payloads are locked.
