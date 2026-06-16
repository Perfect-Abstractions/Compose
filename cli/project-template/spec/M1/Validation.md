# compose validate

## Summary

Validation checks the selected diamond surface before files are written or before a deployed project is trusted.

- Selector validation checks function selector ownership.
- Identifier validation checks storage layout compatibility.
- Both checks should fail fast when the diamond shape is unsafe.

## Constraints

- Validation is static analysis on the selected diamond surface.
- Validation must fail fast when a required check fails.
- Selector collision detection must run after selector export validation.
- Identifier collision validation is separate from selector collision validation.

## Selector Validation

Selector validation works on selected facets from `init` or facets referenced by `compose.json`.

Order:

1. Scan selected facets.
2. Validate selector exports.
3. Detect selector collisions.

### scanSelectedFacets

Owned by `scaffoldingModule` during `init`.

- Read selected package facets.
- Read selected local example facets.
- Parse external and public functions.
- Parse `exportSelectors()`.
- Parse storage layout identifiers for later storage validation.

### validateSelectorExports

Owned by `validationModule`.

- Verify every intended external or public function is exported by `exportSelectors()`.
- Verify every function exported by `exportSelectors()` exists in the facet.
- Fail before selector collision detection if this check fails.

### detectSelectorCollisions

Owned by `validationModule`.

- Use `exportSelectors()` as the selector source after export validation passes.
- Compute each exported function's 4-byte selector from its signature.
- Fail if more than one selected facet exports the same selector.
- This is the last selector validation step before project files are written.

## Identifier Validation

Identifier validation checks storage layout collisions for selected facets.

- Prefer ERC-8042 storage annotations.
- Fall back to detected storage slot assignment patterns.
- Skip the storage check for a facet when no supported storage pattern is found.
- Fail when different storage layouts point to the same namespace in an unsafe way.

### Detection Order

1. Parse `@custom:storage-location erc8042:<namespace>` annotations.
2. If no annotation is found, infer storage from `.slot :=` assignments.
3. If neither is found, warn and skip storage validation for that facet.

### Layout Rule

Each detected namespace maps to a normalized storage type sequence.

- Types are normalized before comparison.
- `uint` and `int` are normalized to `uint256` and `int256`.
- Mapping parameter names are ignored.
- `mapping(address owner => uint256 balance)` is compared as `mapping(address=>uint256)`.
- Inline structs are flattened in storage order.

### Compare Rule

Group storage records by namespace.

- If a namespace appears once, it is safe.
- If a namespace appears multiple times, compare the layouts.
- Compatible layouts must share the same prefix.
- Appending fields is safe.
- Reordering fields or inserting fields before existing fields is unsafe.
- Incompatible duplicate namespaces fail validation.
