import pc from "picocolors";

export const logger = {
  info(message: string) {
    console.log(pc.cyan(message));
  },
  success(message: string) {
    console.log(pc.green(message));
  },
  warn(message: string) {
    console.warn(pc.yellow(message));
  },
  brightYellow(message: string) {
    console.warn(pc.bold(pc.yellowBright(message)));
  },
  error(message: string) {
    console.error(pc.red(message));
  },
  plain(message: string) {
    console.log(message);
  },
};
