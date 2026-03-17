// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

contract CounterFacet {
    event Increment(uint256 by);

    bytes32 private constant COUNTER_STORAGE_POSITION = keccak256("compose.counter.storage");

    struct CounterStorage {
        uint256 counter;
    }

    function _getStorage() internal pure returns (CounterStorage storage s) {
        bytes32 position = COUNTER_STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }

    function increment() external {
        CounterStorage storage s = _getStorage();
        s.counter += 1;
        emit Increment(1);
    }

    function getCounter() external view returns (uint256) {
        return _getStorage().counter;
    }

    function exportSelectors() external pure returns (bytes memory) {
        return bytes.concat(this.increment.selector, this.getCounter.selector);
    }
}
