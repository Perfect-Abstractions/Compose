# Experimental Diamond Optimizations

This directory contains experimental, optional implementations following the isolated storage pattern discussed in issue #162.

## Isolation Pattern Philosophy

Following mudgen's recommendation and aligned with the CoCell concept, these implementations use **isolated, namespaced storage** instead of shared storage. This provides:

1. **Gas Reduction**: Isolated storage reduces storage slot conflicts and simplifies access patterns
2. **Independence**: Each component manages its own storage without relying on shared structures
3. **Safety**: No risk of storage collisions between different facets/modules
4. **Composability**: Can be swapped in/out without affecting the main build

## Files

### IsolatedShardedLoupe.sol
An experimental loupe implementation that uses completely isolated storage. Unlike the main `ShardedDiamondLoupeFacet` which shares storage with the diamond, this version maintains its own isolated storage namespace.

**Key Features:**
- Isolated storage at `keccak256("isolated.sharded.loupe.v1")`
- Direct mapping lookups (O(1) access)
- Can be used alongside or instead of standard loupe
- Requires sync mechanism after diamond cuts

**Usage:**
This is optional and experimental. The main build doesn't depend on it. If it doesn't work as intended, it can be safely removed or ignored.

## Integration

To use experimental components:
1. Deploy the experimental facet
2. Add it to your diamond via `diamondCut`
3. Call sync functions after any diamond modifications
4. Monitor gas usage to confirm improvements

To disable:
1. Simply don't deploy or add to diamond
2. Main diamond functionality remains unaffected

## Status

These are **experimental** implementations. They follow the isolated storage pattern that has proven effective in other contexts but are not yet battle-tested for diamond loupe specifically.
