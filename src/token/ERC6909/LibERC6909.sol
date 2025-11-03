// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/// @title LibERC6909 — ERC-6909 Library
/// @notice Provides internal functions and storage layout for ERC-6909 minimal multi-token logic.
/// @dev Uses ERC-8042 for storage location standardization and ERC-6093 for error conventions.
///      This library is intended to be used by custom facets to integrate with ERC-6909 functionality.
/// @dev Adapted from: https://github.com/Vectorized/solady/blob/main/src/tokens/ERC6909.sol
library LibERC6909 {
    /// @notice Thrown when owner balance for id is insufficient.
    error ERC6909InsufficientBalance();

    /// @notice Thrown when spender allowance for id is insufficient.
    error ERC6909InsufficientPermission();

    /// @notice Emitted when a transfer occurs.
    event Transfer(
        address _caller, address indexed _sender, address indexed _receiver, uint256 indexed _id, uint256 _amount
    );

    /// @notice Emitted when an operator is set.
    event OperatorSet(address indexed _owner, address indexed _spender, bool _approved);

    /// @notice Emitted when an approval occurs.
    event Approval(address indexed _owner, address indexed _spender, uint256 indexed _id, uint256 _amount);

    /// @dev Storage position determined by the keccak256 hash of the diamond storage identifier.
    bytes32 internal constant STORAGE_POSITION = keccak256("compose.erc6909");

    /// @custom:storage-location erc8042:compose.erc6909
    struct ERC6909Storage {
        mapping(address owner => mapping(uint256 id => uint256 amount)) balanceOf;
        mapping(address owner => mapping(address spender => mapping(uint256 id => uint256 amount))) allowance;
        mapping(address owner => mapping(address spender => bool)) isOperator;
    }

    /// @notice Returns a pointer to the ERC-6909 storage struct.
    /// @dev Uses inline assembly to access the storage slot defined by STORAGE_POSITION.
    /// @return s The ERC6909Storage struct in storage.
    function getStorage() internal pure returns (ERC6909Storage storage s) {
        bytes32 position = STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }

    /// @notice Mints `_amount` of token id `_id` to `_to`.
    /// @param _to The address of the receiver.
    /// @param _id The id of the token.
    /// @param _amount The amount of the token.
    function mint(address _to, uint256 _id, uint256 _amount) internal {
        ERC6909Storage storage s = getStorage();

        s.balanceOf[_to][_id] += _amount;

        emit Transfer(msg.sender, address(0), _to, _id, _amount);
    }

    /// @notice Burns `_amount` of token id `_id` from `_from`.
    /// @param _from The address of the sender.
    /// @param _id The id of the token.
    /// @param _amount The amount of the token.
    function burn(address _from, uint256 _id, uint256 _amount) internal {
        ERC6909Storage storage s = getStorage();

        s.balanceOf[_from][_id] -= _amount;

        emit Transfer(msg.sender, _from, address(0), _id, _amount);
    }

    /// @notice Transfers `_amount` of token id `_id` from `_from` to `_to`.
    /// @dev Allowance is not deducted if it is `type(uint256).max`
    /// @dev Allowance is not deducted if `_by` is an operator for `_from`.
    /// @param _by The address initiating the transfer.
    /// @param _from The address of the sender.
    /// @param _to The address of the receiver.
    /// @param _id The id of the token.
    /// @param _amount The amount of the token.
    function transfer(address _by, address _from, address _to, uint256 _id, uint256 _amount) internal {
        ERC6909Storage storage s = getStorage();

        if (_by != address(0) && !s.isOperator[_from][_by]) {
            uint256 allowed = s.allowance[_from][_by][_id];
            if (allowed != type(uint256).max) {
                if (_amount > allowed) revert ERC6909InsufficientPermission();
                s.allowance[_from][_by][_id] = allowed - _amount;
            }
        }

        if (_amount > s.balanceOf[_from][_id]) revert ERC6909InsufficientBalance();

        s.balanceOf[_from][_id] -= _amount;
        s.balanceOf[_to][_id] += _amount;

        emit Transfer(_by, _from, _to, _id, _amount);
    }

    /// @notice Approves an amount of an id to a spender.
    /// @param _owner The token owner.
    /// @param _spender The address of the spender.
    /// @param _id The id of the token.
    /// @param _amount The amount of the token.
    function approve(address _owner, address _spender, uint256 _id, uint256 _amount) internal {
        ERC6909Storage storage s = getStorage();

        s.allowance[_owner][_spender][_id] = _amount;

        emit Approval(_owner, _spender, _id, _amount);
    }

    /// @notice Sets or removes a spender as an operator for the caller.
    /// @param _owner The address of the owner.
    /// @param _spender The address of the spender.
    /// @param _approved The approval status.
    function setOperator(address _owner, address _spender, bool _approved) internal {
        ERC6909Storage storage s = getStorage();

        s.isOperator[_owner][_spender] = _approved;

        emit OperatorSet(_owner, _spender, _approved);
    }
}
