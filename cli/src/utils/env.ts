import dotenv from "dotenv";
import path from "node:path";
import { locateComposeProjectFile } from "./composeProjectFile";

/**
 * Loads the `.env` file for the nearest Compose project, or the starting
 * directory when no Compose project is present. Parent and nested `.env` files
 * are deliberately ignored so another project cannot affect this command.
 * Existing process environment values keep dotenv's default precedence.
 */
export async function loadProjectEnv(startDirectory: string = process.cwd()): Promise<void> {
  const resolvedStartDirectory = path.resolve(startDirectory);
  const composeProject = await locateComposeProjectFile(resolvedStartDirectory);
  const projectRoot = composeProject?.root ?? resolvedStartDirectory;

  dotenv.config({ path: path.join(projectRoot, ".env") });
}
