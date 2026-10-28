// compose-plan-hash: {{PLAN_HASH}}
// compose-ignition-deployment-id: {{IGNITION_DEPLOYMENT_ID}}

import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("{{IGNITION_MODULE_ID}}", (m) => {
{{FACET_FUTURES}}
  const diamond = m.contract("{{DIAMOND_CONTRACT}}", [[{{FACET_VARIABLES}}]], {
    id: "Diamond",
  });

  return {
    diamond,
{{FACET_RESULTS}}
  };
});
