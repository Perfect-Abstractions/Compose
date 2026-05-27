import { createRequire } from "node:module";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const require = createRequire(import.meta.url);

const pkg = require(resolve(__dirname, "..", "..", "package.json"));
import { COMPOSE_DOCS_URL } from "../config/constants.js";

export const HELP_TEXT = `
Compose CLI v${pkg.version}

Scaffolds Diamond-based projects using the Compose Library

Usage:
  compose init [options]
  compose --version | -v
  compose update

Options:
  --name <project-name>
  --template <template-id>
  --framework <foundry|hardhat>
  --language <javascript|typescript>
  --install-deps | --no-install-deps
  --yes
  --help

For more information about the Compose, see: ${COMPOSE_DOCS_URL}
`;
