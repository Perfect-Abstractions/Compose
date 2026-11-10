import { describe, expect, it } from "vitest";
import { parseIgnitionJournalTransactionHash } from "../../../src/modules/deployExecution/ignitionJournal";

const DIAMOND_FUTURE = "ComposeDeploy#Diamond";
const DIAMOND_TX = `0x${"ab".repeat(32)}`;

describe("parseIgnitionJournalTransactionHash", () => {
  it("returns the successful confirmation hash for the exact future ID", () => {
    const journal = [
      JSON.stringify({
        type: "TRANSACTION_CONFIRM",
        futureId: "ComposeDeploy#Facet_0",
        hash: `0x${"11".repeat(32)}`,
        receipt: { status: "SUCCESS" },
      }),
      JSON.stringify({
        type: "TRANSACTION_CONFIRM",
        futureId: DIAMOND_FUTURE,
        hash: `0x${"22".repeat(32)}`,
        receipt: { status: "FAILURE" },
      }),
      JSON.stringify({
        type: "TRANSACTION_CONFIRM",
        futureId: DIAMOND_FUTURE,
        hash: DIAMOND_TX,
        receipt: { status: "SUCCESS" },
      }),
    ].join("\n");

    expect(parseIgnitionJournalTransactionHash(journal, DIAMOND_FUTURE)).toBe(DIAMOND_TX);
  });

  it("rejects a journal without a successful transaction for the future", () => {
    const journal = JSON.stringify({
      type: "TRANSACTION_CONFIRM",
      futureId: "ComposeDeploy#NotDiamond",
      hash: DIAMOND_TX,
      receipt: { status: "SUCCESS" },
    });

    expect(() => parseIgnitionJournalTransactionHash(journal, DIAMOND_FUTURE)).toThrow(
      "no successful transaction for future 'ComposeDeploy#Diamond'",
    );
  });

  it("rejects invalid journal JSON and malformed transaction hashes", () => {
    expect(() => parseIgnitionJournalTransactionHash("{not-json", DIAMOND_FUTURE)).toThrow(
      "Invalid JSON in Hardhat Ignition journal",
    );
    const invalidHash = JSON.stringify({
      type: "TRANSACTION_CONFIRM",
      futureId: DIAMOND_FUTURE,
      hash: "0x1234",
      receipt: { status: "SUCCESS" },
    });
    expect(() => parseIgnitionJournalTransactionHash(invalidHash, DIAMOND_FUTURE)).toThrow(
      "invalid transaction hash",
    );
  });
});
