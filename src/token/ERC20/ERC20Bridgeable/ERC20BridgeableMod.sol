// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

/*
 *  /// @title LibERC20Bridgeable — ERC-7802 Library
 */
/*
 *  /// @notice Provides internal functions and storage layout for ERC-7802 token logic.
 */
/**
 *  /// @dev Uses ERC-8042 for storage location standardization and ERC-6093 for error conventions
 */

/**
 * @notice Revert when a provided receiver is invalid(e.g,zero address) .
 * @param _receiver The invalid reciever address.
 */
error ERC20InvalidReciever(address _receiver);

/**
 * @notice Thrown when the sender address is invalid (e.g., zero address).
 * @param _sender The invalid sender address.
 */
error ERC20InvalidSender(address _sender);

/**
 * @notice Revert when caller is not a trusted bridge.
 * @param _caller The unauthorized caller.
 */
error ERC20InvalidBridgeAccount(address _caller);

/**
 * @notice Revert when caller address is invalid.
 */
/**
 * @param _caller is the invalid address.
 */
error ERC20InvalidCallerAddress(address _caller);

/**
 * @notice Thrown when the account does not have a specific role.
 * @param _role The role that the account does not have.
 * @param _account The account that does not have the role.
 */
error AccessControlUnauthorizedAccount(address _account, bytes32 _role);

error ERC20InsufficientBalance(address _from, uint256 _accountBalance, uint256 _value);

/**
 * @notice Emitted when tokens are minted via a cross-chain bridge.
 * @param _to The recipient of minted tokens.
 * @param _amount The amount minted.
 * @param _sender The bridge account that triggered the mint (msg.sender).
 */
event CrosschainMint(address indexed _to, uint256 _amount, address indexed _sender);

/**
 * @notice Emitted when a crosschain transfer burns tokens.
 * @param _from     Address of the account tokens are being burned from.
 * @param _amount   Amount of tokens burned.
 * @param _sender   Address of the caller (msg.sender) who invoked crosschainBurn.
 */
event CrosschainBurn(address indexed _from, uint256 _amount, address indexed _sender);

/**
 * @notice Emitted when tokens are transferred between two addresses.
 * @param _from Address sending the tokens.
 * @param _to Address receiving the tokens.
 * @param _value Amount of tokens transferred.
 */
event Transfer(address indexed _from, address indexed _to, uint256 _value);

/*
 * -----------------------------------------------------------------------
 * ERC20 integration (re-uses ERC20Facet storage layout)
 * -----------------------------------------------------------------------
 */

/*
 * @notice Storage slot for ERC-20 token using ERC8042 for storage location standardization
 * @dev Storage position determined by the keccak256 hash of the diamond storage identifier.
 */
bytes32 constant ERC20_TRANSFER_STORAGE_POSITION = keccak256("compose.erc20.transfer");

/**
 * @dev ERC-8042 compliant storage struct for ERC20 token data.
 * @custom:storage-location erc8042:compose.erc20.transfer
 */
struct ERC20TransferStorage {
    mapping(address owner => uint256 balance) balanceOf;
    uint256 totalSupply;
}
/**
 * @notice Returns the ERC20 storage struct from the predefined diamond storage slot.
 * @dev Uses inline assembly to set the storage slot reference.
 * @return s The ERC20 storage struct reference.
 */

function getERC20TransferStorage() pure returns (ERC20TransferStorage storage s) {
    bytes32 position = ERC20_TRANSFER_STORAGE_POSITION;
    assembly {
        s.slot := position
    }
}

/*
 * -----------------------------------------------------------------------
 * AccessControl integration (re-uses AccessControlFacet storage layout)
 * -----------------------------------------------------------------------
 */

/*
 * @notice Storage slot identifier.
 */
bytes32 constant ACCESS_STORAGE_POSITION = keccak256("compose.accesscontrol");

/*
 * @notice storage struct for the AccessControl.
 */
struct AccessControlStorage {
    mapping(address account => mapping(bytes32 role => bool hasRole)) hasRole;
}

/**
 * @notice helper to return AccessControlStorage at its diamond slot
 */
function getAccessControlStorage() pure returns (AccessControlStorage storage s) {
    bytes32 position = ACCESS_STORAGE_POSITION;
    assembly {
        s.slot := position
    }
}

/**
 * @notice Cross-chain mint — callable only by an address having the `trusted-bridge` role.
 * @param _account The account to mint tokens to.
 * @param _value The amount to mint.
 */
function crosschainMint(address _account, uint256 _value) {
    ERC20TransferStorage storage erc20Transfer = getERC20TransferStorage();

    AccessControlStorage storage acs = getAccessControlStorage();

    /**
     * authorize: caller must have the trusted-bridge role
     */
    if (!acs.hasRole[msg.sender]["trusted-bridge"]) {
        revert AccessControlUnauthorizedAccount(msg.sender, "trusted-bridge");
    }

    if (_account == address(0)) {
        revert ERC20InvalidReciever(address(0));
    }

    unchecked {
        erc20Transfer.totalSupply += _value;
        erc20Transfer.balanceOf[_account] += _value;
    }

    emit Transfer(address(0), _account, _value);
    emit CrosschainMint(_account, _value, msg.sender);
}

/**
 * @notice Cross-chain burn — callable only by an address having the `trusted-bridge` role.
 * @param _from The account to burn tokens from.
 * @param _value The amount to burn.
 */
function crosschainBurn(address _from, uint256 _value) {
    ERC20TransferStorage storage erc20Transfer = getERC20TransferStorage();

    AccessControlStorage storage acs = getAccessControlStorage();

    /**
     * authorize: caller must have the trusted-bridge role
     */
    if (!acs.hasRole[msg.sender]["trusted-bridge"]) {
        revert AccessControlUnauthorizedAccount(msg.sender, "trusted-bridge");
    }

    if (_from == address(0)) {
        revert ERC20InvalidReciever(address(0));
    }

    uint256 accountBalance = erc20Transfer.balanceOf[_from];

    if (accountBalance < _value) {
        revert ERC20InsufficientBalance(_from, accountBalance, _value);
    }

    unchecked {
        erc20Transfer.totalSupply -= _value;
        erc20Transfer.balanceOf[_from] -= _value;
    }
    emit Transfer(_from, address(0), _value);
    emit CrosschainBurn(_from, _value, msg.sender);
}

/**
 * @notice Internal check to check if the bridge (caller) is trusted.
 * @dev Reverts if caller is zero or not in the AccessControl `trusted-bridge` role.
 * @param _caller The address to validate
 */
function checkTokenBridge(address _caller) view {
    AccessControlStorage storage acs = getAccessControlStorage();

    if (_caller == address(0)) {
        revert ERC20InvalidBridgeAccount(address(0));
    }

    if (!acs.hasRole[_caller]["trusted-bridge"]) {
        revert ERC20InvalidBridgeAccount(_caller);
    }
}
