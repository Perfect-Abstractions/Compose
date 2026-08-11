import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { ComposeContext } from "../../../src/context/types";
import { Context } from "../../../src/context/context";
import { BasesCatalog, FacetEntry } from "../../../src/modules/config/types";

export type DeployGenerationHarness = {
  ctx: ComposeContext;
  projectRoot: string;
  scriptRoot: string;
  cleanup(): Promise<void>;
};

const facetPaths = {
  ERC20DataFacet: "@perfect-abstractions/compose/token/ERC20/Data/ERC20DataFacet.sol",
  ERC20ApproveFacet: "@perfect-abstractions/compose/token/ERC20/Approve/ERC20ApproveFacet.sol",
  ERC20TransferFacet: "@perfect-abstractions/compose/token/ERC20/Transfer/ERC20TransferFacet.sol",
  ERC20BurnFacet: "@perfect-abstractions/compose/token/ERC20/Burn/ERC20BurnFacet.sol",
  ERC20MetadataFacet: "@perfect-abstractions/compose/token/ERC20/Metadata/ERC20MetadataFacet.sol",
  ERC20PermitFacet: "@perfect-abstractions/compose/token/ERC20/Permit/ERC20PermitFacet.sol",
  DiamondInspectFacet: "@perfect-abstractions/compose/diamond/DiamondInspectFacet.sol",
  DiamondUpgradeFacet: "@perfect-abstractions/compose/diamond/DiamondUpgradeFacet.sol",
  OwnerDataFacet: "@perfect-abstractions/compose/access/Owner/Data/OwnerDataFacet.sol",
  OwnerTransferFacet: "@perfect-abstractions/compose/access/Owner/Transfer/OwnerTransferFacet.sol",
  OwnerRenounceFacet: "@perfect-abstractions/compose/access/Owner/Renounce/OwnerRenounceFacet.sol",
  AccessControlDataFacet: "@perfect-abstractions/compose/access/AccessControl/Data/AccessControlDataFacet.sol",
  AccessControlGrantFacet: "@perfect-abstractions/compose/access/AccessControl/Grant/AccessControlGrantFacet.sol",
  AccessControlRevokeFacet: "@perfect-abstractions/compose/access/AccessControl/Revoke/AccessControlRevokeFacet.sol",
  AccessControlGrantBatchFacet: "@perfect-abstractions/compose/access/AccessControl/Batch/Grant/AccessControlGrantBatchFacet.sol",
  AccessControlRevokeBatchFacet: "@perfect-abstractions/compose/access/AccessControl/Batch/Revoke/AccessControlRevokeBatchFacet.sol",
} as const;

type FacetName = keyof typeof facetPaths;

const catalog: BasesCatalog = {
  globals: {
    diamond: {
      label: "Diamond",
      required: {
        DiamondInspectFacet: facet(facetPaths.DiamondInspectFacet),
      },
      optional: {
        DiamondUpgradeFacet: facet(facetPaths.DiamondUpgradeFacet),
      },
    },
  },
  features: {
    "erc-20": {
      label: "ERC-20",
      required: {
        ERC20DataFacet: facet(facetPaths.ERC20DataFacet),
        ERC20ApproveFacet: facet(facetPaths.ERC20ApproveFacet),
        ERC20TransferFacet: facet(facetPaths.ERC20TransferFacet),
      },
      optional: {
        ERC20BurnFacet: facet(facetPaths.ERC20BurnFacet),
        ERC20MetadataFacet: facet(facetPaths.ERC20MetadataFacet),
        ERC20PermitFacet: facet(facetPaths.ERC20PermitFacet),
      },
    },
    owner: {
      label: "Owner",
      access: true,
      accessType: "ownership",
      required: {
        OwnerDataFacet: facet(facetPaths.OwnerDataFacet),
        OwnerTransferFacet: facet(facetPaths.OwnerTransferFacet),
      },
      optional: {
        OwnerRenounceFacet: facet(facetPaths.OwnerRenounceFacet),
      },
    },
    "access-control": {
      label: "AccessControl",
      access: true,
      accessType: "roles",
      required: {
        AccessControlDataFacet: facet(facetPaths.AccessControlDataFacet),
        AccessControlGrantFacet: facet(facetPaths.AccessControlGrantFacet),
        AccessControlRevokeFacet: facet(facetPaths.AccessControlRevokeFacet),
      },
      optional: {
        AccessControlGrantBatchFacet: facet(facetPaths.AccessControlGrantBatchFacet),
        AccessControlRevokeBatchFacet: facet(facetPaths.AccessControlRevokeBatchFacet),
      },
    },
  },
};

function facet(path: string): FacetEntry {
  return {
    path,
    constructor: undefined,
  };
}

function scaffoldEntry(facetName: FacetName) {
  return {
    facetName,
    contractName: facetName,
    targetPath: facetPaths[facetName],
    origin: "package" as const,
  };
}

/**
 * Builds the Compose context needed to test a full ERC-20 deploy script.
 *
 * It selects every facet used by the snapshot script: the ERC-20 base and
 * extensions, DiamondUpgrade, Owner with renounce, and AccessControl batches.
 */
export async function createDeployGenerationHarness(): Promise<DeployGenerationHarness> {
  const projectRoot = await fs.mkdtemp(path.join(os.tmpdir(), "compose-cli-deploy-generation-"));
  const scriptRoot = path.join(projectRoot, "script");
  const ctx = Context.create();

  ctx.param.projectRoot = projectRoot;
  ctx.param.framework = "foundry";
  ctx.param.base = "erc-20";
  ctx.param.extensions = ["ERC20BurnFacet", "ERC20MetadataFacet", "ERC20PermitFacet"];
  ctx.param.libraries = ["DiamondUpgradeFacet"];
  ctx.param.access = ["owner", "access-control"];
  ctx.param.accessExtensions = [
    "OwnerRenounceFacet",
    "AccessControlGrantBatchFacet",
    "AccessControlRevokeBatchFacet",
  ];
  ctx.config.bases = catalog;
  ctx.state.scaffoldMap = {
    success: true,
    result: {
      entries: (Object.keys(facetPaths) as FacetName[]).map(scaffoldEntry),
    },
    error: null,
  };

  return {
    ctx,
    projectRoot,
    scriptRoot,
    cleanup: () => fs.rm(projectRoot, { recursive: true, force: true }),
  };
}
