/** Types describing LayerZero messages on the Perihelion Stellar ↔ EVM path. */

import type { Hex } from "@perihelion/sdk";

/** LayerZero endpoint identifiers for the chains Perihelion bridges. */
export type EndpointId = number;

/**
 * A cross-chain message carrying proof that a solver locked source funds for an
 * intent, instructing the destination chain to release the settlement assets.
 */
export interface BridgeMessage {
  /** LayerZero endpoint id of the source chain (where funds were locked). */
  readonly srcEid: EndpointId;
  /** LayerZero endpoint id of the destination chain (where assets release). */
  readonly dstEid: EndpointId;
  /** keccak256 commitment of the intent (its protocol-wide id). */
  readonly intentHash: Hex;
  /** Solver that locked the source funds and is owed the destination assets. */
  readonly solver: Hex;
  /** Destination recipient — the user's Stellar address. */
  readonly recipient: string;
  /** Destination asset identifier (e.g. `native` or `CODE:ISSUER`). */
  readonly destAsset: string;
  /** Amount to release, in destination-asset smallest units (decimal string). */
  readonly amount: string;
  /** Monotonic per-source-endpoint nonce for ordering and replay protection. */
  readonly nonce: number;
}

/** A {@link BridgeMessage} observed on-chain, awaiting relay to its destination. */
export interface PendingMessage {
  readonly message: BridgeMessage;
  /** Source-chain tx hash that emitted the message. */
  readonly srcTxHash: string;
  /** Block number the message was emitted in (for confirmation depth). */
  readonly srcBlock: number;
}

/** Outcome of attempting to relay a single message. */
export interface RelayResult {
  readonly intentHash: Hex;
  readonly delivered: boolean;
  /** Destination-chain tx hash, when delivered. */
  readonly dstTxHash?: string;
  readonly error?: string;
}
