// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

/*
 * @title LibERC20 — ERC-20 Library
 * @notice Provides internal functions and storage layout for ERC-20 token logic.
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
 * @notice Thrown when the receiver address is invalid (e.g., zero address).
 * @param _receiver The invalid receiver address.
 */
error ERC20InvalidReceiver(address _receiver);

/**
 * @notice Thrown when a spender tries to spend more than their allowance.
 * @param _spender The address attempting to spend.
 * @param _allowance The current allowance.
 * @param _needed The required amount to complete the transfer.
 */
error ERC20InsufficientAllowance(address _spender, uint256 _allowance, uint256 _needed);

/**
 * @notice Thrown when the spender address is invalid (e.g., zero address).
 * @param _spender The invalid spender address.
 */
error ERC20InvalidSpender(address _spender);

/**
 * @notice Emitted when tokens are transferred between addresses.
 * @param _from The address tokens are transferred from.
 * @param _to The address tokens are transferred to.
 * @param _value The amount of tokens transferred.
 */
event Transfer(address indexed _from, address indexed _to, uint256 _value);

/**
 * @notice Emitted when an approval is made for a spender by an owner.
 * @param _owner The address granting the allowance.
 * @param _spender The address receiving the allowance.
 * @param _value The amount approved.
 */
event Approval(address indexed _owner, address indexed _spender, uint256 _value);

/*
 * @notice Storage slot identifier, defined using keccak256 hash of the library diamond storage identifier.
 */
bytes32 constant STORAGE_POSITION = keccak256("compose.erc20.transfer");

/*
 * @notice ERC-20 storage layout using the ERC-8042 standard.
 * @custom:storage-location erc8042:compose.erc20.transfer
 */
struct ERC20TransferStorage {
    mapping(address owner => uint256 balance) balanceOf;
    uint256 totalSupply;
    mapping(address owner => mapping(address spender => uint256 allowance)) allowance;
}

/**
 * @notice Returns a pointer to the ERC-20 storage struct.
 * @dev Uses inline assembly to bind the storage struct to the fixed storage position.
 * @return s The ERC-20 storage struct.
 */
function getStorage() pure returns (ERC20TransferStorage storage s) {
    bytes32 position = STORAGE_POSITION;
    assembly {
        s.slot := position
    }
}

/**
 * @notice Mints new tokens to a specified address.
 * @dev Increases both total supply and the recipient's balance.
 * @param _account The address receiving the newly minted tokens.
 * @param _value The number of tokens to mint.
 */
function mint(address _account, uint256 _value) {
    ERC20TransferStorage storage s = getStorage();
    if (_account == address(0)) {
        revert ERC20InvalidReceiver(address(0));
    }
    s.totalSupply += _value;
    s.balanceOf[_account] += _value;
    emit Transfer(address(0), _account, _value);
}

/**
 * @notice Burns tokens from a specified address.
 * @dev Decreases both total supply and the sender's balance.
 * @param _account The address whose tokens will be burned.
 * @param _value The number of tokens to burn.
 */
function burn(address _account, uint256 _value) {
    ERC20TransferStorage storage s = getStorage();
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

/**
 * @notice Transfers tokens from one address to another using an allowance.
 * @dev Deducts the spender's allowance and updates balances.
 * @param _from The address to send tokens from.
 * @param _to The address to send tokens to.
 * @param _value The number of tokens to transfer.
 * @return True if the transfer was successful.
 */
function transferFrom(address _from, address _to, uint256 _value) returns (bool) {
    ERC20TransferStorage storage s = getStorage();
    if (_from == address(0)) {
        revert ERC20InvalidSender(address(0));
    }
    if (_to == address(0)) {
        revert ERC20InvalidReceiver(address(0));
    }
    uint256 currentAllowance = s.allowance[_from][msg.sender];
    if (currentAllowance < _value) {
        revert ERC20InsufficientAllowance(msg.sender, currentAllowance, _value);
    }
    uint256 fromBalance = s.balanceOf[_from];
    if (fromBalance < _value) {
        revert ERC20InsufficientBalance(_from, fromBalance, _value);
    }
    unchecked {
        if (currentAllowance != type(uint256).max) {
            s.allowance[_from][msg.sender] = currentAllowance - _value;
        }
        s.balanceOf[_from] = fromBalance - _value;
    }
    s.balanceOf[_to] += _value;
    emit Transfer(_from, _to, _value);
    return true;
}

/**
 * @notice Transfers tokens from the caller to another address.
 * @dev Updates balances directly without allowance mechanism.
 * @param _to The address to send tokens to.
 * @param _value The number of tokens to transfer.
 * @return True if the transfer was successful.
 */
function transfer(address _to, uint256 _value) returns (bool) {
    ERC20TransferStorage storage s = getStorage();
    if (_to == address(0)) {
        revert ERC20InvalidReceiver(address(0));
    }
    uint256 fromBalance = s.balanceOf[msg.sender];
    if (fromBalance < _value) {
        revert ERC20InsufficientBalance(msg.sender, fromBalance, _value);
    }
    unchecked {
        s.balanceOf[msg.sender] = fromBalance - _value;
    }
    s.balanceOf[_to] += _value;
    emit Transfer(msg.sender, _to, _value);
    return true;
}

/**
 * @notice Approves a spender to transfer tokens on behalf of the caller.
 * @dev Sets the allowance for the spender.
 * @param _spender The address to approve for spending.
 * @param _value The amount of tokens to approve.
 * @return True if the approval was successful.
 */
function approve(address _spender, uint256 _value) returns (bool) {
    if (_spender == address(0)) {
        revert ERC20InvalidSpender(address(0));
    }
    ERC20TransferStorage storage s = getStorage();
    s.allowance[msg.sender][_spender] = _value;
    emit Approval(msg.sender, _spender, _value);
    return true;
}
