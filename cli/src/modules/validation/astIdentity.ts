/** Matches a resolved source file with the source-unit name emitted by solc. */
export function matchesAstSource(
  compilerSourceName: string,
  resolvedSourcePath: string,
): boolean {
  let sourceName = normalizePath(compilerSourceName);
  let sourcePath = normalizePath(resolvedSourcePath);

  if (/^[a-zA-Z]:\//.test(sourcePath)) {
    sourceName = sourceName.toLowerCase();
    sourcePath = sourcePath.toLowerCase();
  }

  if (sourceName === sourcePath) return true;
  const relativeSourceName = sourceName.replace(/^\.\//, "").replace(/^\//, "");
  return sourcePath.endsWith(`/${relativeSourceName}`);
}

function normalizePath(value: string): string {
  return value.replace(/\\/g, "/").replace(/\/+$/, "");
}
