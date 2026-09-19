import { describe, expect, it } from "vitest";
import { Context } from "../../../src/context/context";
import { ConfigModule } from "../../../src/modules/config/module";
import { BasesCatalog } from "../../../src/modules/config/types";

/** Tests catalog loading independently from init selection and scaffolding. */
describe("ConfigModule", () => {
  it("loads and indexes the shipped bases catalog", async () => {
    const ctx = Context.create();

    const result = await ConfigModule.loadBasesCatalog(ctx);
    const catalog = result.config.bases as BasesCatalog;

    expect(result).toBe(ctx);
    expect(result.state.config?.success).toBe(true);
    expect(catalog.globals.diamond?.required).toHaveProperty("DiamondInspectFacet");
    expect(catalog.globals.libraries?.optional).toHaveProperty("ERC165Facet");
    expect(Object.keys(catalog.features)).toEqual(expect.arrayContaining([
      "counter",
      "erc-20",
      "erc-721",
      "owner",
      "access-control",
    ]));
    expect(ConfigModule.getDiamondCompilerVersion(catalog)).toBe("0.8.30");
  });
});
