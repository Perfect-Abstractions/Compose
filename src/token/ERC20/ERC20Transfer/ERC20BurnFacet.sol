// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

contract ERC20BurnFacet {
    /**
     * @notice Thrown when an account has insufficient balance for a transfer or burn.
     * @param _sender Address attempting the transfer.
     * @param _balance Current balance of the sender.
     * @param _needed Amount required to complete the operation.
     */
    error ERC20InsufficientBalance(address _sender, uint256 _balance, uint256 _needed);

    /**
     * @notice Thrown when a spender tries to use more than the approved allowance.
     * @param _spender Address attempting to spend.
     * @param _allowance Current allowance for the spender.
     * @param _needed Amount required to complete the operation.
     */
    error ERC20InsufficientAllowance(address _spender, uint256 _allowance, uint256 _needed);

    /**
     * @notice Emitted when tokens are transferred between two addresses.
     * @param _from Address sending the tokens.
     * @param _to Address receiving the tokens.
     * @param _value Amount of tokens transferred.
     */
    event Transfer(address indexed _from, address indexed _to, uint256 _value);

    /**
     * @dev Storage position determined by the keccak256 hash of the diamond storage identifier.
     */
    bytes32 constant STORAGE_POSITION = keccak256("compose.erc20.transfer");

    /**
     * @dev ERC-8042 compliant storage struct for ERC20 token data.
     * @custom:storage-location erc8042:compose.erc20.transfer
     */
    struct ERC20TransferStorage {
        mapping(address owner => uint256 balance) balanceOf;
        uint256 totalSupply;
        mapping(address owner => mapping(address spender => uint256 allowance)) allowance;
    }

    /**
     * @notice Returns the ERC20 storage struct from the predefined diamond storage slot.
     * @dev Uses inline assembly to set the storage slot reference.
     * @return s The ERC20 storage struct reference.
     */
    function getStorage() internal pure returns (ERC20TransferStorage storage s) {
        bytes32 position = STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }

    /**
     * @notice Burns (destroys) a specific amount of tokens from the caller's balance.
     * @dev Emits a {Transfer} event to the zero address.
     * @param _value The amount of tokens to burn.
     */
    function burn(uint256 _value) external {
        ERC20TransferStorage storage s = getStorage();
        uint256 balance = s.balanceOf[msg.sender];
        if (balance < _value) {
            revert ERC20InsufficientBalance(msg.sender, balance, _value);
        }
        unchecked {
            s.balanceOf[msg.sender] = balance - _value;
            s.totalSupply -= _value;
        }
        emit Transfer(msg.sender, address(0), _value);
    }

    /**
     * @notice Burns tokens from another account, deducting from the caller's allowance.
     * @dev Emits a {Transfer} event to the zero address.
     * @param _account The address whose tokens will be burned.
     * @param _value The amount of tokens to burn.
     */
    function burnFrom(address _account, uint256 _value) external {
        ERC20TransferStorage storage s = getStorage();
        uint256 currentAllowance = s.allowance[_account][msg.sender];
        if (currentAllowance < _value) {
            revert ERC20InsufficientAllowance(msg.sender, currentAllowance, _value);
        }
        uint256 balance = s.balanceOf[_account];
        if (balance < _value) {
            revert ERC20InsufficientBalance(_account, balance, _value);
        }
        unchecked {
            if (currentAllowance != type(uint256).max) {
                s.allowance[_account][msg.sender] = currentAllowance - _value;
            }
            s.balanceOf[_account] = balance - _value;
            s.totalSupply -= _value;
        }
        emit Transfer(_account, address(0), _value);
    }
}
