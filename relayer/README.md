# @perihelion/relayer

A lightweight LayerZero message relayer optimized for the Perihelion
**Stellar ↔ EVM** path. Open source and permissionlessly runnable, so the
messaging layer has no single point of failure.

## What it does

The relayer watches the EVM escrow contract for locked-fund commitments, waits
for a configurable confirmation depth, and delivers each verified message to the
Soroban settlement contract's `lz_receive` entrypoint.

```
EVM escrow ──emit MessageSent──► [relayer: confirm N blocks] ──► Soroban settlement
                                                                  (verifies + releases)
```

It is **trust-minimized**: the relayer only transports messages whose
authenticity the destination verifies independently (LayerZero DVN stack, plus
Stellar Protocol 24 ZK proofs where available). A faulty relayer can delay or
censor, but cannot forge a delivery — and anyone can run another.

## Run

```bash
npm install
cp .env.example .env   # then edit
npm run build && npm start
# or, for local development:
npm run dev
```

## Customizing

Two extension points to implement for a live deployment:

1. **`SourceWatcher`** — subscribe to the EVM escrow's `MessageSent` event and
   decode each log into a `PendingMessage`.
2. **`DestinationDelivery`** — submit the message to the Soroban settlement
   contract and expose an `isDelivered` view for the replay guard.

| Module        | Responsibility                                     |
| ------------- | -------------------------------------------------- |
| `types.ts`    | `BridgeMessage` / `PendingMessage` / `RelayResult` |
| `config.ts`   | Load config from environment                       |
| `relayer.ts`  | The watch → confirm → deliver loop                 |
| `index.ts`    | CLI entry point + graceful shutdown                |
