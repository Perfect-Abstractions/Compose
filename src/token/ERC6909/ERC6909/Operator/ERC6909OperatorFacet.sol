// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

/**
 * @title ERC-6909 Minimal Multi-Token Interface
 * @notice A complete, dependency-free ERC-6909 implementation using the diamond storage pattern.
 */
contract ERC6909OperatorFacet {
    /**
     * @notice Thrown when the spender address is invalid.
     */
    error ERC6909InvalidSpender(address _spender);

    /**
     * @notice Emitted when an operator is set.
     */
    event OperatorSet(address indexed _owner, address indexed _spender, bool _approved);

    /**
     * @dev Storage position determined by the keccak256 hash of the diamond storage identifier.
     */
    bytes32 constant STORAGE_POSITION = keccak256("erc6909");

    /**
     * @custom:storage-location erc8042:erc6909
     */
    struct ERC6909Storage {
        mapping(address owner => mapping(uint256 id => uint256 amount)) balanceOf;
        mapping(address owner => mapping(address spender => mapping(uint256 id => uint256 amount))) allowance;
        mapping(address owner => mapping(address spender => bool)) isOperator;
    }

    /**
     * @notice Returns a pointer to the ERC-6909 storage struct.
     * @dev Uses inline assembly to access the storage slot defined by STORAGE_POSITION.
     * @return s The ERC6909Storage struct in storage.
     */
    function getStorage() internal pure returns (ERC6909Storage storage s) {
        bytes32 position = STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }

    /**
     * @notice Sets or removes a spender as an operator for the caller.
     * @param _spender The address of the spender.
     * @param _approved The approval status.
     * @return Whether the operator update succeeded.
     */
    function setOperator(address _spender, bool _approved) external returns (bool) {
        if (_spender == address(0)) {
            revert ERC6909InvalidSpender(address(0));
        }

        ERC6909Storage storage s = getStorage();

        s.isOperator[msg.sender][_spender] = _approved;

        emit OperatorSet(msg.sender, _spender, _approved);

        return true;
    }

    /**
     * @notice Exports the function selectors of the ERC6909OPeratorFacet
     * @dev This function is use as a selector discovery mechanism for diamonds
     * @return selectors The exported function selectors of the ERC6909OPeratorFacet
     */
    function exportSelectors() external pure returns (bytes memory) {
        return bytes.concat(this.setOperator.selector);
    }
}
