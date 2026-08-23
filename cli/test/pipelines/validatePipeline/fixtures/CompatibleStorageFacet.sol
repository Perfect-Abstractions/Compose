// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

contract CompatibleStorageFacet {
    enum Status { None, Active, Paused }
    type UserId is uint64;

    /**
     * @custom:storage-location erc8042:compose.fixture.virtual-storage
     */
    struct Storage {
        bool flag;
        Status status;
        address owner;
        uint8 smallUint;
        uint16 mediumUint;
        int24 signedValue;
        bytes2 shortBytes;
        UserId userId;
        bytes dynamicBytes;
        string text;
    }

    bytes32 private constant STORAGE_POSITION =
        keccak256("compose.fixture.virtual-storage");

    function readCompatibleOwner() external view returns (address) {
        return _storage().owner;
    }

    function exportSelectors() external pure returns (bytes4[] memory selectors) {
        selectors = new bytes4[](1);
        selectors[0] = this.readCompatibleOwner.selector;
    }

    function _storage() private pure returns (Storage storage s) {
        bytes32 position = STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }
}
