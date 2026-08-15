import { isAddress, keccak256, slice, toBytes, type Address, type Hex } from "viem";
import path from "node:path";
import { ComposeContext } from "../../context/types";
import { DependencyKey } from "../../resolver/dependencyKey";
import { DependencyResolver } from "../../resolver/dependencyResolver";
import { resolveChainConfig } from "../../utils/chainConfig";
import { findFileAncestor } from "../../utils/files";
import { RPCAdapterError } from "../../adapters/rpc/errors";
import { showInspect } from "./output";
import { loadProjectSignatures } from "./abiLoader";
import type { InspectResult, FacetInfo } from "./types";

const DIAMOND_LOUPE_ABI = [
  {
    name: "facets",
    type: "function",
    stateMutability: "view",
    inputs: [],
    outputs: [
      {
        type: "tuple[]",
        components: [
          { name: "facet", type: "address" },
          { name: "functionSelectors", type: "bytes4[]" },
        ],
      },
    ],
  },
] as const;

const COMMON_SIGNATURES: readonly string[] = [
  "acceptOwnership()",
  "allowance(address,address)",
  "allowance(address,address,uint256)",
  "approve(address,uint256)",
  "approve(address,uint256,uint256)",
  "balanceOf(address)",
  "balanceOf(address,uint256)",
  "balanceOfBatch(address[],uint256[])",
  "burn(address,uint256)",
  "burn(address,uint256,uint256)",
  "burn(uint256)",
  "burn(uint256,uint256)",
  "burnBatch(address,uint256[],uint256[])",
  "burnBatch(uint256[])",
  "burnFrom(address,uint256)",
  "burnFrom(address,uint256,uint256)",
  "checkTokenBridge(address)",
  "crosschainBurn(address,uint256)",
  "crosschainMint(address,uint256)",
  "decimals()",
  "deleteDefaultRoyalty()",
  "diamondCut((address,bytes4[],uint8)[],address,bytes)",
  "DOMAIN_SEPARATOR()",
  "exportSelectors()",
  "facetAddress(bytes4)",
  "facetAddresses()",
  "facetFunctionSelectors(address)",
  "facets()",
  "getApproved(uint256)",
  "getRoleAdmin(bytes32)",
  "getRoleExpiry(bytes32,address)",
  "grantRole(bytes32,address)",
  "grantRoleBatch(bytes32,address[])",
  "grantRoleWithExpiry(bytes32,address,uint256)",
  "hasRole(bytes32,address)",
  "isApprovedForAll(address,address)",
  "isOperator(address,address)",
  "isRoleExpired(bytes32,address)",
  "isRolePaused(bytes32)",
  "name()",
  "nonces(address)",
  "owner()",
  "ownerOf(uint256)",
  "pauseRole(bytes32)",
  "pendingOwner()",
  "permit(address,address,uint256,uint256,uint8,bytes32,bytes32)",
  "renounceOwnership()",
  "renounceRole(bytes32,address)",
  "requireRole(bytes32,address)",
  "requireRoleNotPaused(bytes32,address)",
  "requireValidRole(bytes32,address)",
  "resetTokenRoyalty(uint256)",
  "revokeRole(bytes32,address)",
  "revokeRoleBatch(bytes32,address[])",
  "royaltyInfo(uint256,uint256)",
  "safeBatchTransferFrom(address,address,uint256[],uint256[],bytes)",
  "safeTransferFrom(address,address,uint256)",
  "safeTransferFrom(address,address,uint256,bytes)",
  "safeTransferFrom(address,address,uint256,uint256,bytes)",
  "setApprovalForAll(address,bool)",
  "setDefaultRoyalty(address,uint96)",
  "setOperator(address,bool)",
  "setRoleAdmin(bytes32,bytes32)",
  "setTokenRoyalty(uint256,address,uint96)",
  "supportsInterface(bytes4)",
  "symbol()",
  "tokenByIndex(uint256)",
  "tokenOfOwnerByIndex(address,uint256)",
  "tokenURI(uint256)",
  "totalSupply()",
  "transfer(address,uint256)",
  "transfer(address,uint256,uint256)",
  "transferFrom(address,address,uint256)",
  "transferFrom(address,address,uint256,uint256)",
  "transferOwnership(address)",
  "unpauseRole(bytes32)",
  "upgradeDiamond(address[],(address,address)[],address[],address,bytes,bytes32)",
  "uri(uint256)",
];

const SELECTOR_MAP = new Map<string, string>();

function ensureSelectorMap(): void {
  if (SELECTOR_MAP.size > 0) return;
  for (const sig of COMMON_SIGNATURES) {
    const trimmed = sig.trim();
    if (!trimmed) continue;
    const hash = keccak256(toBytes(trimmed));
    const selector = slice(hash, 0, 4);
    SELECTOR_MAP.set(selector.toLowerCase(), trimmed);
  }
}

export function decodeSelector(selector: string | Hex): string {
  ensureSelectorMap();
  const key = selector.toLowerCase();
  return SELECTOR_MAP.get(key) ?? selector;
}

async function mergeProjectSignatures(projectRoot: string): Promise<void> {
  ensureSelectorMap();
  const projectMap = await loadProjectSignatures(projectRoot);
  for (const [selector, signature] of projectMap) {
    if (!SELECTOR_MAP.has(selector)) {
      SELECTOR_MAP.set(selector, signature);
    }
  }
}

async function findProjectRoot(): Promise<string | null> {
  const composePath = await findFileAncestor(process.cwd(), "compose.json");
  return composePath ? path.dirname(composePath) : null;
}

function toFacetInfo(raw: { facet: Address; functionSelectors: Hex[] }, index: number): FacetInfo {
  return {
    address: raw.facet,
    index,
    selectors: raw.functionSelectors.map((sel) => ({
      selector: sel,
      signature: decodeSelector(sel),
    })),
  };
}

export const InspectModule = {
  async inspect(ctx: ComposeContext): Promise<ComposeContext> {
    const addressValue = ctx.param.address;
    if (typeof addressValue !== "string" || !isAddress(addressValue, { strict: false })) {
      throw new RPCAdapterError(
        "RPC_INVALID_ADDRESS",
        `Invalid diamond address: ${String(addressValue ?? "")}`,
        { operation: "inspect" },
      );
    }
    const diamondAddress = addressValue as Address;

    const chainKey = typeof ctx.param.chain === "string" ? ctx.param.chain : "local";
    const configuredChain = await resolveChainConfig({ chainKey });

    const dependencies = await DependencyResolver.resolve([{
      key: DependencyKey.RPC,
      params: { chainKey: configuredChain.chainKey },
    }]);
    const rpc = dependencies[DependencyKey.RPC];
    if (!rpc) throw new Error("RPC dependency was not resolved");

    const code = await rpc.getCode(diamondAddress);
    if (!code || code === "0x") {
      throw new RPCAdapterError(
        "RPC_CONTRACT_NOT_FOUND",
        `No contract code found at ${diamondAddress}`,
        { operation: "inspect", chainId: configuredChain.chainId },
      );
    }

    const rawFacets = await rpc.readContract<
      { facet: Address; functionSelectors: Hex[] }[]
    >({
      address: diamondAddress,
      abi: DIAMOND_LOUPE_ABI,
      functionName: "facets",
    });

    const projectRoot = await findProjectRoot();
    if (projectRoot) {
      await mergeProjectSignatures(projectRoot);
    }

    const facets: FacetInfo[] = rawFacets.map(toFacetInfo);

    const result: InspectResult = {
      diamond: diamondAddress,
      chainKey: configuredChain.chainKey,
      chainId: configuredChain.chainId,
      facets,
    };

    ctx.state.inspect = { success: true, result, error: null };
    showInspect(result);
    return ctx;
  },
};
