/** Relayer runtime configuration, loaded from environment variables. */

export interface RelayerConfig {
  /** RPC endpoint for the EVM source chain. */
  readonly evmRpcUrl: string;
  /** Horizon / RPC endpoint for Stellar. */
  readonly stellarRpcUrl: string;
  /** Address of the EVM escrow contract emitting bridge messages. */
  readonly escrowAddress: string;
  /** Address of the Soroban settlement (OApp) contract. */
  readonly settlementContractId: string;
  /** Block confirmations to wait before relaying a source message. */
  readonly confirmations: number;
  /** Poll interval for new messages, milliseconds. */
  readonly pollIntervalMs: number;
}

/** Build config from `process.env`, applying sensible defaults. */
export function loadConfig(env: NodeJS.ProcessEnv = process.env): RelayerConfig {
  return {
    evmRpcUrl: env.PERIHELION_EVM_RPC_URL ?? "http://localhost:8545",
    stellarRpcUrl:
      env.PERIHELION_STELLAR_RPC_URL ?? "https://soroban-testnet.stellar.org",
    escrowAddress: env.PERIHELION_ESCROW_ADDRESS ?? "",
    settlementContractId: env.PERIHELION_SETTLEMENT_CONTRACT ?? "",
    confirmations: Number(env.PERIHELION_CONFIRMATIONS ?? 6),
    pollIntervalMs: Number(env.PERIHELION_POLL_INTERVAL_MS ?? 5_000),
  };
}
