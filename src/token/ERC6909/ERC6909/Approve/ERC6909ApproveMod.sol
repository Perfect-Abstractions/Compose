// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

/**
 * @notice Thrown when the spender address is invalid.
 */
error ERC6909InvalidSpender(address _spender);

/**
 * @notice Emitted when an approval occurs.
 */
event Approval(address indexed _owner, address indexed _spender, uint256 indexed _id, uint256 _amount);
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
 * @notice Approves an amount of an id to a spender.
 * @param _spender The address of the spender.
 * @param _id The id of the token.
 * @param _amount The amount of the token.
 * @return Whether the approval succeeded.
 */
function approve(address _spender, uint256 _id, uint256 _amount) returns (bool) {
    if (_spender == address(0)) {
        revert ERC6909InvalidSpender(address(0));
    }

    ERC6909Storage storage s = getStorage();

    s.allowance[msg.sender][_spender][_id] = _amount;

    emit Approval(msg.sender, _spender, _id, _amount);

    return true;
}
