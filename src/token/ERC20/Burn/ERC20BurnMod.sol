// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

/*
 * @title ERC20BurnMod
 * @notice Provides internal functions for burning ERC-20 tokens.
 * @dev Uses ERC-8042 for storage location standardization and ERC-6093 for error conventions.
 */

/**
 * @notice Thrown when a sender attempts to transfer or burn more tokens than their balance.
 * @param _sender The address attempting the transfer or burn.
 * @param _balance The sender's current balance.
 * @param _needed The amount required to complete the operation.
 */
error ERC20InsufficientBalance(address _sender, uint256 _balance, uint256 _needed);

/**
 * @notice Thrown when the sender address is invalid (e.g., zero address).
 * @param _sender The invalid sender address.
 */
error ERC20InvalidSender(address _sender);

/**
 * @notice Emitted when tokens are transferred between addresses.
 * @param _from The address tokens are transferred from.
 * @param _to The address tokens are transferred to.
 * @param _value The amount of tokens transferred.
 */
event Transfer(address indexed _from, address indexed _to, uint256 _value);

/*
 * @notice Storage slot identifier, defined using keccak256 hash of the library diamond storage identifier.
 */
bytes32 constant STORAGE_POSITION = keccak256("erc20");

/*
 * @notice ERC-20 storage layout using the ERC-8042 standard.
 * @custom:storage-location erc8042:erc20
 */
struct ERC20Storage {
    mapping(address owner => uint256 balance) balanceOf;
    uint256 totalSupply;
}

/**
 * @notice Returns a pointer to the ERC-20 storage struct.
 * @dev Uses inline assembly to bind the storage struct to the fixed storage position.
 * @return s The ERC-20 storage struct.
 */
function getStorage() pure returns (ERC20Storage storage s) {
    bytes32 position = STORAGE_POSITION;
    assembly {
        s.slot := position
    }
}

/**
 * @notice Burns tokens from a specified address.
 * @dev Decreases both total supply and the sender's balance.
 * @param _account The address whose tokens will be burned.
 * @param _value The number of tokens to burn.
 */
function burnERC20(address _account, uint256 _value) {
    ERC20Storage storage s = getStorage();
    if (_account == address(0)) {
        revert ERC20InvalidSender(address(0));
    }
    uint256 accountBalance = s.balanceOf[_account];
    if (accountBalance < _value) {
        revert ERC20InsufficientBalance(_account, accountBalance, _value);
    }
    unchecked {
        s.balanceOf[_account] = accountBalance - _value;
        s.totalSupply -= _value;
    }
    emit Transfer(_account, address(0), _value);
}
