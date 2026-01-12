// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

/*
 * @title ERC20MintMod
 * @notice Provides internal functions for minting ERC-20 tokens.
 * @dev Uses ERC-8042 for storage location standardization and ERC-6093 for error conventions.
 */

/**
 * @notice Thrown when the receiver address is invalid (e.g., zero address).
 * @param _receiver The invalid receiver address.
 */
error ERC20InvalidReceiver(address _receiver);

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
 * @notice Mints new tokens to a specified address.
 * @dev Increases both total supply and the recipient's balance.
 * @param _account The address receiving the newly minted tokens.
 * @param _value The number of tokens to mint.
 */
function mintERC20(address _account, uint256 _value) {
    ERC20Storage storage s = getStorage();
    if (_account == address(0)) {
        revert ERC20InvalidReceiver(address(0));
    }
    s.totalSupply += _value;
    s.balanceOf[_account] += _value;
    emit Transfer(address(0), _account, _value);
}
