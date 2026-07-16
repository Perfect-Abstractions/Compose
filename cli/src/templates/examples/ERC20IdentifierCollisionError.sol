// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

/*
 * TEST FIXTURE: This facet intentionally has identifier collisions.
 * Used by the CLI to validate that identifier collisions are detected.
 */

contract ERC20IdentifierCollisionError {
    bytes32 constant STORAGE_POSITION = keccak256("erc20.identifier");

    struct Data {
        uint256 value;
        mapping(address => uint256) values;
    }

    function getStorage() internal pure returns (Data storage s) {
        bytes32 position = STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }

    /* ERROR: Two functions with the same name but different signatures */
    function getValue() external view returns (uint256) {
        return getStorage().value;
    }

    function getValue(address _account) external view returns (uint256) {
        return getStorage().values[_account];
    }

    function exportSelectors() external pure returns (bytes memory) {
        return bytes.concat(
            this.getValue.selector,
            this.getValue(address).selector
        );
    }
}
