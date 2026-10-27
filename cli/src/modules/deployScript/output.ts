import { toProjectRelativePath } from "../../utils/files";
import { dim, green } from "../../utils/terminal";

/**
 * Prints the managed deployment artifact location and review instructions.
 *
 * @param projectRoot - Absolute project root, used to shorten the displayed path.
 * @param scriptPath - Absolute path of the managed script.
 */
export function showScriptReady(projectRoot: string, scriptPath: string): void {
  console.log(`${green("Deployment artifact ready")}: ${toProjectRelativePath(projectRoot, scriptPath)}`);
  console.log(dim("Review this artifact before deploying."));
  console.log(dim("When ready, run 'compose deploy --broadcast' to send transactions."));
}
