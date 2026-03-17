const { logger } = require("../utils/logger");

function runVersionCommand(version) {
  logger.plain(version);
}

module.exports = {
  runVersionCommand,
};
