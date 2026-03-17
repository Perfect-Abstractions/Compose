import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

import { DiamondInspectFacet } from "@perfect-abstractions/compose/facets/diamond/DiamondInspectFacet.sol";
import { DiamondUpgradeFacet } from "@perfect-abstractions/compose/facets/diamond/DiamondUpgradeFacet.sol";

export default buildModule("CounterDiamondModule", (m) => {
  const counterFacet = m.contract("CounterFacet");
  const inspectFacet = m.contract(DiamondInspectFacet);
  const upgradeFacet = m.contract(DiamondUpgradeFacet);

  const owner = m.getAccount(0);
  const diamond = m.contract("Diamond", [[counterFacet, inspectFacet, upgradeFacet], owner]);

  return { diamond, counterFacet, inspectFacet, upgradeFacet };
});
