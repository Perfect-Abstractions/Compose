// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

contract ERC20ApproveFacet {
    /**
     * @notice Thrown when the spender address is invalid (e.g., zero address).
     * @param _spender Invalid spender address.
     */
    error ERC20InvalidSpender(address _spender);

    /**
     * @notice Emitted when an approval is made for a spender by an owner.
     * @param _owner The address granting the allowance.
     * @param _spender The address receiving the allowance.
     * @param _value The amount approved.
     */
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);

    /**
     * @dev Storage position determined by the keccak256 hash of the diamond storage identifier.
     */
    bytes32 constant STORAGE_POSITION = keccak256("erc20");

    /**
     * @dev ERC-8042 compliant storage struct for ERC20 token data.
     * @custom:storage-location erc8042:erc20
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
     * @notice Approves a spender to transfer up to a certain amount of tokens on behalf of the caller.
     * @dev Emits an {Approval} event.
     * @param _spender The address approved to spend tokens.
     * @param _value The number of tokens to approve.
     * @return True if the approval was successful.
     */
    function approve(address _spender, uint256 _value) external returns (bool) {
        ERC20Storage storage s = getStorage();
        if (_spender == address(0)) {
            revert ERC20InvalidSpender(address(0));
        }
        s.allowance[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }
}
