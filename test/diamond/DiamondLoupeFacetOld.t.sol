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

    function testFacetsOld() public view {
        DiamondLoupeFacet.Facet[] memory facets = loupe.facetsOld();
        console.log("facets length:", facets.length);
        for(uint256 i; i < facets.length; i++) {
            console.log("Facet", i, "address:", facets[i].facet);
            console.log("Facet", i, "selectors length:", facets[i].functionSelectors.length);
            // for (uint256 j; j < facets[i].functionSelectors.length; j++) {
            //     console.logBytes4(facets[i].functionSelectors[j]);
            // }
        }
    
        // for (uint256 i; i < facets.length; i++) {
        //     assertEq(facets[i].facet, address(0x71C7656EC7ab88b098defB751B7401B5f6d8976F));
        //     for (uint256 j; j < facets[i].functionSelectors.length; j++) {
        //         assertEq(facets[i].functionSelectors[j], bytes4(uint32(j + 1)));
        //     }
        // }
    }

    function testFacetsA() public view {
        DiamondLoupeFacet.Facet[] memory facets = loupe.facets11();
        console.log("facets length:", facets.length);
        for(uint256 i; i < facets.length; i++) {
            console.log("Facet", i, "address:", facets[i].facet);
            console.log("Facet", i, "selectors length:", facets[i].functionSelectors.length);
            // for (uint256 j; j < facets[i].functionSelectors.length; j++) {
            //     console.logBytes4(facets[i].functionSelectors[j]);
            // }
        }
        
        // for (uint256 i; i < facets.length; i++) {
        //     assertEq(facets[i].facet, address(0x71C7656EC7ab88b098defB751B7401B5f6d8976F));
        //     for (uint256 j; j < facets[i].functionSelectors.length; j++) {
        //         assertEq(facets[i].functionSelectors[j], bytes4(uint32(j + 1)));
        //     }
        // }
    }

     function testFacetsB() public view {
        DiamondLoupeFacet.Facet[] memory facets = loupe.facets10()
;
        console.log("facets length:", facets.length);
        for(uint256 i; i < facets.length; i++) {
            console.log("Facet", i, "address:", facets[i].facet);
            console.log("Facet", i, "selectors length:", facets[i].functionSelectors.length);
            // for (uint256 j; j < facets[i].functionSelectors.length; j++) {
            //     console.logBytes4(facets[i].functionSelectors[j]);
            // }
        }
        
        // for (uint256 i; i < facets.length; i++) {
        //     assertEq(facets[i].facet, address(0x71C7656EC7ab88b098defB751B7401B5f6d8976F));
        //     for (uint256 j; j < facets[i].functionSelectors.length; j++) {
        //         assertEq(facets[i].functionSelectors[j], bytes4(uint32(j + 1)));
        //     }
        // }
    }


     function testFacetsD() public view {
        DiamondLoupeFacet.Facet[] memory facets = loupe.facets12()
;
        console.log("facets length:", facets.length);
        for(uint256 i; i < facets.length; i++) {
            console.log("Facet", i, "address:", facets[i].facet);
            console.log("Facet", i, "selectors length:", facets[i].functionSelectors.length);
            // for (uint256 j; j < facets[i].functionSelectors.length; j++) {
            //     console.logBytes4(facets[i].functionSelectors[j]);
            // }
        }
        
    }

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

