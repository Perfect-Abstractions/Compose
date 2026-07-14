// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

/// @custom:storage-location erc7201:counter
contract CounterResetFacet {
    bytes32 constant STORAGE_POSITION = keccak256("counter");

    /**
     * @custom:storage-location erc8042:counter
     */
    struct CounterStorage {
        uint256 count;
    }

    function getStorage() internal pure returns (CounterStorage storage s) {
        bytes32 position = STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }

    function reset() external {
        getStorage().count = 0;
    }

    function exportSelectors() external pure returns (bytes memory) {
        return bytes.concat(this.reset.selector);
    }
}
