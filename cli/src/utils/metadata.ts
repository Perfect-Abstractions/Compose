import fs from "node:fs";
import path from "node:path";
import { CLI_ROOT } from "./cliRoot";

function readVersion(): string {
  const pkgPath = path.join(CLI_ROOT, "package.json");
  const pkg = JSON.parse(fs.readFileSync(pkgPath, "utf8"));
  return pkg.version;
}

export const COMPOSE_DOCS_URL = "https://compose.diamonds/";
export const VERSION = readVersion();
export const LOCK_FILE_NAME = "compose.lock";

/** npm package that provides the `compose` binary. */
export const CLI_PACKAGE_NAME = "@perfect-abstractions/compose-cli";

/** Version range written into generated projects so they run the CLI locally. */
export const CLI_DEV_DEPENDENCY_VERSION = `^${VERSION}`;

export const COMPOSE_HEADER = `
   _____ ____  __  __ _____   ____   _____ ______     _____ _      _____ 
  / ____/ __ \\|  \\/  |  __ \\ / __ \\ / ____|  ____|   / ____| |    |_   _|
 | |   | |  | | \\  / | |__) | |  | | (___ | |__     | |    | |      | |  
 | |   | |  | | |\\/| |  ___/| |  | |\\___ \\|  __|    | |    | |      | |  
 | |___| |__| | |  | | |    | |__| |____) | |____   | |____| |____ _| |_ 
  \\_____\\____/|_|  |_|_|     \\____/|_____/|______|   \\_____|______|_____|
  
  `;
