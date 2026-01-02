// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

/*
 * @title LibERC6909 — ERC-6909 Library
 * @notice Provides internal functions and storage layout for ERC-6909 minimal multi-token logic.
 * @dev Uses ERC-8042 for storage location standardization.
 *      This library is intended to be used by custom facets to integrate with ERC-6909 functionality.
 * @dev Adapted from: https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC6909.sol
 */

/**
 * @notice Thrown when the sender has insufficient balance.
 * @param _sender The address attempting the transfer or burn.
 * @param _balance The sender's current balance.
 * @param _needed The amount required to complete the operation.
 * @param _id The token ID.
 */
error ERC6909InsufficientBalance(address _sender, uint256 _balance, uint256 _needed, uint256 _id);

/**
 * @notice Thrown when the spender has insufficient allowance.
 * @param _spender The address attempting the transfer.
 * @param _allowance The spender's current allowance.
 * @param _needed The amount required to complete the operation.
 * @param _id The token ID.
 */
error ERC6909InsufficientAllowance(address _spender, uint256 _allowance, uint256 _needed, uint256 _id);

/**
 * @notice Thrown when the approver address is invalid.
 * @param _approver The invalid approver address.
 */
error ERC6909InvalidApprover(address _approver);

/**
 * @notice Thrown when the receiver address is invalid.
 * @param _receiver The invalid receiver address.
 */
error ERC6909InvalidReceiver(address _receiver);

/**
 * @notice Thrown when the sender address is invalid.
 * @param _sender The invalid sender address.
 */
error ERC6909InvalidSender(address _sender);

/**
 * @notice Thrown when the spender address is invalid.
 * @param _spender The invalid spender address.
 */
error ERC6909InvalidSpender(address _spender);

/**
 * @notice Emitted when a transfer occurs.
 * @param _caller The caller who initiated the transfer.
 * @param _sender The address from which tokens are transferred.
 * @param _receiver The address to which tokens are transferred.
 * @param _id The token ID.
 * @param _amount The number of tokens transferred.
 */
event Transfer(
    address _caller, address indexed _sender, address indexed _receiver, uint256 indexed _id, uint256 _amount
);

/**
 * @notice Emitted when an operator is set.
 * @param _owner The owner granting the operator status.
 * @param _spender The address receiving operator status.
 * @param _approved True if the operator is approved, false otherwise.
 */
event OperatorSet(address indexed _owner, address indexed _spender, bool _approved);

/**
 * @notice Emitted when an approval occurs.
 * @param _owner The address granting the allowance.
 * @param _spender The address receiving the allowance.
 * @param _id The token ID.
 * @param _amount The number of tokens approved.
 */
event Approval(address indexed _owner, address indexed _spender, uint256 indexed _id, uint256 _amount);

/**
 * @dev Storage position determined by the keccak256 hash of the diamond storage identifier.
 */
bytes32 constant STORAGE_POSITION = keccak256("compose.erc6909");

/**
 * @custom:storage-location erc8042:compose.erc6909
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
 * @notice Mints `_amount` of token id `_id` to `_to`.
 * @param _to The address of the receiver.
 * @param _id The id of the token.
 * @param _amount The amount of the token.
 */
function mint(address _to, uint256 _id, uint256 _amount) {
    if (_to == address(0)) {
        revert ERC6909InvalidReceiver(address(0));
    }

    ERC6909Storage storage s = getStorage();

    s.balanceOf[_to][_id] += _amount;

    emit Transfer(msg.sender, address(0), _to, _id, _amount);
}

/**
 * @notice Burns `_amount` of token id `_id` from `_from`.
 * @param _from The address of the sender.
 * @param _id The id of the token.
 * @param _amount The amount of the token.
 */
function burn(address _from, uint256 _id, uint256 _amount) {
    if (_from == address(0)) {
        revert ERC6909InvalidSender(address(0));
    }

    ERC6909Storage storage s = getStorage();

    uint256 fromBalance = s.balanceOf[_from][_id];
    if (fromBalance < _amount) {
        revert ERC6909InsufficientBalance(_from, fromBalance, _amount, _id);
    }

    unchecked {
        s.balanceOf[_from][_id] = fromBalance - _amount;
    }

    emit Transfer(msg.sender, _from, address(0), _id, _amount);
}

/**
 * @notice Transfers `_amount` of token id `_id` from `_from` to `_to`.
 * @dev Allowance is not deducted if it is `type(uint256).max`
 * @dev Allowance is not deducted if `_by` is an operator for `_from`.
 * @param _by The address initiating the transfer.
 * @param _from The address of the sender.
 * @param _to The address of the receiver.
 * @param _id The id of the token.
 * @param _amount The amount of the token.
 */
function transfer(address _by, address _from, address _to, uint256 _id, uint256 _amount) {
    if (_from == address(0)) {
        revert ERC6909InvalidSender(address(0));
    }

    if (_to == address(0)) {
        revert ERC6909InvalidReceiver(address(0));
    }

    ERC6909Storage storage s = getStorage();

    if (_by != _from && !s.isOperator[_from][_by]) {
        uint256 currentAllowance = s.allowance[_from][_by][_id];
        if (currentAllowance < type(uint256).max) {
            if (currentAllowance < _amount) {
                revert ERC6909InsufficientAllowance(_by, currentAllowance, _amount, _id);
            }
            unchecked {
                s.allowance[_from][_by][_id] = currentAllowance - _amount;
            }
        }
    }

    uint256 fromBalance = s.balanceOf[_from][_id];
    if (fromBalance < _amount) {
        revert ERC6909InsufficientBalance(_from, fromBalance, _amount, _id);
    }
    unchecked {
        s.balanceOf[_from][_id] = fromBalance - _amount;
    }

    s.balanceOf[_to][_id] += _amount;

    emit Transfer(_by, _from, _to, _id, _amount);
}

/**
 * @notice Approves an amount of an id to a spender.
 * @param _owner The token owner.
 * @param _spender The address of the spender.
 * @param _id The id of the token.
 * @param _amount The amount of the token.
 */
function approve(address _owner, address _spender, uint256 _id, uint256 _amount) {
    if (_owner == address(0)) {
        revert ERC6909InvalidApprover(address(0));
    }
    if (_spender == address(0)) {
        revert ERC6909InvalidSpender(address(0));
    }

    ERC6909Storage storage s = getStorage();

    s.allowance[_owner][_spender][_id] = _amount;

    emit Approval(_owner, _spender, _id, _amount);
}

/**
 * @notice Sets or removes a spender as an operator for the caller.
 * @param _owner The address of the owner.
 * @param _spender The address of the spender.
 * @param _approved The approval status.
 */
function setOperator(address _owner, address _spender, bool _approved) {
    if (_owner == address(0)) {
        revert ERC6909InvalidApprover(address(0));
    }
    if (_spender == address(0)) {
        revert ERC6909InvalidSpender(address(0));
    }

    ERC6909Storage storage s = getStorage();

    s.isOperator[_owner][_spender] = _approved;

    emit OperatorSet(_owner, _spender, _approved);
}
