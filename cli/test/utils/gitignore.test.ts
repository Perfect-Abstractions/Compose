import { describe, expect, it } from "vitest";
import { ensureGitignoreEntries, ensureGitignoreEntry } from "../../src/utils/gitignore";

describe("ensureGitignoreEntry", () => {
  it("adds the entry to empty content", () => {
    expect(ensureGitignoreEntry("", ".compose/")).toBe(".compose/\n");
  });

  it("preserves content that lacks a trailing newline", () => {
    expect(ensureGitignoreEntry("node_modules/", ".compose/")).toBe("node_modules/\n.compose/\n");
  });

  it("does not duplicate an existing entry", () => {
    expect(ensureGitignoreEntry("node_modules/\n.compose/\n", ".compose/"))
      .toBe("node_modules/\n.compose/\n");
  });

  it("matches entries surrounded by whitespace", () => {
    expect(ensureGitignoreEntry("  .compose/  \n", ".compose/")).toBe("  .compose/  \n");
  });

  it("preserves CRLF content", () => {
    expect(ensureGitignoreEntry("out/\r\ncache/\r\n", ".compose/"))
      .toBe("out/\r\ncache/\r\n.compose/\n");
  });
});

describe("ensureGitignoreEntries", () => {
  it("appends missing entries in order", () => {
    expect(ensureGitignoreEntries("out/\n", ["node_modules/", ".compose/"]))
      .toBe("out/\nnode_modules/\n.compose/\n");
  });

  it("only appends entries that are missing", () => {
    expect(ensureGitignoreEntries("out/\n.compose/\n", ["node_modules/", ".compose/"]))
      .toBe("out/\n.compose/\nnode_modules/\n");
  });
});
