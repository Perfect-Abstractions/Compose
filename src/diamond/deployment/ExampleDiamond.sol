// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {ComposeDiamond} from "../ComposeDiamond.sol";
import {LibOwner} from "../../access/Owner/LibOwner.sol";
import {LibERC721} from "../../token/ERC721/ERC721/LibERC721.sol";
import {LibERC165} from "../../interfaceDetection/ERC165/LibERC165.sol";
import {IERC721} from "../../interfaces/IERC721.sol";
import {IERC721Metadata} from "../../interfaces/IERC721Metadata.sol";

contract ExampleDiamond is ComposeDiamond {
    /// @notice Struct to hold facet address and its function selectors.
    //  struct Facet {
    //     address facet;
    //     bytes4[] functionSelectors;
    // }

    /// @notice Initializes the diamond contract with facets, owner and other data.
    /// @dev Adds all provided facets to the diamond's function selector mapping and sets the contract owner.
    ///      Each facet in the array will have its function selectors registered to enable delegatecall routing.
    /// @param _facets Array of facet addresses and their corresponding function selectors to add to the diamond.
    /// @param _diamondOwner Address that will be set as the owner of the diamond contract.
    constructor(FacetCut[] memory _facets, address _diamondOwner) {
        addFacets(_facets);

        // Initialize storage variables
        //////////////////////////////////////////////////////

        // Setting the contract owner
        LibOwner.setContractOwner(_diamondOwner);
        // Setting ERC721 token details
        LibERC721.setMetadata("ExampleDiamondNFT", "EDN", "https://example.com/metadata/");
        // Registering ERC165 interfaces
        LibERC165.registerInterface(type(IERC721).interfaceId);
        LibERC165.registerInterface(type(IERC721Metadata).interfaceId);
    }
}
