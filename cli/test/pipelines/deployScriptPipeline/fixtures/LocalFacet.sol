// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {increment} from "./helpers/CounterMod.sol";

contract LocalFacet {
    function nextValue(uint256 value) external pure returns (uint256) {
        return increment(value);
    }

    function exportSelectors() external pure returns (bytes memory) {
        return abi.encodePacked(this.nextValue.selector);
    }
}
