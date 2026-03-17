const pc = require("picocolors");

const logger = {
  info(message) {
    console.log(pc.cyan(message));
  },
  success(message) {
    console.log(pc.green(message));
  },
  warn(message) {
    console.warn(pc.yellow(message));
  },
  error(message) {
    console.error(pc.red(message));
  },
  plain(message) {
    console.log(message);
  },
};

module.exports = {
  logger,
};
