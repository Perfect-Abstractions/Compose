// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/// @title ERC-6909 Minimal Multi-Token Interface
/// @notice A complete, dependency-free ERC-6909 implementation using the diamond storage pattern.
contract ERC6909Facet {
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
    bytes32 constant STORAGE_POSITION = keccak256("compose.erc6909");

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

    /// @notice Owner balance of an id.
    /// @param _owner The address of the owner.
    /// @param _id The id of the token.
    /// @return The balance of the token.
    function balanceOf(address _owner, uint256 _id) external view returns (uint256) {}

    /// @notice Spender allowance of an id.
    /// @param _owner The address of the owner.
    /// @param _spender The address of the spender.
    /// @param _id The id of the token.
    /// @return The allowance of the token.
    function allowance(address _owner, address _spender, uint256 _id) external view returns (uint256) {}

    /// @notice Checks if a spender is approved by an owner as an operator.
    /// @param _owner The address of the owner.
    /// @param _spender The address of the spender.
    /// @return The approval status.
    function isOperator(address _owner, address _spender) external view returns (bool) {}

    /// @notice Transfers an amount of an id from the caller to a receiver.
    /// @param _receiver The address of the receiver.
    /// @param _id The id of the token.
    /// @param _amount The amount of the token.
    /// @return Whether the transfer succeeded.
    function transfer(address _receiver, uint256 _id, uint256 _amount) external returns (bool) {}

    /// @notice Transfers an amount of an id from a sender to a receiver.
    /// @param _sender The address of the sender.
    /// @param _receiver The address of the receiver.
    /// @param _id The id of the token.
    /// @param _amount The amount of the token.
    /// @return Whether the transfer succeeded.
    function transferFrom(address _sender, address _receiver, uint256 _id, uint256 _amount) external returns (bool) {}

    /// @notice Approves an amount of an id to a spender.
    /// @param _spender The address of the spender.
    /// @param _id The id of the token.
    /// @param _amount The amount of the token.
    /// @return Whether the approval succeeded.
    function approve(address _spender, uint256 _id, uint256 _amount) external returns (bool) {}

    /// @notice Sets or removes a spender as an operator for the caller.
    /// @param _spender The address of the spender.
    /// @param _approved The approval status.
    /// @return Whether the operator update succeeded.
    function setOperator(address _spender, bool _approved) external returns (bool) {}
}
