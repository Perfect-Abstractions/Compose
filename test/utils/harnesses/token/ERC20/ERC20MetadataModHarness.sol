// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC20MetadataFacet} from "src/token/ERC20/Metadata/ERC20MetadataFacet.sol";
import "src/token/ERC20/Metadata/ERC20MetadataMod.sol" as ERC20MetadataMod;

/**
 * @title ERC20MetadataModHarness
 * @notice Test harness that exposes ERC20MetadataFacet view functions and ERC20MetadataMod setMetadata (same storage).
 */
contract ERC20MetadataModHarness is ERC20MetadataFacet {
    function setMetadata(string memory _name, string memory _symbol, uint8 _decimals) external {
        ERC20MetadataMod.setMetadata(_name, _symbol, _decimals);
    }
}
