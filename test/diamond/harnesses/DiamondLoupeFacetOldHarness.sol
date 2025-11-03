// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

//import {DiamondLoupeFacet} from "../../../src/diamond/DiamondLoupeFacet.sol";
import {DiamondLoupeFacet} from "../../../src/diamond/DiamondLoupeFacetOld.sol";
// import {DiamondLoupeFacet} from "../../../src/diamond/DiamondLoupeFacet2.sol";
import {console} from "forge-std/console.sol";

contract DiamondLoupeFacetHarness is DiamondLoupeFacet {
    
    function initialize() external {
        
        DiamondStorage storage s = getStorage();
        uint256 facetCount = 0;
        address a = 0x71C7656EC7ab88b098defB751B7401B5f6d8976F;
        for(uint256 i = 1; i < 40001; i++) {
            bytes4 selector = bytes4(uint32(i));
            s.selectors.push(selector);
            s.facetAndPosition[selector] = FacetAndPosition(a, 0);
            if(i % 8 == 0) {
                facetCount++;
                a = address(uint160(uint256(keccak256(abi.encodePacked(i)))));
            }
            // else if(i % 17 == 0) {
            //     a = address(uint160(uint256(keccak256(abi.encodePacked(uint256(17))))));
            // }
            // else if(i % 24 == 0) {
            //     a = address(uint160(uint256(keccak256(abi.encodePacked(uint256(24))))));
            // }
        }
        console.log("------------Total facets added ----------------", facetCount);

    }

}