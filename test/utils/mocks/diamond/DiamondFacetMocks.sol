// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

/* Compose
 * https://compose.diamonds
 */

bytes32 constant DIAMOND_TEST_STORAGE_POSITION = keccak256("compose.test.diamond");

contract FacetA {
    function a1() external pure returns (uint256) {
        return 1;
    }

    function a2(uint256 _value) external pure returns (uint256) {
        return _value;
    }

    function a3() external pure returns (bytes32) {
        return keccak256("a3");
    }

    function exportSelectors() external pure returns (bytes memory) {
        return bytes.concat(this.a1.selector, this.a2.selector, this.a3.selector);
    }
}

contract FacetAReplacement {
    function a1() external pure returns (uint256) {
        return 2;
    }

    function a2(uint256 _value) external pure returns (uint256) {
        return _value + 1;
    }

    function a3() external pure returns (bytes32) {
        return keccak256("a3-v2");
    }

    function exportSelectors() external pure returns (bytes memory) {
        return bytes.concat(this.a1.selector, this.a2.selector, this.a3.selector);
    }
}

contract FacetAChanged {
    function a4() external pure returns (uint256) {
        return 4;
    }

    function a2(uint256 _value) external pure returns (uint256) {
        return _value + 2;
    }

    function a5() external pure returns (uint256) {
        return 5;
    }

    function exportSelectors() external pure returns (bytes memory) {
        return bytes.concat(this.a4.selector, this.a2.selector, this.a5.selector);
    }
}

contract FacetB {
    function b1() external pure returns (uint256) {
        return 11;
    }

    function b2(bytes32 _value) external pure returns (bytes32) {
        return _value;
    }

    function b3(address _value) external pure returns (address) {
        return _value;
    }

    function exportSelectors() external pure returns (bytes memory) {
        return bytes.concat(this.b1.selector, this.b2.selector, this.b3.selector);
    }
}

contract FacetBReplacement {
    function b1() external pure returns (uint256) {
        return 12;
    }

    function b2(bytes32 _value) external pure returns (bytes32) {
        return keccak256(abi.encode(_value));
    }

    function b3(address _value) external pure returns (address) {
        return address(uint160(_value) ^ 1);
    }

    function exportSelectors() external pure returns (bytes memory) {
        return bytes.concat(this.b1.selector, this.b2.selector, this.b3.selector);
    }
}

contract FacetBChanged {
    function b4() external pure returns (uint256) {
        return 14;
    }

    function b2(bytes32 _value) external pure returns (bytes32) {
        return _value;
    }

    function b5() external pure returns (uint256) {
        return 15;
    }

    function exportSelectors() external pure returns (bytes memory) {
        return bytes.concat(this.b4.selector, this.b2.selector, this.b5.selector);
    }
}

contract FacetC {
    function c1() external pure returns (uint256) {
        return 21;
    }

    function c2(bool _value) external pure returns (bool) {
        return _value;
    }

    function c3(bytes calldata _value) external pure returns (bytes32) {
        return keccak256(_value);
    }

    function exportSelectors() external pure returns (bytes memory) {
        return bytes.concat(this.c1.selector, this.c2.selector, this.c3.selector);
    }
}

contract FacetCReplacement {
    function c1() external pure returns (uint256) {
        return 22;
    }

    function c2(bool _value) external pure returns (bool) {
        return !_value;
    }

    function c3(bytes calldata _value) external pure returns (bytes32) {
        return keccak256(abi.encode(_value));
    }

    function exportSelectors() external pure returns (bytes memory) {
        return bytes.concat(this.c1.selector, this.c2.selector, this.c3.selector);
    }
}

contract FacetCChanged {
    function c4() external pure returns (uint256) {
        return 24;
    }

    function c2(bool _value) external pure returns (bool) {
        return _value;
    }

    function c5() external pure returns (uint256) {
        return 25;
    }

    function exportSelectors() external pure returns (bytes memory) {
        return bytes.concat(this.c4.selector, this.c2.selector, this.c5.selector);
    }
}

contract EmptySelectorsFacet {
    function exportSelectors() external pure returns (bytes memory) {
        return bytes("");
    }
}

contract MisalignedSelectorsFacet {
    function exportSelectors() external pure returns (bytes memory) {
        return hex"0102030405";
    }
}

contract RevertingSelectorsFacet {
    error SelectorExportReverted();

    function exportSelectors() external pure returns (bytes memory) {
        revert SelectorExportReverted();
    }
}

contract MissingSelectorsFacet {}

contract ShortReturnFacet {
    fallback() external {
        assembly ("memory-safe") {
            mstore(0, 0x20)
            return(0, 0x20)
        }
    }
}

contract BadOffsetFacet {
    fallback() external {
        assembly ("memory-safe") {
            mstore(0, 0)
            mstore(0x20, 4)
            return(0, 0x40)
        }
    }
}

contract OversizedLengthFacet {
    fallback() external {
        assembly ("memory-safe") {
            mstore(0, 0x20)
            mstore(0x20, 0x20)
            return(0, 0x40)
        }
    }
}

contract SelectorConflictFacet {
    function conflictHead() external pure returns (uint256) {
        return 1;
    }

    function exportSelectors() external pure returns (bytes memory) {
        return bytes.concat(this.conflictHead.selector, FacetB.b2.selector);
    }
}

contract DuplicateSelectorFacet {
    function duplicate() external pure returns (uint256) {
        return 1;
    }

    function exportSelectors() external pure returns (bytes memory) {
        return bytes.concat(this.duplicate.selector, this.duplicate.selector);
    }
}

contract DispatchFacet {
    error DispatchFailure(uint256 _value);

    function context(uint256 _value) external payable returns (address sender, uint256 value, uint256 argument) {
        bytes32 position = DIAMOND_TEST_STORAGE_POSITION;
        assembly ("memory-safe") {
            sstore(position, _value)
        }
        return (msg.sender, msg.value, _value);
    }

    function fail(uint256 _value) external pure {
        revert DispatchFailure(_value);
    }

    function exportSelectors() external pure returns (bytes memory) {
        return bytes.concat(this.context.selector, this.fail.selector);
    }
}

contract DelegateTarget {
    error DelegateFailure(uint256 _value);

    function initialize(uint256 _value) external {
        bytes32 position = DIAMOND_TEST_STORAGE_POSITION;
        assembly ("memory-safe") {
            sstore(position, _value)
        }
    }

    function failWithData(uint256 _value) external pure {
        revert DelegateFailure(_value);
    }

    function failWithoutData() external pure {
        assembly ("memory-safe") {
            revert(0, 0)
        }
    }
}
