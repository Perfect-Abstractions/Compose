// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import * as LibDiamond from "../LibDiamond.sol";
import * as LibOwner from "../../access/Owner/LibOwner.sol";
import * as LibERC721 from "../../token/ERC721/ERC721/LibERC721.sol";
import * as LibERC165 from "../../interfaceDetection/ERC165/LibERC165.sol";
import {IERC721} from "../../interfaces/IERC721.sol";
import {IERC721Metadata} from "../../interfaces/IERC721Metadata.sol";

contract ExampleDiamond {
    /**
     * @notice Struct to hold facet address and its function selectors.
     * struct FacetCut {
     *    address facetAddress;
     *    FacetCutAction action; // Add=0, Replace=1, Remove=2
     *    bytes4[] functionSelectors;
     * }
     */
    /**
     * @notice Initializes the diamond contract with facets, owner and other data.
     * @dev Adds all provided facets to the diamond's function selector mapping and sets the contract owner.
     *      Each facet in the array will have its function selectors registered to enable delegatecall routing.
     * @param _facets Array of facet addresses and their corresponding function selectors to add to the diamond.
     * @param _diamondOwner Address that will be set as the owner of the diamond contract.
     */
    constructor(LibDiamond.FacetCut[] memory _facets, address _diamondOwner) {
        LibDiamond.addFacets(_facets);

        /*************************************
         * Initialize storage variables
         ************************************/

        /**
         * Setting the contract owner
         */
        LibOwner.setContractOwner(_diamondOwner);
        /**
         * Setting ERC721 token details
         */
        LibERC721.setMetadata({_name: "ExampleDiamondNFT", _symbol: "EDN", _baseURI: "https://example.com/metadata/"});
        /**
         * Registering ERC165 interfaces
         */
        LibERC165.registerInterface(type(IERC721).interfaceId);
        LibERC165.registerInterface(type(IERC721Metadata).interfaceId);
    }

    fallback() external payable {
        LibDiamond.diamondFallback();
    }

    receive() external payable {}
}
