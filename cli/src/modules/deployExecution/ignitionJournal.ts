import { isHex, type Hex } from "viem";

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

/** Reads the confirmed transaction hash for one Ignition future from a JSONL journal. */
export function parseIgnitionJournalTransactionHash(journal: string, futureId: string): Hex {
  const confirmations: unknown[] = [];

  for (const [index, line] of journal.split(/\r?\n/).entries()) {
    if (!line.trim()) continue;
    let record: unknown;
    try {
      record = JSON.parse(line) as unknown;
    } catch (error) {
      throw new Error(`Invalid JSON in Hardhat Ignition journal at line ${index + 1}.`, { cause: error });
    }
    if (!isRecord(record) || record.type !== "TRANSACTION_CONFIRM" || record.futureId !== futureId) continue;

    const receipt = record.receipt;
    if (isRecord(receipt) && receipt.status === "SUCCESS") confirmations.push(record.hash);
  }

  if (confirmations.length === 0) {
    throw new Error(`Hardhat Ignition journal has no successful transaction for future '${futureId}'.`);
  }

  const hash = confirmations.at(-1);
  if (typeof hash !== "string" || !isHex(hash) || hash.length !== 66) {
    throw new Error(`Hardhat Ignition journal contains an invalid transaction hash for future '${futureId}'.`);
  }
  return hash as Hex;
}
