import { cyan, dim } from "../../utils/terminal";
import type { HistoryParameter, HistoryResult } from "./types";

function displayValue(parameter: HistoryParameter): string {
  const value = String(parameter.value);
  if (parameter.type === "bytes" && value.length > 82) return `${value.slice(0, 82)}...`;
  return value;
}

function parameterLabel(name: string): string {
  const words = name.replace(/^_/, "").replace(/([a-z])([A-Z])/g, "$1 $2");
  return `${words.charAt(0).toUpperCase()}${words.slice(1)}`;
}

/** Shared event frame; event-specific fields come from the decoded ABI. */
export function showHistory(result: HistoryResult): void {
  console.log(`\nDiamond: ${result.diamond}`);
  console.log(`Chain: ${result.chainKey} (${result.chainId})`);
  console.log();
  console.log(cyan("Upgrade History:"));
  console.log();

  if (result.events.length === 0) {
    console.log(dim("  No ERC-8153 events found"));
    return;
  }

  for (const event of result.events) {
    const time = new Date(Number(event.timestamp) * 1_000).toISOString().slice(0, 19).replace("T", " ");
    console.log(`Block ${event.blockNumber} (${time} UTC)`);
    console.log(`  Tx: ${event.transactionHash}`);
    console.log(`  Event: ${event.name}`);
    for (const parameter of event.parameters) {
      console.log(`    ${parameterLabel(parameter.name)}: ${displayValue(parameter)}`);
    }
    console.log();
  }
}
