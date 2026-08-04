import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

function readVersion(): string {
  const pkgPath = path.resolve(__dirname, "..", "..", "package.json");
  const pkg = JSON.parse(fs.readFileSync(pkgPath, "utf8"));
  return pkg.version;
}

export const COMPOSE_DOCS_URL = "https://compose.diamonds/";
export const VERSION = readVersion();
export const LOCK_FILE_NAME = "compose.lock";

export const COMPOSE_HEADER = `
   _____ ____  __  __ _____   ____   _____ ______     _____ _      _____ 
  / ____/ __ \\|  \\/  |  __ \\ / __ \\ / ____|  ____|   / ____| |    |_   _|
 | |   | |  | | \\  / | |__) | |  | | (___ | |__     | |    | |      | |  
 | |   | |  | | |\\/| |  ___/| |  | |\\___ \\|  __|    | |    | |      | |  
 | |___| |__| | |  | | |    | |__| |____) | |____   | |____| |____ _| |_ 
  \\_____\\____/|_|  |_|_|     \\____/|_____/|______|   \\_____|______|_____|
  
  `;

