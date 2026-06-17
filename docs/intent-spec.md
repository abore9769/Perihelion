# Intent Specification

An **intent** is a structured, off-chain message a user signs to declare what
they want from the bridge. It carries no execution details — only the desired
outcome and the constraints under which a solver may fill it.

## Fields

| Field             | Type      | Description                                                        |
| ----------------- | --------- | ----------------------------------------------------------------- |
| `user`            | `address` | EVM address funding the source leg; the EIP-712 signer            |
| `destination`     | `string`  | Stellar address that receives settled assets (`G...` / `C...`)    |
| `sourceChainId`   | `uint256` | EVM chain id spent from (1 = Ethereum, 8453 = Base, …)            |
| `sourceAsset`     | `address` | ERC-20 token spent on the source chain                            |
| `sourceAmount`    | `uint256` | Amount of `sourceAsset` locked, in smallest units                |
| `destAsset`       | `string`  | Stellar asset wanted: `native` or `<CODE>:<ISSUER>`              |
| `minDestAmount`   | `uint256` | Minimum acceptable amount on Stellar (slippage floor)            |
| `deadline`        | `uint256` | Unix seconds after which the intent is void and refundable       |
| `nonce`           | `uint256` | Unique value preventing replay/collision of identical intents    |
| `preferredSolver` | `address` | Optional exclusive solver; `address(0)` = open to all            |

All amounts are decimal strings in the asset's smallest unit, preserving
precision across the EVM (typically 6–18 decimals) and Stellar (7 decimals).

## EIP-712 encoding

The intent is hashed and signed per [EIP-712](https://eips.ethereum.org/EIPS/eip-712).

**Domain** — intentionally minimal so the same signature is valid across every
supported source chain:

```
EIP712Domain(string name,string version)
name    = "Perihelion"
version = "1"
```

**Type:**

```
Intent(
  address user,
  string destination,
  uint256 sourceChainId,
  address sourceAsset,
  uint256 sourceAmount,
  string destAsset,
  uint256 minDestAmount,
  uint256 deadline,
  uint256 nonce,
  address preferredSolver
)
```

The struct hash encodes dynamic fields (`destination`, `destAsset`) as the
keccak256 of their UTF-8 bytes. The final digest is:

```
keccak256(0x1901 ‖ domainSeparator ‖ structHash)
```

This digest is the **intent hash** — the protocol-wide identifier used by the
escrow lock key, the relayer message, and the settlement replay guard.

> The reference implementation lives in `sdk/src/intent.ts` (`hashIntent`) and is
> mirrored exactly in `contracts/evm/src/PerihelionEscrow.sol` (`hashIntent`).
> Any change to the domain or type must be made in both places.

## Lifecycle

```
pending ──claimed──► claimed ──settling──► settled       (success)
   │                                          
   └──deadline──► expired                      (never claimed)
                                              
claimed ──deadline w/o settlement──► refunded  (claimed but not settled)
```

| Status     | Meaning                                            |
| ---------- | -------------------------------------------------- |
| `pending`  | Signed, in the mempool, unclaimed                  |
| `claimed`  | A solver locked the source funds                   |
| `settling` | Cross-chain message in flight                      |
| `settled`  | Assets released on Stellar                         |
| `refunded` | Deadline passed after claim; source funds returned |
| `expired`  | Deadline passed before any claim                   |
