// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

contract HistoryFacetA {
    function alpha() external pure returns (uint256) {
        return 1;
    }

    function exportSelectors() external pure returns (bytes memory) {
        return bytes.concat(this.alpha.selector);
    }
}

contract HistoryFacetB {
    function beta() external pure returns (uint256) {
        return 2;
    }

    function exportSelectors() external pure returns (bytes memory) {
        return bytes.concat(this.beta.selector);
    }
}

contract HistoryFacetB2 {
    function beta() external pure returns (uint256) {
        return 22;
    }

    function exportSelectors() external pure returns (bytes memory) {
        return bytes.concat(this.beta.selector);
    }
}

contract HistoryFacetC {
    function gamma() external pure returns (uint256) {
        return 3;
    }

    function exportSelectors() external pure returns (bytes memory) {
        return bytes.concat(this.gamma.selector);
    }
}

contract HistoryInitializer {
    function initialize() external {
        bytes32 position = keccak256("history.initialized");
        assembly {
            sstore(position, 1)
        }
    }
}
