// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */


/**
 * @title ERC-1155 Multi Token Standard
 *
 */
contract ERC1155DataFacet {
    
    /**
     * @notice Error indicating array length mismatch in batch operations.
     * @param _idsLength Length of the ids array.
     * @param _valuesLength Length of the values array.
     */
    error ERC1155InvalidArrayLength(uint256 _idsLength, uint256 _valuesLength);
    
    /**
     * @dev Storage position determined by the keccak256 hash of the diamond storage identifier.
     */
    bytes32 constant STORAGE_POSITION = keccak256("erc1155");

    /**
     * @dev ERC-8042 compliant storage struct for ERC-1155 token data.
     * @custom:storage-location erc8042:compose.erc1155
     */
    struct ERC1155Storage {
        mapping(uint256 id => mapping(address account => uint256 balance)) balanceOf;
        mapping(address account => mapping(address operator => bool)) isApprovedForAll;
        string uri;
        string baseURI;
        mapping(uint256 tokenId => string) tokenURIs;
    }

    /**
     * @notice Returns the ERC-1155 storage struct from the predefined diamond storage slot.
     * @dev Uses inline assembly to set the storage slot reference.
     * @return s The ERC-1155 storage struct reference.
     */
    function getStorage() internal pure returns (ERC1155Storage storage s) {
        bytes32 position = STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }   

    /**
     * @notice Returns the amount of tokens of token type `id` owned by `account`.
     * @param _account The address to query the balance of.
     * @param _id The token type to query.
     * @return The balance of the token type.
     */
    function balanceOf(address _account, uint256 _id) external view returns (uint256) {
        return getStorage().balanceOf[_id][_account];
    }

    /**
     * @notice Batched version of {balanceOf}.
     * @param _accounts The addresses to query the balances of.
     * @param _ids The token types to query.
     * @return balances The balances of the token types.
     */
    function balanceOfBatch(address[] calldata _accounts, uint256[] calldata _ids)
        external
        view
        returns (uint256[] memory balances)
    {
        if (_accounts.length != _ids.length) {
            revert ERC1155InvalidArrayLength(_ids.length, _accounts.length);
        }

        ERC1155Storage storage s = getStorage();
        balances = new uint256[](_accounts.length);

        for (uint256 i = 0; i < _accounts.length; i++) {
            balances[i] = s.balanceOf[_ids[i]][_accounts[i]];
        }
    } 

    /**
     * @notice Returns true if `operator` is approved to transfer `account`'s tokens.
     * @param _account The token owner.
     * @param _operator The operator to query.
     * @return True if the operator is approved, false otherwise.
     */
    function isApprovedForAll(address _account, address _operator) external view returns (bool) {
        return getStorage().isApprovedForAll[_account][_operator];
    }    
}
