// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

// TEST FIXTURE: This facet intentionally does NOT implement exportSelectors().
// Used by the CLI to validate that missing exportSelectors() is detected.

contract ERC20MissingExportSelector {
    bytes32 constant STORAGE_POSITION = keccak256("erc20.missing");

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
}
