#!/usr/bin/env node

const minimist = require("minimist");
const pkg = require("./package.json");
const { logger } = require("./src/utils/logger");
const { exitWithError } = require("./src/utils/errors");
const { runInitCommand } = require("./src/commands/init");
const { runVersionCommand } = require("./src/commands/version");
const { runUpdateCommand } = require("./src/commands/update");
const { runListTemplatesCommand } = require("./src/commands/listTemplates");
const { HELP_TEXT } = require("./src/utils/helpText");

async function main() {
  const argv = minimist(process.argv.slice(2), {
    alias: {
      v: "version",
      h: "help",
      n: "name",
    },
    boolean: ["version", "help", "yes"],
    string: ["name", "template", "framework", "language"],
  });

  const [command = ""] = argv._;

  if (argv.version) {
    runVersionCommand(pkg.version);
    return;
  }

  if (argv.help || !command) {
    logger.plain(HELP_TEXT.trim());
    return;
  }

  if (command === "init") {
    await runInitCommand(argv);
    return;
  }

  if (command === "update") {
    await runUpdateCommand(pkg.name);
    return;
  }

  if (command === "templates") {
    await runListTemplatesCommand();
    return;
  }

  throw new Error(`Unknown command: ${command}. Run 'compose --help' for available commands.`);
}

main().catch((error) => {
  exitWithError(error);
});
