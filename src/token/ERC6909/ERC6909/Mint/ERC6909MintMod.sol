// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

/**
 * @notice Thrown when the receiver address is invalid.
 */
error ERC6909InvalidReceiver(address _receiver);
/**
 * @dev Storage position determined by the keccak256 hash of the diamond storage identifier.
 */

/**
 * @notice Emitted when a transfer occurs.
 */
event Transfer(
    address _caller, address indexed _sender, address indexed _receiver, uint256 indexed _id, uint256 _amount
);

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
 * @notice Mints new tokens to a specified address.
 * @dev Increases both total supply and the recipient's balance.
 * @param _account The address receiving the newly minted tokens.
 * @param _value The number of tokens to mint.
 */
function mintERC6909(address _account, uint256 _id, uint256 _value) {
    ERC6909Storage storage s = getStorage();
    if (_account == address(0)) {
        revert ERC6909InvalidReceiver(address(0));
    }

    s.balanceOf[_account][_id] += _value;
    emit Transfer(msg.sender, address(0), _account, _id, _value);
}

