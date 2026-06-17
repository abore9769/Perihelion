import assert from "node:assert/strict";
import { test } from "node:test";
import { buildIntent } from "@perihelion/sdk";
import { loadConfig } from "../src/config.js";
import { evaluate } from "../src/quote.js";

const config = loadConfig({
  PERIHELION_SUPPORTED_ASSETS: "native,USDC:GA5Z",
  PERIHELION_MIN_MARGIN_BPS: "10",
});

function intent(overrides: Partial<Parameters<typeof buildIntent>[0]> = {}) {
  return buildIntent({
    user: "0x0000000000000000000000000000000000000001",
    destination: "GUSER",
    sourceChainId: 8453,
    sourceAsset: "0x0000000000000000000000000000000000000002",
    sourceAmount: "1000000",
    destAsset: "USDC:GA5Z",
    minDestAmount: "9900000",
    deadline: 4102444800,
    ...overrides,
  });
}

test("fills a profitable, supported intent", async () => {
  const decision = await evaluate(intent(), config);
  assert.equal(decision.fill, true);
});

test("rejects unsupported dest asset", async () => {
  const decision = await evaluate(intent({ destAsset: "EURC:GBBB" }), config);
  assert.equal(decision.fill, false);
});

test("rejects when minDestAmount cannot be met", async () => {
  const decision = await evaluate(intent({ minDestAmount: "999999999" }), config);
  assert.equal(decision.fill, false);
});

test("rejects expired intents", async () => {
  const decision = await evaluate(intent({ deadline: 1 }), config);
  assert.equal(decision.fill, false);
  assert.equal(decision.reason, "intent expired");
});
