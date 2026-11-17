import { describe, expect, it } from "vitest";
import {
  assertHardhatNodeVersion,
  HARDHAT_MINIMUM_NODE_VERSION,
  isNodeVersionAtLeast,
} from "../../src/utils/nodeVersion";

describe("isNodeVersionAtLeast", () => {
  it.each(["22.13.0", "v22.13.0", "22.13.1", "22.14.0", "23.0.0", "24.0.0"])(
    "accepts %s as meeting the Hardhat minimum",
    (version) => {
      expect(isNodeVersionAtLeast(version, HARDHAT_MINIMUM_NODE_VERSION)).toBe(true);
    },
  );

  it.each(["20.19.0", "22.0.0", "22.12.9", "21.99.99"])(
    "rejects %s as older than the Hardhat minimum",
    (version) => {
      expect(isNodeVersionAtLeast(version, HARDHAT_MINIMUM_NODE_VERSION)).toBe(false);
    },
  );

  it("rejects an unparseable version", () => {
    expect(isNodeVersionAtLeast("not-a-version", HARDHAT_MINIMUM_NODE_VERSION)).toBe(false);
  });
});

describe("assertHardhatNodeVersion", () => {
  it("allows the exact minimum Hardhat version", () => {
    expect(() => assertHardhatNodeVersion("22.13.0")).not.toThrow();
  });

  it("reports the current version and the supported minimum", () => {
    expect(() => assertHardhatNodeVersion("22.12.0")).toThrow(
      "Hardhat 3 requires Node.js 22.13.0 or newer; current version is 22.12.0",
    );
  });
});
