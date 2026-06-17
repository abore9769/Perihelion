#!/usr/bin/env node
/**
 * Entry point for the reference Perihelion solver node.
 *
 * Configure via environment variables (see `.env.example`) and run:
 *   perihelion-solver
 */

import { loadConfig } from "./config.js";
import { Solver, type Executor } from "./solver.js";
import type { SignedIntent } from "@perihelion/sdk";

/**
 * Placeholder executor. Wire this to:
 *  1. the EVM escrow contract (lock source funds against `signed.hash`), and
 *  2. the Soroban settlement contract (release dest assets after LayerZero
 *     confirms the message).
 */
class StubExecutor implements Executor {
  async fill(signed: SignedIntent): Promise<{ settlementTx: string }> {
    throw new Error(
      `executor not configured — cannot fill ${signed.hash}. ` +
        "Implement Executor against the EVM escrow and Soroban settlement contracts.",
    );
  }
}

async function main(): Promise<void> {
  const config = loadConfig();
  const solver = new Solver(config, new StubExecutor());

  const shutdown = () => {
    console.info("shutting down solver");
    solver.stop();
    process.exit(0);
  };
  process.on("SIGINT", shutdown);
  process.on("SIGTERM", shutdown);

  await solver.start();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
