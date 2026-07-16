/**
 * Checks structural equality of two values via JSON serialization.
 *
 * @param left - First value.
 * @param right - Second value.
 * @returns `true` if both values are deeply equal by JSON comparison.
 *
 * @remarks
 * Limitations: key order matters, `undefined` values are ignored,
 * and `Date`/`Map`/`Set` are not handled correctly.
 */
export function isDeepEqual(left: unknown, right: unknown): boolean {
  return JSON.stringify(left) === JSON.stringify(right);
}
