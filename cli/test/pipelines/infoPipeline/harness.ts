import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { ComposeContext } from "../../../src/context/types";
import { Context } from "../../../src/context/context";

export type InfoPipelineHarness = {
  ctx: ComposeContext;
  projectRoot: string;
  cleanup(): Promise<void>;
};

const counterFacet = `// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

contract CounterFacet {
    bytes32 constant STORAGE_POSITION = keccak256("counter");

    /**
     * @custom:storage-location erc8042:counter
     */
    struct CounterStorage {
        uint256 value;
    }

    function getValue() external view returns (uint256) {
        return 0;
    }

    function exportSelectors() external pure returns (bytes memory) {
        return bytes.concat(this.getValue.selector);
    }
}
`;

/**
 * Builds a local Compose project for InfoPipeline with one CounterFacet.
 *
 * CounterFacet exports getValue() and declares an ERC-8042 counter layout.
 */
export async function createInfoPipelineHarness(): Promise<InfoPipelineHarness> {
  const projectRoot = await fs.mkdtemp(path.join(os.tmpdir(), "compose-cli-info-pipeline-"));
  const facetRoot = path.join(projectRoot, "src", "facets");
  const ctx = Context.create();

  await fs.mkdir(facetRoot, { recursive: true });
  await fs.writeFile(path.join(facetRoot, "CounterFacet.sol"), counterFacet, "utf8");
  await fs.writeFile(
    path.join(projectRoot, "compose.json"),
    JSON.stringify({
      project: "info-example",
      compose: "0.1.3",
      framework: "foundry",
      diamonds: {
        "info-example": {
          contract: "src/Diamond.sol:Diamond",
          facets: {
            CounterFacet: {
              source: "local",
              contract: "src/facets/CounterFacet.sol:CounterFacet",
            },
          },
        },
      },
    }, null, 2),
    "utf8",
  );

  ctx.param.projectRoot = projectRoot;

  return {
    ctx,
    projectRoot,
    cleanup: () => fs.rm(projectRoot, { recursive: true, force: true }),
  };
}
