// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import {CounterFacet} from "../facets/CounterFacet.sol";
import {Diamond} from "../Diamond.sol";
import {DiamondInspectFacet} from "@perfect-abstractions/compose/facets/diamond/DiamondInspectFacet.sol";
import {DiamondUpgradeFacet} from "@perfect-abstractions/compose/facets/diamond/DiamondUpgradeFacet.sol";
import {Test} from "forge-std/Test.sol";

contract CounterTest is Test {
  CounterFacet counter;

  address internal owner = makeAddr("owner");

  function setUp() public {
    CounterFacet counterFacet = new CounterFacet();

    address[] memory facets = new address[](1);
    facets[0] = address(counterFacet);

    Diamond diamond = new Diamond(facets, owner);
    counter = CounterFacet(address(diamond));
  }

  function test_InitialValue() public view {
    require(counter.getCounter() == 0, "Initial value should be 0");
  }

  function testFuzz_Inc(uint8 x) public {
    for (uint8 i = 0; i < x; i++) {
      counter.increment();
    }
    require(counter.getCounter() == x, "Value after increment x times should be x");
  }
}

