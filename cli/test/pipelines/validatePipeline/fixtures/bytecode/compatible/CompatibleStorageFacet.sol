// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

contract CompatibleStorageFacet {
    bytes32 constant STORAGE_POSITION = keccak256("compose.e2e.storage");

    struct Node {
        uint256 amount;
        uint256 score;
        uint256 nonce;
    }

    /**
     * @custom:storage-location erc8042:compose.e2e.storage
     */
    struct Storage {
        uint256 value;
        address account;
        bool enabled;
        uint8 small;
        mapping(address owner => uint256 balance) balances;
        uint256[] values;
        uint8[5] fixedValues;
        mapping(bytes4 id => Node node) nodes;
        Node[] children;
        bytes32 appended;
    }

    function getStorage() internal pure returns (Storage storage s) {
        bytes32 position = STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }

    function writeScalars(uint256 value, address account, bool enabled, uint8 small) external {
        Storage storage s = getStorage();
        s.value = value;
        s.account = account;
        s.enabled = enabled;
        s.small = small;
    }

    function writeBalance(address owner, uint256 balance) external {
        getStorage().balances[owner] = balance;
    }

    function pushValue(uint256 value) external {
        getStorage().values.push(value);
    }

    function writeFixed(uint256 index, uint8 value) external {
        getStorage().fixedValues[index] = value;
    }

    function writeNode(bytes4 id, uint256 amount, uint256 score, uint256 nonce) external {
        Node storage node = getStorage().nodes[id];
        node.amount = amount;
        node.score = score;
        node.nonce = nonce;
    }

    function writeChild(uint256 index, uint256 amount, uint256 score, uint256 nonce) external {
        Node storage node = getStorage().children[index];
        node.amount = amount;
        node.score = score;
        node.nonce = nonce;
    }

    function writeAppended(bytes32 value) external {
        getStorage().appended = value;
    }

    function exportSelectors() external pure returns (bytes memory) {
        return bytes.concat(
            this.writeScalars.selector,
            this.writeBalance.selector,
            this.pushValue.selector,
            this.writeFixed.selector,
            this.writeNode.selector,
            this.writeChild.selector,
            this.writeAppended.selector
        );
    }
}
