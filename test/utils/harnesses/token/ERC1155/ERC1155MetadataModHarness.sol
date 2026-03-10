// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC1155MetadataFacet} from "src/token/ERC1155/Metadata/ERC1155MetadataFacet.sol";
import "src/token/ERC1155/Metadata/ERC1155MetadataMod.sol" as ERC1155MetadataMod;

/**
 * @title ERC1155MetadataModHarness
 * @notice Test harness that exposes ERC1155MetadataFacet.uri and ERC1155MetadataMod setters (same storage).
 */
contract ERC1155MetadataModHarness is ERC1155MetadataFacet {
    function setURI(string memory _uri) external {
        ERC1155MetadataMod.setURI(_uri);
    }

    function setBaseURI(string memory _baseURI) external {
        ERC1155MetadataMod.setBaseURI(_baseURI);
    }

    function setTokenURI(uint256 _tokenId, string memory _tokenURI) external {
        ERC1155MetadataMod.setTokenURI(_tokenId, _tokenURI);
    }
}
