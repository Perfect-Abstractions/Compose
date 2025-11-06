# Sharded Diamond Loupe Implementation

This directory contains an optimized Diamond Loupe implementation using sharded SSTORE2 snapshots, addressing issue #180.

## Overview

The sharded loupe approach replaces expensive SLOAD loops with cheap EXTCODECOPY operations by:
1. Pre-computing facet/selector snapshots during `diamondCut` (write time)
2. Storing snapshots as contract code via SSTORE2
3. Reading snapshots via EXTCODECOPY (O(1) operation, not O(n))

## Architecture

### Core Components

#### LibBlob.sol
SSTORE2-style library for storing/reading arbitrary data as contract code.
- `write(bytes)`: Deploys a contract with data as its code
- `read(address)`: Reads all code from a blob contract via EXTCODECOPY

#### LibShardedLoupe.sol  
Core library managing sharded storage and snapshot operations.
- Maintains category-based shards (default category for basic usage)
- Each shard has pointers to SSTORE2 blobs containing packed data
- `rebuildShard()`: Rebuilds a shard's snapshots
- `unpackAddresses()`: Unpacks facet addresses from blob
- `unpackFacetsAndSelectors()`: Unpacks complete facet/selector data

#### ShardedDiamondLoupeFacet.sol
Main loupe facet implementing EIP-2535 loupe interface.
- Implements standard: `facets()`, `facetAddresses()`, `facetFunctionSelectors()`, `facetAddress()`
- Falls back to traditional loupe when sharding not enabled
- Uses sharded snapshots when enabled for massive gas savings

#### LibDiamondShard.sol
Helper library for integrating with diamond cuts.
- `rebuildDefaultShard()`: Rebuilds the default shard after cuts
- `enableShardedLoupe()`: Enables sharded loupe and builds initial snapshot

#### InitShardedLoupe.sol
Initialization contract for existing diamonds.
- Call via `diamondCut` with init to enable sharded loupe

#### PackedLoupeExtension.sol
Optional extension providing packed/compressed loupe functions.
- `facetAddressesPacked()`: Returns raw packed addresses (20 bytes each)
- `selectorsPacked(address)`: Returns raw packed selectors (4 bytes each)
- `facetsPacked()`: Returns RLE format: [addr|count|selectors...]

### Experimental Components

#### experimental/IsolatedShardedLoupe.sol
Experimental loupe using completely isolated storage (issue #162 pattern).
- Independent storage namespace
- No shared diamond storage access
- Requires sync after cuts
- Can be swapped in/out without affecting main build

## Usage

### Option 1: New Diamond with Sharded Loupe

```solidity
import {ShardedDiamondLoupeFacet} from "./diamond/ShardedDiamondLoupeFacet.sol";
import {InitShardedLoupe} from "./diamond/InitShardedLoupe.sol";
import {LibDiamond} from "./diamond/LibDiamond.sol";

// Deploy loupe
ShardedDiamondLoupeFacet loupe = new ShardedDiamondLoupeFacet();
InitShardedLoupe init = new InitShardedLoupe();

// Add loupe to diamond
bytes4[] memory loupeSelectors = new bytes4[](4);
loupeSelectors[0] = bytes4(keccak256("facets()"));
loupeSelectors[1] = bytes4(keccak256("facetFunctionSelectors(address)"));
loupeSelectors[2] = bytes4(keccak256("facetAddresses()"));
loupeSelectors[3] = bytes4(keccak256("facetAddress(bytes4)"));

LibDiamond.FacetCut[] memory cut = new LibDiamond.FacetCut[](1);
cut[0] = LibDiamond.FacetCut({
    facetAddress: address(loupe),
    action: LibDiamond.FacetCutAction.Add,
    functionSelectors: loupeSelectors
});

// Enable sharded loupe during initialization
LibDiamond.diamondCut(cut, address(init), abi.encodeWithSelector(init.init.selector));
```

### Option 2: Upgrade Existing Diamond

```solidity
// 1. Deploy new sharded loupe facet
ShardedDiamondLoupeFacet newLoupe = new ShardedDiamondLoupeFacet();
InitShardedLoupe init = new InitShardedLoupe();

// 2. Replace old loupe with new one
LibDiamond.FacetCut[] memory cut = new LibDiamond.FacetCut[](1);
cut[0] = LibDiamond.FacetCut({
    facetAddress: address(newLoupe),
    action: LibDiamond.FacetCutAction.Replace,
    functionSelectors: loupeSelectors
});

// 3. Enable sharding in same transaction
LibDiamond.diamondCut(cut, address(init), abi.encodeWithSelector(init.init.selector));
```

### Option 3: Add Packed Extensions (Optional)

```solidity
import {PackedLoupeExtension} from "./diamond/PackedLoupeExtension.sol";

PackedLoupeExtension packed = new PackedLoupeExtension();

bytes4[] memory packedSelectors = new bytes4[](3);
packedSelectors[0] = bytes4(keccak256("facetAddressesPacked()"));
packedSelectors[1] = bytes4(keccak256("selectorsPacked(address)"));
packedSelectors[2] = bytes4(keccak256("facetsPacked()"));

// Add alongside standard loupe
LibDiamond.FacetCut[] memory cut = new LibDiamond.FacetCut[](1);
cut[0] = LibDiamond.FacetCut({
    facetAddress: address(packed),
    action: LibDiamond.FacetCutAction.Add,
    functionSelectors: packedSelectors
});

LibDiamond.diamondCut(cut, address(0), "");
```

### Maintaining Snapshots

After any diamond cut, snapshots must be rebuilt:

```solidity
import {LibDiamondShard} from "./diamond/LibDiamondShard.sol";

// In your DiamondCutFacet, after performing cuts:
function diamondCut(...) external {
    // ... existing cut logic ...
    
    // Rebuild sharded snapshots
    LibDiamondShard.rebuildDefaultShard();
}
```

## Gas Expectations

Based on the design from issue #180:

| Operation | Baseline | Sharded | Improvement |
|-----------|----------|---------|-------------|
| facets() 200 facets | ~370M gas | ~5-10M gas | 97%+ |
| facetAddresses() | ~31M gas | ~500K gas | 98%+ |
| facetFunctionSelectors() | ~5M gas | ~100K gas | 98%+ |
| facetAddress() | ~12K gas | ~12K gas | Same (already O(1)) |

Sharded loupe shifts cost to write (diamondCut) which is:
- Rare operation
- Expected to be expensive
- Acceptable tradeoff for massive read savings

## Compatibility

- ✅ EIP-2535 compliant (standard interface preserved)
- ✅ Falls back to traditional loupe when sharding disabled
- ✅ Can be added to existing diamonds
- ✅ Optional packed variants for power users
- ✅ Experimental isolated variant available

## Testing

See `test/benchmark/ShardedLoupe.t.sol` for comprehensive benchmarks testing:
- 64 facets × 16 selectors (1,024 total)
- 64 facets × 64 selectors (4,096 total)
- 1,000 facets × 84 selectors (84,000 total)
- 10,000 facets × 834 selectors (8.34M total)
- 40,000 facets × 5,000 selectors (200M total - smoke test)

## Safety

- Atomic snapshots: blob creation and pointer update in single transaction
- Versioning ready: Shard struct can include version field
- Events: Can emit snapshot hashes for indexer verification
- Reorg safe: pointer updates are in same tx as cut

## Design Philosophy

Aligns with issue #180 and #162:
- **Intent-driven**: Diamond focuses on "getting it done", not "finding it"
- **Compositional**: Categories/shards are semantic units
- **Scales unlimited**: Add shards forever; cost grows with #shards not selectors
- **Compatible**: Standard loupe returns same shapes, just sourced smarter
- **Isolated**: Experimental variant uses isolated storage pattern
