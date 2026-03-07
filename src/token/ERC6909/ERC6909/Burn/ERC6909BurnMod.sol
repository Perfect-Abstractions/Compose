// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */
/**
 * @notice Thrown when the sender has insufficient balance.
 */
error ERC6909InsufficientBalance(address _sender, uint256 _balance, uint256 _needed, uint256 _id);

/**
 * @notice Thrown when the spender has insufficient allowance.
 */
error ERC6909InsufficientAllowance(address _spender, uint256 _allowance, uint256 _needed, uint256 _id);

/**
 * @notice Emitted when a transfer occurs.
 */
event Transfer(
    address _caller, address indexed _sender, address indexed _receiver, uint256 indexed _id, uint256 _amount
);

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
function getStorage() pure returns (ERC6909Storage storage s) {
    bytes32 position = STORAGE_POSITION;
    assembly {
        s.slot := position
    }
}

/**
 * @notice Burns (destroys) a specific amount of tokens from the caller's balance.
 * @dev Emits a {Transfer} event to the zero address.
 * @param _amount The amount of tokens to burn.
 */
function burnERC6909(uint256 _id, uint256 _amount) {
    ERC6909Storage storage s = getStorage();

    uint256 fromBalance = s.balanceOf[msg.sender][_id];

    if (fromBalance < _amount) {
        revert ERC6909InsufficientBalance(msg.sender, fromBalance, _amount, _id);
    }

    unchecked {
        s.balanceOf[msg.sender][_id] = fromBalance - _amount;
    }

    emit Transfer(msg.sender, msg.sender, address(0), _id, _amount);
}

/**
 * @notice Burns tokens from another account, deducting from the caller's allowance.
 * @dev Emits a {Transfer} event to the zero address.
 * @param _account The address whose tokens will be burned.
 * @param _amount The amount of tokens to burn.
 */
function burnERC6909From(address _account, uint256 _id, uint256 _amount) {
    ERC6909Storage storage s = getStorage();
    uint256 currentAllowance = s.allowance[_account][msg.sender][_id];
    uint256 fromBalance = s.balanceOf[msg.sender][_id];

    if (currentAllowance < type(uint256).max) {
        if (currentAllowance < _amount) {
            revert ERC6909InsufficientAllowance(msg.sender, currentAllowance, _amount, _id);
        }
        unchecked {
            s.allowance[_account][msg.sender][_id] = currentAllowance - _amount;
            s.balanceOf[_account][_id] = fromBalance - _amount;
        }
    }
    emit Transfer(_account, msg.sender, address(0), _id, _amount);
}

