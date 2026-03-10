// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC20PermitFacet} from "src/token/ERC20/Permit/ERC20PermitFacet.sol";
import "src/token/ERC20/Metadata/ERC20MetadataMod.sol" as ERC20MetadataMod;

/**
 * @title ERC20PermitFacetHarness
 * @notice Test harness for ERC20PermitFacet: adds setMetadata so DOMAIN_SEPARATOR and permit hashes can be tested.
 */
contract ERC20PermitFacetHarness is ERC20PermitFacet {
    function setMetadata(string memory _name, string memory _symbol, uint8 _decimals) external {
        ERC20MetadataMod.setMetadata(_name, _symbol, _decimals);
    }
}
