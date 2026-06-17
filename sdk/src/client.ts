/**
 * Client for submitting intents to a Perihelion mempool and tracking status.
 *
 * The common integration path is three calls: sign an intent, submit it, then
 * poll (or `await`) until it settles.
 */

import type { WalletClient } from "viem";
import { hashIntent, INTENT_TYPES, PERIHELION_DOMAIN } from "./intent.js";
import type {
  Hex,
  Intent,
  IntentRecord,
  SignedIntent,
} from "./types.js";

export interface ClientOptions {
  /** Base URL of the Perihelion mempool / relayer API. */
  readonly mempoolUrl: string;
  /** Override the fetch implementation (defaults to global `fetch`). */
  readonly fetch?: typeof fetch;
}

/** Thin client over a Perihelion mempool endpoint. */
export class PerihelionClient {
  private readonly base: string;
  private readonly fetchImpl: typeof fetch;

  constructor(opts: ClientOptions) {
    this.base = opts.mempoolUrl.replace(/\/$/, "");
    this.fetchImpl = opts.fetch ?? globalThis.fetch;
  }

  /** Sign an intent with a viem wallet, producing a {@link SignedIntent}. */
  async signIntent(
    wallet: WalletClient,
    intent: Intent,
  ): Promise<SignedIntent> {
    const account = wallet.account;
    if (!account) throw new Error("wallet client has no account");
    const signature = (await wallet.signTypedData({
      account,
      domain: PERIHELION_DOMAIN,
      types: INTENT_TYPES,
      primaryType: "Intent",
      message: {
        user: intent.user,
        destination: intent.destination,
        sourceChainId: BigInt(intent.sourceChainId),
        sourceAsset: intent.sourceAsset,
        sourceAmount: BigInt(intent.sourceAmount),
        destAsset: intent.destAsset,
        minDestAmount: BigInt(intent.minDestAmount),
        deadline: BigInt(intent.deadline),
        nonce: BigInt(intent.nonce),
        preferredSolver: intent.preferredSolver,
      },
    })) as Hex;
    return { intent, signature, hash: hashIntent(intent) };
  }

  /** Submit a signed intent to the mempool. Returns its hash (id). */
  async submitIntent(signed: SignedIntent): Promise<Hex> {
    const res = await this.fetchImpl(`${this.base}/intents`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify(signed),
    });
    if (!res.ok) {
      throw new Error(`submitIntent failed: ${res.status} ${await res.text()}`);
    }
    const body = (await res.json()) as { hash: Hex };
    return body.hash;
  }

  /** Fetch the current record for an intent by its hash. */
  async getIntent(hash: Hex): Promise<IntentRecord> {
    const res = await this.fetchImpl(`${this.base}/intents/${hash}`);
    if (!res.ok) {
      throw new Error(`getIntent failed: ${res.status} ${await res.text()}`);
    }
    return (await res.json()) as IntentRecord;
  }

  /**
   * Poll until the intent reaches a terminal state (`settled`, `refunded`, or
   * `expired`) or the timeout elapses.
   */
  async waitForSettlement(
    hash: Hex,
    opts: { intervalMs?: number; timeoutMs?: number } = {},
  ): Promise<IntentRecord> {
    const interval = opts.intervalMs ?? 3_000;
    const deadline = Date.now() + (opts.timeoutMs ?? 5 * 60_000);
    const terminal = new Set(["settled", "refunded", "expired"]);
    for (;;) {
      const record = await this.getIntent(hash);
      if (terminal.has(record.status)) return record;
      if (Date.now() > deadline) {
        throw new Error(`waitForSettlement timed out for ${hash}`);
      }
      await sleep(interval);
    }
  }
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
