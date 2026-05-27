import fs from "fs-extra";
import path from "node:path";

export async function replaceTokensInFile(
  filePath: string,
  tokenMap: Record<string, string>
): Promise<void> {
  const content: string = await fs.readFile(filePath, "utf8");
  let updated = content;

  Object.entries(tokenMap).forEach(([token, value]) => {
    updated = updated.split(token).join(value);
  });

  if (updated !== content) {
    await fs.writeFile(filePath, updated);
  }
}

export async function replaceTokensRecursively(
  rootDir: string,
  tokenMap: Record<string, string>
): Promise<void> {
  const entries = await fs.readdir(rootDir);

  await Promise.all(
    entries.map(async (entry) => {
      const fullPath = path.join(rootDir, entry);
      const stat = await fs.stat(fullPath);

      if (stat.isDirectory()) {
        await replaceTokensRecursively(fullPath, tokenMap);
        return;
      }

      const textExtensions = [".md", ".txt", ".json", ".toml", ".js", ".ts", ".sol"];
      if (textExtensions.some((ext) => fullPath.endsWith(ext))) {
        await replaceTokensInFile(fullPath, tokenMap);
      }
    })
  );
}
