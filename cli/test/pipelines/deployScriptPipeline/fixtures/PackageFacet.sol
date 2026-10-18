// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

contract PackageFacet {
    function packageValue() external pure returns (uint256) {
        return 42;
    }

    function exportSelectors() external pure returns (bytes memory) {
        return abi.encodePacked(this.packageValue.selector);
    }
}
