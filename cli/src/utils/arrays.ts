/**
 * Deduplicates an array by a key function, keeping the first occurrence of each unique key.
 *
 * @param items - Array of items to deduplicate.
 * @param keyFn - Function that extracts the deduplication key from an item.
 * @returns A new array with only the first occurrence of each unique key.
 */
export function dedupeBy<T>(items: T[], keyFn: (item: T) => string): T[] {
  const seen = new Set<string>();
  return items.filter((item) => {
    const key = keyFn(item);
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}

/**
 * Checks whether one array is a prefix of another.
 *
 * @param prefix - The potential prefix array.
 * @param array - The array to check against.
 * @returns True if `prefix` matches the beginning of `array`.
 */
export function isArrayPrefix<T>(prefix: T[], array: T[]): boolean {
  if (prefix.length > array.length) return false;
  return prefix.every((value, index) => array[index] === value);
}
