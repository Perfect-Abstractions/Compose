// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {CounterFacet} from "../src/facets/CounterFacet.sol";
import {Diamond} from "../src/Diamond.sol";

contract CounterFacetTest is Test {
    CounterFacet internal counter;
    Diamond internal diamond;

    address internal owner = makeAddr("owner");

    function setUp() public {
        CounterFacet counterFacet = new CounterFacet();

        address[] memory facets = new address[](1);
        facets[0] = address(counterFacet);

        diamond = new Diamond(facets, owner);
        counter = CounterFacet(address(diamond));
    }

    function test_increment() public {
        counter.increment();
        assertEq(counter.getCounter(), 1);
    }
}
