# {{projectName}}

Minimal diamond starter scaffolded by Compose CLI using Hardhat 3.


## What's included?

The project includes native support for TypeScript, Hardhat scripts, tasks, support for Solidity compilation & tests.

Compose is directly included as a dependency in the project (even before package publication).

This starter includes:
- `contracts/Diamond.sol` using Compose `DiamondMod` and `OwnerMod`
- `contracts/CounterFacet.sol` with `increment`, `getCounter`, and `exportSelectors`

To deploy a working diamond, deploy `CounterFacet` first, then pass the facet address and owner into `Diamond` constructor.

## Next steps
1. `npx hardhat compile`
2. `npx hardhat test`
