/**
 * Wraps terminal text in ANSI cyan color codes.
 *
 * @param text - The text to colorize.
 * @returns The text wrapped in cyan escape sequences.
 */
export function cyan(text: string): string {
  return `\u001b[36m${text}\u001b[39m`;
}

/**
 * Wraps terminal text in ANSI red color codes.
 *
 * @param text - The text to colorize.
 * @returns The text wrapped in red escape sequences.
 */
export function red(text: string): string {
  return `\u001b[31m${text}\u001b[39m`;
}

/**
 * Wraps terminal text in ANSI green color codes.
 *
 * @param text - The text to colorize.
 * @returns The text wrapped in green escape sequences.
 */
export function green(text: string): string {
  return `\u001b[32m${text}\u001b[39m`;
}

/**
 * Wraps terminal text in ANSI yellow color codes.
 *
 * @param text - The text to colorize.
 * @returns The text wrapped in yellow escape sequences.
 */
export function yellow(text: string): string {
  return `\u001b[33m${text}\u001b[39m`;
}

/**
 * Wraps terminal text in ANSI blue color codes.
 *
 * @param text - The text to colorize.
 * @returns The text wrapped in blue escape sequences.
 */
export function blue(text: string): string {
  return `\u001b[34m${text}\u001b[39m`;
}

/**
 * Wraps terminal text in ANSI magenta color codes.
 *
 * @param text - The text to colorize.
 * @returns The text wrapped in magenta escape sequences.
 */
export function magenta(text: string): string {
  return `\u001b[35m${text}\u001b[39m`;
}

/**
 * Wraps terminal text in ANSI white color codes.
 *
 * @param text - The text to colorize.
 * @returns The text wrapped in white escape sequences.
 */
export function white(text: string): string {
  return `\u001b[37m${text}\u001b[39m`;
}

/**
 * Wraps terminal text in an off-white color using 256-color mode.
 *
 * @param text - The text to colorize.
 * @returns The text wrapped in dim escape sequences.
 */
export function dim(text: string): string {
  return `\u001b[38;5;250m${text}\u001b[39m`;
}
