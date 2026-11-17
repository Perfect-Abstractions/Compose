import { describe, expect, it } from "vitest";
import { toComposeError } from "../../src/utils/errors";

describe("toComposeError", () => {
  it("keeps an error code exposed by the original error", () => {
    const error = Object.assign(new Error("Account lookup failed."), { code: "ACCOUNT_NOT_FOUND" });

    expect(toComposeError(error, "ACCOUNT_FAILED", "Account command failed.")).toEqual({
      code: "ACCOUNT_NOT_FOUND",
      message: "Account lookup failed.",
      nativeError: error,
    });
  });

  it("uses the fallback code for errors without one", () => {
    const error = new Error("Deploy failed hard.");

    expect(toComposeError(error, "DEPLOY_FAILED", "Deploy failed.")).toEqual({
      code: "DEPLOY_FAILED",
      message: "Deploy failed hard.",
      nativeError: error,
    });
  });

  it("stringifies numeric error codes", () => {
    const error = Object.assign(new Error("RPC failed."), { code: -32000 });

    expect(toComposeError(error, "DEPLOY_FAILED", "Deploy failed.").code).toBe("-32000");
  });

  it("uses the fallback code and message for non-Error values", () => {
    expect(toComposeError("boom", "BYTECODE_VALIDATION_FAILED", "Bytecode validation failed.")).toEqual({
      code: "BYTECODE_VALIDATION_FAILED",
      message: "Bytecode validation failed.",
      nativeError: "boom",
    });
    expect(toComposeError(null, "DEPLOY_FAILED", "Deploy failed.")).toEqual({
      code: "DEPLOY_FAILED",
      message: "Deploy failed.",
      nativeError: null,
    });
  });

  it("defaults the fallback message", () => {
    expect(toComposeError(undefined, "UNKNOWN_FAILED").message).toBe("Operation failed.");
  });
});
