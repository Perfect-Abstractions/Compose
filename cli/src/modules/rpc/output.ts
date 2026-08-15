import { cyan, dim, green, yellow } from "../../utils/terminal";
import type { RPCCheckResult } from "./types";

/** Displays the result of a real RPC connectivity check. */
export function showRPCCheck(result: RPCCheckResult): void {
  console.log(`\n${cyan("RPC Check")}\n`);
  console.log(`  ${dim("Chain:")} ${result.chainKey}`);
  console.log(`  ${dim("Chain ID:")} ${result.chainId}`);
  console.log(`  ${dim("Endpoint:")} ${green("connected")}`);

  if (result.address) {
    const status = result.hasCode ? green("deployed") : yellow("no bytecode");
    console.log(`  ${dim("Address:")} ${result.address}`);
    console.log(`  ${dim("Bytecode:")} ${status}`);
  }

  console.log(`  ${dim("Result:")} ${green("passed")}\n`);
}
