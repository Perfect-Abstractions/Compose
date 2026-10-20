import { describe, expect, it } from "vitest";
import { toPassthroughArgs } from "../../src/utils/args";

describe("toPassthroughArgs", () => {
  it("keeps only string arguments in order", () => {
    expect(toPassthroughArgs(["--match-test", "test_Increment", 7, null])).toEqual([
      "--match-test",
      "test_Increment",
    ]);
  });

  it("returns an empty list for missing or non-array values", () => {
    expect(toPassthroughArgs(undefined)).toEqual([]);
    expect(toPassthroughArgs("--match-test")).toEqual([]);
  });
});
