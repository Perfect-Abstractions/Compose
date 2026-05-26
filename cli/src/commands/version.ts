import { logger } from "../utils/logger.js";

export function runVersionCommand(version: string): void {
  logger.plain(version);
}
