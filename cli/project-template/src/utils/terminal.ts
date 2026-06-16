// Wrap terminal text in ANSI cyan color codes.
export function cyan(text: string): string {
  return `\u001b[36m${text}\u001b[39m`;
}

// Wrap terminal text in ANSI red color codes.
export function red(text: string): string {
  return `\u001b[31m${text}\u001b[39m`;
}

// Wrap terminal text in ANSI yellow color codes.
export function yellow(text: string): string {
  return `\u001b[33m${text}\u001b[39m`;
}
