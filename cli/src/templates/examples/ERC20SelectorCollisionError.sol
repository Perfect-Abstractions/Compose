// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

/*
 * TEST FIXTURE: This facet intentionally exports the same selector twice.
 * Used by the CLI to validate that selector collisions are detected.
 */

contract ERC20SelectorCollisionError {
    bytes32 constant STORAGE_POSITION = keccak256("erc20.collision");

    struct Data {
        uint256 value;
    }

    function getStorage() internal pure returns (Data storage s) {
        bytes32 position = STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }

    function getValue() external view returns (uint256) {
        return getStorage().value;
    }

    function setValue(uint256 _value) external {
        getStorage().value = _value;
    }

    /* ERROR: exportSelectors() exports this.getValue.selector twice */
    function exportSelectors() external pure returns (bytes memory) {
        return bytes.concat(this.getValue.selector, this.getValue.selector);
    }
}
