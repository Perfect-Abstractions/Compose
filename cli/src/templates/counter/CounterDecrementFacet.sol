// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

contract CounterDecrementFacet {
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

    function decrement() external {
        require(getStorage().count > 0, "Counter: underflow");
        getStorage().count--;
    }

    function decrementBy(uint256 _amount) external {
        require(getStorage().count >= _amount, "Counter: underflow");
        getStorage().count -= _amount;
    }

    function exportSelectors() external pure returns (bytes memory) {
        return bytes.concat(this.decrement.selector, this.decrementBy.selector);
    }
}
