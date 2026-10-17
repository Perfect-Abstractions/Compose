import { toProjectRelativePath } from "../../utils/files";
import { dim, green } from "../../utils/terminal";

/**
 * Prints the generated script source for `--dry-run` review.
 *
 * @param projectRoot - Absolute project root, used to shorten the displayed path.
 * @param scriptPath - Absolute path the script would be written to.
 * @param source - The rendered script source.
 */
export function showScriptPreview(projectRoot: string, scriptPath: string, source: string): void {
  console.log(`${green("Generated script")} ${dim(toProjectRelativePath(projectRoot, scriptPath))}`);
  console.log();
  console.log(source.endsWith("\n") ? source.slice(0, -1) : source);
  console.log();
}

/**
 * Prints the managed script location, relative to the project root.
 *
 * @param projectRoot - Absolute project root, used to shorten the displayed path.
 * @param scriptPath - Absolute path of the managed script.
 */
export function showScriptPath(projectRoot: string, scriptPath: string): void {
  console.log(`Script: ${toProjectRelativePath(projectRoot, scriptPath)}`);
}

/**
 * Prints the script location and the review-then-broadcast instruction.
 *
 * @param projectRoot - Absolute project root, used to shorten the displayed path.
 * @param scriptPath - Absolute path of the managed script.
 */
export function showScriptReady(projectRoot: string, scriptPath: string): void {
  showScriptPath(projectRoot, scriptPath);
  console.log(dim("Review it, then run 'compose deploy --broadcast' to execute it."));
}
