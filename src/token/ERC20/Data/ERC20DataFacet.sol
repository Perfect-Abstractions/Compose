// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

contract ERC20DataFacet {
    /**
     * @dev Storage position determined by the keccak256 hash of the diamond storage identifier.
     */
    bytes32 constant STORAGE_POSITION = keccak256("erc20");

    /**
     * @dev ERC-8042 compliant storage struct for ERC20 token data.
     * @custom:storage-location erc8042:erc20.transfer
     */
    struct ERC20Storage {
        mapping(address owner => uint256 balance) balanceOf;
        uint256 totalSupply;
        mapping(address owner => mapping(address spender => uint256 allowance)) allowance;
    }

    /**
     * @notice Returns the ERC20 storage struct from the predefined diamond storage slot.
     * @dev Uses inline assembly to set the storage slot reference.
     * @return s The ERC20 storage struct reference.
     */
    function getStorage() internal pure returns (ERC20Storage storage s) {
        bytes32 position = STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }

    /**
     * @notice Returns the total supply of tokens.
     * @return The total token supply.
     */
    function totalSupply() external view returns (uint256) {
        return getStorage().totalSupply;
    }

    /**
     * @notice Returns the balance of a specific account.
     * @param _account The address of the account.
     * @return The account balance.
     */
    function balanceOf(address _account) external view returns (uint256) {
        return getStorage().balanceOf[_account];
    }

    /**
     * @notice Returns the remaining number of tokens that a spender is allowed to spend on behalf of an owner.
     * @param _owner The address of the token owner.
     * @param _spender The address of the spender.
     * @return The remaining allowance.
     */
    function allowance(address _owner, address _spender) external view returns (uint256) {
        return getStorage().allowance[_owner][_spender];
    }
}
