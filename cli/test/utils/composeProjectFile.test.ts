import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { locateComposeProjectFile, readComposeProjectFile } from "../../src/utils/composeProjectFile";

describe("compose project file utilities", () => {
  it("locates the nearest compose.json and returns its project root", async () => {
    const root = await fs.mkdtemp(path.join(os.tmpdir(), "compose-project-file-"));

    try {
      const nestedRoot = path.join(root, "nested");
      const startDirectory = path.join(nestedRoot, "src", "facets");
      await fs.mkdir(startDirectory, { recursive: true });
      await fs.writeFile(path.join(root, "compose.json"), "{}", "utf8");
      await fs.writeFile(path.join(nestedRoot, "compose.json"), "{}", "utf8");

      const location = await locateComposeProjectFile(path.relative(process.cwd(), startDirectory));

      expect(location).toEqual({
        path: path.join(nestedRoot, "compose.json"),
        root: nestedRoot,
      });
    } finally {
      await fs.rm(root, { recursive: true, force: true });
    }
  });

  it("returns null when no compose.json exists", async () => {
    const root = await fs.mkdtemp(path.join(os.tmpdir(), "compose-project-file-empty-"));

    try {
      await expect(locateComposeProjectFile(root)).resolves.toBeNull();
    } finally {
      await fs.rm(root, { recursive: true, force: true });
    }
  });

  it("reads JSON without wrapping parse errors", async () => {
    const root = await fs.mkdtemp(path.join(os.tmpdir(), "compose-project-file-json-"));
    const filePath = path.join(root, "compose.json");

    try {
      await fs.writeFile(filePath, '{"project":"example"}', "utf8");
      await expect(readComposeProjectFile(filePath)).resolves.toEqual({ project: "example" });

      await fs.writeFile(filePath, "{invalid", "utf8");
      await expect(readComposeProjectFile(filePath)).rejects.toBeInstanceOf(SyntaxError);
    } finally {
      await fs.rm(root, { recursive: true, force: true });
    }
  });
});
