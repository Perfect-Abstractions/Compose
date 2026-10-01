// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

contract IncompatibleStorageFacet {
    bytes32 constant STORAGE_POSITION = keccak256("compose.e2e.storage");

    struct Node {
        address amount;
        address score;
        address nonce;
    }

    /**
     * @custom:storage-location erc8042:compose.e2e.storage
     */
    struct Storage {
        address value;
        uint256 account;
        uint128 enabled;
        uint128 small;
        mapping(address owner => address balance) balances;
        address[] values;
        address[5] fixedValues;
        mapping(bytes4 id => Node node) nodes;
        Node[] children;
    }

    function getStorage() internal pure returns (Storage storage s) {
        bytes32 position = STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }

    function writeScalars(uint256 value, address account, bool enabled, uint8 small) external {
        Storage storage s = getStorage();
        s.value = address(uint160(value));
        s.account = uint256(uint160(account));
        s.enabled = enabled ? 1 : 0;
        s.small = small;
    }

    function writeBalance(address owner, uint256 balance) external {
        getStorage().balances[owner] = address(uint160(balance));
    }

    function pushValue(uint256 value) external {
        getStorage().values.push(address(uint160(value)));
    }

    function writeFixed(uint256 index, uint8 value) external {
        getStorage().fixedValues[index] = address(uint160(value));
    }

    function writeNode(bytes4 id, uint256 amount, uint256 score, uint256 nonce) external {
        Node storage node = getStorage().nodes[id];
        node.amount = address(uint160(amount));
        node.score = address(uint160(score));
        node.nonce = address(uint160(nonce));
    }

    function writeChild(uint256 index, uint256 amount, uint256 score, uint256 nonce) external {
        Node storage node = getStorage().children[index];
        node.amount = address(uint160(amount));
        node.score = address(uint160(score));
        node.nonce = address(uint160(nonce));
    }

    function exportSelectors() external pure returns (bytes memory) {
        return bytes.concat(
            this.writeScalars.selector,
            this.writeBalance.selector,
            this.pushValue.selector,
            this.writeFixed.selector,
            this.writeNode.selector,
            this.writeChild.selector
        );
    }
}
