// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {Test} from "forge-std/Test.sol";
//import {DiamondLoupeFacet} from "../../src/diamond/DiamondLoupeFacet.sol";
import {DiamondLoupeFacet} from "../../src/diamond/DiamondLoupeFacetOld.sol";
// import {DiamondLoupeFacet} from "../../src/diamond/DiamondLoupeFacet2.sol";
import {DiamondLoupeFacetHarness} from "./harnesses/DiamondLoupeFacetOldHarness.sol";

import {console} from "forge-std/console.sol";

contract DiamondLoupeFacetTest is Test {
    DiamondLoupeFacetHarness internal loupe;

    function setUp() public {
        loupe = new DiamondLoupeFacetHarness();
        loupe.initialize();
    }

    // function testFacetsOld() public view {
    //     DiamondLoupeFacet.Facet[] memory facets = loupe.facetsOld();
    //     console.log("facets length:", facets.length);
    //     uint256 count;

    //     for(uint256 i; i < facets.length; i++) {

    //         // count += facets[i].functionSelectors.length;

    //         // console.log("Facet", i, "address:", facets[i].facet);
    //         // console.log("Facet", i, "selectors length:", facets[i].functionSelectors.length);
    //         // for (uint256 j; j < facets[i].functionSelectors.length; j++) {
    //         //     console.logBytes4(facets[i].functionSelectors[j]);
    //         // }
    //     }
    //     console.log("Total function:", count);
    // }

    //     // for (uint256 i; i < facets.length; i++) {
    //     //     assertEq(facets[i].facet, address(0x71C7656EC7ab88b098defB751B7401B5f6d8976F));
    //     //     for (uint256 j; j < facets[i].functionSelectors.length; j++) {
    //     //         assertEq(facets[i].functionSelectors[j], bytes4(uint32(j + 1)));
    //     //     }
    //     // }
    // }

    //    function testFacetsP() public view {
    //     bytes4[] memory selectors = loupe.facetFunctionSelectors2(0xf8964C9a443B862F02d4c7611D18C2bC4e6FF697);

    //     console.log("selectors length:", selectors.length);
    //     //console.log(selectors);
    //     for(uint256 i; i < selectors.length; i++) {
    //         console.logBytes4(selectors[i]);
    //         // for (uint256 j; j < facets[i].functionSelectors.length; j++) {
    //         //     console.logBytes4(facets[i].functionSelectors[j]);
    //         // }
    //     }

    // }

    // function testFacetsB() public view {
    //     bytes4[] memory selectors = loupe.facetFunctionSelectors(0xf8964C9a443B862F02d4c7611D18C2bC4e6FF697);

    //     console.log("selectors length:", selectors.length);
    //     //console.log(selectors);
    //     for(uint256 i; i < selectors.length; i++) {
    //         console.logBytes4(selectors[i]);
    //         // for (uint256 j; j < facets[i].functionSelectors.length; j++) {
    //         //     console.logBytes4(facets[i].functionSelectors[j]);
    //         // }
    //     }

    // }

    // function testFacetsD() public view {
    //     address[] memory facets = loupe.facetAddresses2();

    //     console.log("facets length:", facets.length);
    //     for(uint256 i; i < facets.length; i++) {
    //         console.log("Facet", i, "address:", facets[i]);
    //         // for (uint256 j; j < facets[i].functionSelectors.length; j++) {
    //         //     console.logBytes4(facets[i].functionSelectors[j]);
    //         // }
    //     }

    // }

    function testFacetsP() public view {
        address[] memory facets = loupe.facetAddresses3();

        console.log("facets length:", facets.length);
        for (uint256 i; i < facets.length; i++) {
            console.log("Facet", i, "address:", facets[i]);
            // for (uint256 j; j < facets[i].functionSelectors.length; j++) {
            //     console.logBytes4(facets[i].functionSelectors[j]);
            // }
        }
    }

    function testFacetsA() public view {
        address[] memory facets = loupe.facetAddresses2();

        console.log("facets length:", facets.length);
        for (uint256 i; i < facets.length; i++) {
            console.log("Facet", i, "address:", facets[i]);
            // for (uint256 j; j < facets[i].functionSelectors.length; j++) {
            //     console.logBytes4(facets[i].functionSelectors[j]);
            // }
        }
    }

    //  function testFacetsJaa() public view {
    //         DiamondLoupeFacet.Facet[] memory facets = loupe.facets142();
    //         console.log("facets length:", facets.length);
    //         uint256 count;

    //         for(uint256 i; i < facets.length; i++) {

    //             count += facets[i].functionSelectors.length;

    //             //console.log("Facet", i, "address:", facets[i].facet);
    //             //console.log("Facet", i, "selectors length:", facets[i].functionSelectors.length);
    //             // for (uint256 j; j < facets[i].functionSelectors.length; j++) {
    //             //     console.logBytes4(facets[i].functionSelectors[j]);
    //             // }
    //         }
    //         console.log("Total function:", count);

    //     }

    //  function testFacetsJa() public view {
    //         DiamondLoupeFacet.Facet[] memory facets = loupe.facets14();
    //         console.log("facets length:", facets.length);
    //         uint256 count;

    //         for(uint256 i; i < facets.length; i++) {

    //             count += facets[i].functionSelectors.length;

    //             //console.log("Facet", i, "address:", facets[i].facet);
    //             //console.log("Facet", i, "selectors length:", facets[i].functionSelectors.length);
    //             // for (uint256 j; j < facets[i].functionSelectors.length; j++) {
    //             //     console.logBytes4(facets[i].functionSelectors[j]);
    //             // }
    //         }
    //         console.log("Total function:", count);

    //     }

    //   function testFacetsJ() public view {
    //     DiamondLoupeFacet.Facet[] memory facets = loupe.facets141();
    //     console.log("facets length:", facets.length);
    //     uint256 count;

    //     for(uint256 i; i < facets.length; i++) {

    //         count += facets[i].functionSelectors.length;

    //         //console.log("Facet", i, "address:", facets[i].facet);
    //         //console.log("Facet", i, "selectors length:", facets[i].functionSelectors.length);
    //         // for (uint256 j; j < facets[i].functionSelectors.length; j++) {
    //         //     console.logBytes4(facets[i].functionSelectors[j]);
    //         // }
    //     }
    //     console.log("Total function:", count);

    // }

    //   function testFacetsE() public view {
    //     DiamondLoupeFacet.Facet[] memory facets = loupe.facets15();
    //     console.log("facets length:", facets.length);
    //     uint256 count;

    //     for(uint256 i; i < facets.length; i++) {

    //         count += facets[i].functionSelectors.length;

    //         // console.log("Facet", i, "address:", facets[i].facet);
    //         // console.log("Facet", i, "selectors length:", facets[i].functionSelectors.length);
    //         // for (uint256 j; j < facets[i].functionSelectors.length; j++) {
    //         //     console.logBytes4(facets[i].functionSelectors[j]);
    //         // }
    //     }
    //     console.log("Total function:", count);

    // }

    //       function testFacetsE() public view {
    //         DiamondLoupeFacet.Facet[] memory facets = loupe.facets5()
    // ;
    //         console.log("facets length:", facets.length);
    //         for(uint256 i; i < facets.length; i++) {
    //             console.log("Facet", i, "address:", facets[i].facet);
    //             console.log("Facet", i, "selectors length:", facets[i].functionSelectors.length);
    //             // for (uint256 j; j < facets[i].functionSelectors.length; j++) {
    //             //     console.logBytes4(facets[i].functionSelectors[j]);
    //             // }
    //         }

    //     }

    // function testFacets2Opt() public view {
    //     DiamondLoupeFacet.Facet[] memory facets = loupe.facets2Opt();
    //     console.log("facets length:", facets.length);
    //     for(uint256 i; i < facets.length; i++) {
    //         console.log("Facet", i, "address:", facets[i].facet);
    //         console.log("Facet", i, "selectors length:", facets[i].functionSelectors.length);
    //         // for (uint256 j; j < facets[i].functionSelectors.length; j++) {
    //         //     console.logBytes4(facets[i].functionSelectors[j]);
    //         // }
    //     }
    //     // for (uint256 i; i < facets.length; i++) {
    //     //     assertEq(facets[i].facet, address(0x71C7656EC7ab88b098defB751B7401B5f6d8976F));
    //     //     for (uint256 j; j < facets[i].functionSelectors.length; j++) {
    //     //         assertEq(facets[i].functionSelectors[j], bytes4(uint32(j + 1)));
    //     //     }
    //     // }
    // }
}

