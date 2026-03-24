// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

contract ERC6909DataFacet {
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
     * @notice Owner balance of an id.
     * @param _owner The address of the owner.
     * @param _id The id of the token.
     * @return The balance of the token.
     */
    function balanceOf(address _owner, uint256 _id) external view returns (uint256) {
        return getStorage().balanceOf[_owner][_id];
    }

    /**
     * @notice Spender allowance of an id.
     * @param _owner The address of the owner.
     * @param _spender The address of the spender.
     * @param _id The id of the token.
     * @return The allowance of the token.
     */
    function allowance(address _owner, address _spender, uint256 _id) external view returns (uint256) {
        return getStorage().allowance[_owner][_spender][_id];
    }

    /**
     * @notice Checks if a spender is approved by an owner as an operator.
     * @param _owner The address of the owner.
     * @param _spender The address of the spender.
     * @return The approval status.
     */
    function isOperator(address _owner, address _spender) external view returns (bool) {
        return getStorage().isOperator[_owner][_spender];
    }

    /**
     * @notice Exports the function selectors of the ERC6909DataFacet
     * @dev This function is use as a selector discovery mechanism for diamonds
     * @return selectors The exported function selectors of the ERC6909DataFacet
     */
    function exportSelectors() external pure returns (bytes memory) {
        return bytes.concat(this.balanceOf.selector, this.allowance.selector, this.isOperator.selector);
    }
}
