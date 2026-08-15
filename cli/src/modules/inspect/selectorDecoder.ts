import { keccak256, slice, toBytes, type Hex } from "viem";
import { loadProjectSignatures } from "./abiLoader";
import { COMMON_SIGNATURES } from "./commonSignatures";

const SELECTOR_MAP = new Map<string, string>();

/**
 * Lazily populates the selector lookup map from {@link COMMON_SIGNATURES}.
 * Subsequent calls are no-ops once the map is initialized.
 */
function ensureSelectorMap(): void {
  if (SELECTOR_MAP.size > 0) return;
  for (const sig of COMMON_SIGNATURES) {
    const trimmed = sig.trim();
    if (!trimmed) continue;
    const hash = keccak256(toBytes(trimmed));
    const selector = slice(hash, 0, 4);
    SELECTOR_MAP.set(selector.toLowerCase(), trimmed);
  }
}

/**
 * Decodes a 4-byte function selector into its human-readable signature.
 *
 * Falls back to returning the raw hex when no match is found in either the
 * common signatures or the project-specific ABI files.
 *
 * @param selector - The 4-byte selector (e.g., `"0x313ce567"`).
 * @returns The matched function signature, or the original hex string.
 */
export function decodeSelector(selector: string | Hex): string {
  ensureSelectorMap();
  const key = selector.toLowerCase();
  return SELECTOR_MAP.get(key) ?? selector;
}

/**
 * Augments the selector lookup map with signatures extracted from the project's
 * compiled ABI files (artifacts or out directory).
 *
 * Existing entries are never overwritten, so common signatures take precedence.
 *
 * @param projectRoot - Absolute path to the project root containing
 *     `compose.json`.
 */
export async function mergeProjectSignatures(projectRoot: string): Promise<void> {
  ensureSelectorMap();
  const projectMap = await loadProjectSignatures(projectRoot);
  for (const [selector, signature] of projectMap) {
    if (!SELECTOR_MAP.has(selector)) {
      SELECTOR_MAP.set(selector, signature);
    }
  }
}
