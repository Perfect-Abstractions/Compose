const fs = require("fs-extra");
const path = require("node:path");

async function replaceTokensInFile(filePath, tokenMap) {
  const content = await fs.readFile(filePath, "utf8");
  let updated = content;

  Object.entries(tokenMap).forEach(([token, value]) => {
    updated = updated.split(token).join(value);
  });

  if (updated !== content) {
    await fs.writeFile(filePath, updated);
  }
}

async function replaceTokensRecursively(rootDir, tokenMap) {
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

module.exports = {
  replaceTokensRecursively,
};
