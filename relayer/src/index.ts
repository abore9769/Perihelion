#!/usr/bin/env node
/**
 * Entry point for the Perihelion LayerZero relayer.
 *
 * Configure via environment variables (see `.env.example`) and run:
 *   perihelion-relayer
 */

import { loadConfig } from "./config.js";
import { Relayer } from "./relayer.js";
import type {
  DestinationDelivery,
  SourceWatcher,
} from "./relayer.js";
import type { PendingMessage } from "./types.js";

/**
 * Placeholder source watcher. Wire this to the EVM escrow contract: subscribe
 * to the `MessageSent` event and decode each into a {@link PendingMessage}.
 */
class StubWatcher implements SourceWatcher {
  async poll(fromBlock: number) {
    return { messages: [] as PendingMessage[], head: fromBlock };
  }
}

/**
 * Placeholder destination delivery. Wire this to the Soroban settlement
 * contract's `lz_receive` entrypoint and an `isDelivered` view.
 */
class StubDelivery implements DestinationDelivery {
  async deliver(pending: PendingMessage): Promise<string> {
    throw new Error(
      `delivery not configured — cannot relay ${pending.message.intentHash}. ` +
        "Implement DestinationDelivery against the Soroban settlement contract.",
    );
  }
  async isDelivered(): Promise<boolean> {
    return false;
  }
}

async function main(): Promise<void> {
  const config = loadConfig();
  const relayer = new Relayer(config, new StubWatcher(), new StubDelivery());

  const shutdown = () => {
    console.info("shutting down relayer");
    relayer.stop();
    process.exit(0);
  };
  process.on("SIGINT", shutdown);
  process.on("SIGTERM", shutdown);

  await relayer.start();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
