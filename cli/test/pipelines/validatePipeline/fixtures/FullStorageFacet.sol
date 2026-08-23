// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

contract FullStorageFacet {
    enum Status { None, Active, Paused }
    type UserId is uint64;

    struct InlineChild {
        bytes4 tailFacetNodeId;
        uint32 facetCount;
    }

    struct InlineOuter {
        bytes4 headFacetNodeId;
        InlineChild child;
        uint32 selectorCount;
    }

    struct ContainerChild {
        uint256 amount;
        bool active;
        address owner;
    }

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

        function(uint256) external returns (uint256) externalFn;

        InlineOuter inlineStruct;

        mapping(address => uint256) balances;
        mapping(uint256 => uint256[]) mapToDynamicArray;
        uint256[] dynamicValues;
        uint8[] packedDynamicValues;

        uint256[5] fixedFive;
        uint256[300] fixedThreeHundred;
        uint256[5][10] nestedFixed;

        mapping(address => ContainerChild) childByAddress;
        ContainerChild[] childList;
        ContainerChild[2] fixedChildren;
        mapping(uint256 => ContainerChild[]) nestedChildren;

        mapping(bytes => uint256) bytesKeyed;
        mapping(string => uint256) stringKeyed;

        function(uint256) internal returns (uint256) internalFn;
    }

    bytes32 private constant STORAGE_POSITION =
        keccak256("compose.fixture.virtual-storage");

    function readFullFlag() external view returns (bool) {
        return _storage().flag;
    }

    function exportSelectors() external pure returns (bytes4[] memory selectors) {
        selectors = new bytes4[](1);
        selectors[0] = this.readFullFlag.selector;
    }

    function _storage() private pure returns (Storage storage s) {
        bytes32 position = STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }
}
