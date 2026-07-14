// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

contract CounterSetFacet {
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

    function set(uint256 _value) external {
        getStorage().count = _value;
    }

    function exportSelectors() external pure returns (bytes memory) {
        return bytes.concat(this.set.selector);
    }
}
