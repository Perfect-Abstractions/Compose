// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/// @title ERC-165 Standard Interface Detection Interface
/// @notice Interface for detecting what interfaces a contract implements
/// @dev ERC-165 allows contracts to publish their supported interfaces
interface IERC165 {
    /// @notice Query if a contract implements an interface
    /// @param _interfaceId The interface identifier, as specified in ERC-165
    /// @dev Interface identification is specified in ERC-165. This function
    /// uses less than 30,000 gas.
    /// @return `true` if the contract implements `_interfaceId` and
    /// `_interfaceId` is not 0xffffffff, `false` otherwise
    function supportsInterface(bytes4 _interfaceId) external view returns (bool);
}

/// @title ERC20Bridgeable — ERC-7802 Implementation Facet
/// @notice Provides functions and storage layout for ERC20-Bridgeable token logic.
/// @dev Uses ERC-8042 for storage location standardization and ERC-6093 for error conventions
contract ERC20BridgeableFacet {
    /// @notice Revert when a provided receiver is invalid(e.g,zero address) .
    /// @param _receiver The invalid reciever address.
    error ERC20InvalidReciever(address _receiver);

    /// @notice Thrown when the sender address is invalid (e.g., zero address).
    /// @param _sender The invalid sender address.
    error ERC20InvalidSender(address _sender);

    /// @notice Revert when caller is not a trusted bridge.
    /// @param _caller The unauthorized caller.
    error ERC20InvalidBridgeAccount(address _caller);

    // @notice Revert when caller address is invalid.
    /// @param _caller is the invalid address.
    error ERC20InvalidCallerAddress(address _caller);

    /// @notice Unauthorized sender error from AccessControl.
    error AccessControlUnauthorized(address _sender, address _account);

    error ERC20InsufficientBalance(address _from, uint256 _accountBalance, uint256 _value);

    /// @notice Emitted when tokens are minted via a cross-chain bridge.
    /// @param _to The recipient of minted tokens.
    /// @param _amount The amount minted.
    /// @param _sender The bridge account that triggered the mint (msg.sender).
    event CrosschainMint(address indexed _to, uint256 _amount, address indexed _sender);

    /// @notice Emitted when a crosschain transfer burns tokens.
    /// @param _from     Address of the account tokens are being burned from.
    /// @param _amount   Amount of tokens burned.
    /// @param _sender   Address of the caller (msg.sender) who invoked crosschainBurn.
    event CrosschainBurn(address indexed _from, uint256 _amount, address indexed _sender);

    /// @notice Emitted when tokens are transferred between two addresses.
    /// @param _from Address sending the tokens.
    /// @param _to Address receiving the tokens.
    /// @param _value Amount of tokens transferred.
    event Transfer(address indexed _from, address indexed _to, uint256 _value);

    /// -----------------------------------------------------------------------
    /// ERC165 integration (re-uses ERC165Facet storage layout)
    /// -----------------------------------------------------------------------

    /// @notice Storage slot for ERC-165 using ERC8042 for storage location standardization
    /// @dev Storage position determined by the keccak256 hash of the diamond storage identifier.
    bytes32 constant ERC165_STORAGE_POSITION = keccak256("compose.erc165");
    /// @notice ERC-165 storage layout using the ERC-8042 standard
    /// @custom:storage-location erc8042:compose.erc165

    struct ERC165Storage {
        /// @notice Mapping of interface IDs to whether they are supported
        mapping(bytes4 => bool) supportedInterfaces;
    }

    function getErc165Storage() internal pure returns (ERC165Storage storage s) {
        bytes32 position = ERC165_STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }

    /// -----------------------------------------------------------------------
    /// ERC20 integration (re-uses ERC20Facet storage layout)
    /// -----------------------------------------------------------------------

    /// @notice Storage slot for ERC-20 token using ERC8042 for storage location standardization
    /// @dev Storage position determined by the keccak256 hash of the diamond storage identifier.
    bytes32 constant ERC20_STORAGE_POSITION = keccak256("compose.erc20");

    /**
     * @dev ERC-8042 compliant storage struct for ERC20 token data.
     * @custom:storage-location erc8042:compose.erc20
     */
    struct ERC20Storage {
        string name;
        string symbol;
        uint8 decimals;
        uint256 totalSupply;
        mapping(address owner => uint256 balance) balanceOf;
    }

    /**
     * @notice Returns the ERC20 storage struct from the predefined diamond storage slot.
     * @dev Uses inline assembly to set the storage slot reference.
     * @return s The ERC20 storage struct reference.
     */
    function getERC20Storage() internal pure returns (ERC20Storage storage s) {
        bytes32 position = ERC20_STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }

    /// -----------------------------------------------------------------------
    /// AccessControl integration (re-uses AccessControlFacet storage layout)
    /// -----------------------------------------------------------------------

    /// @notice Storage slot identifier.
    bytes32 constant ACCESS_STORAGE_POSITION = keccak256("compose.accesscontrol");

    /// @notice storage struct for the AccessControl.
    struct AccessControlStorage {
        mapping(address account => mapping(bytes32 role => bool hasRole)) hasRole;
    }

    /// @notice helper to return AccessControlStorage at its diamond slot
    function getAccessControlStorage() internal pure returns (AccessControlStorage storage s) {
        bytes32 position = ACCESS_STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }

    /// @notice role identifier for trusted bridge actors
    bytes32 internal constant TRUSTED_BRIDGE_ROLE = keccak256("trusted-bridge");

    /// @notice Cross-chain mint — callable only by an address having the `trusted-bridge` role.
    /// @param _account The account to mint tokens to.
    /// @param _value The amount to mint.
    function crosschainMint(address _account, uint256 _value) external {
        ERC20Storage storage erc20 = getERC20Storage();

        AccessControlStorage storage acs = getAccessControlStorage();

        // authorize: caller must have the trusted-bridge role
        if (!acs.hasRole[msg.sender][TRUSTED_BRIDGE_ROLE]) {
            revert AccessControlUnauthorized(msg.sender, _account);
        }

        if (_account == address(0)) {
            revert ERC20InvalidReciever(address(0));
        }

        unchecked {
            erc20.totalSupply += _value;
            erc20.balanceOf[_account] += _value;
        }
        emit Transfer(address(0), _account, _value);
        emit CrosschainMint(_account, _value, msg.sender);
    }

    /// @notice Cross-chain burn — callable only by an address having the `trusted-bridge` role.
    /// @param _from The account to burn tokens from.
    /// @param _value The amount to burn.
    function crosschainBurn(address _from, uint256 _value) external {
        ERC20Storage storage erc20 = getERC20Storage();

        AccessControlStorage storage acs = getAccessControlStorage();

        // authorize: caller must have the trusted-bridge role
        if (!acs.hasRole[msg.sender][TRUSTED_BRIDGE_ROLE]) {
            revert AccessControlUnauthorized(msg.sender, _from);
        }

        if (_from == address(0)) {
            revert ERC20InvalidReciever(address(0));
        }

        uint256 accountBalance = erc20.balanceOf[_from];

        if (accountBalance < _value) {
            revert ERC20InsufficientBalance(_from, accountBalance, _value);
        }

        unchecked {
            erc20.totalSupply -= _value;
            erc20.balanceOf[_from] -= _value;
        }

        emit Transfer(_from, address(0), _value);
        emit CrosschainBurn(_from, _value, msg.sender);
    }

    /// @notice Internal check to check if the bridge (caller) is trusted.
    /// @dev Reverts if caller is zero or not in the AccessControl `trusted-bridge` role.
    /// @param _caller The address to validate
    function checkTokenBridge(address _caller) external view {
        AccessControlStorage storage acs = getAccessControlStorage();

        if (_caller == address(0)) {
            revert ERC20InvalidBridgeAccount(address(0));
        }

        if (!acs.hasRole[_caller][TRUSTED_BRIDGE_ROLE]) {
            revert ERC20InvalidBridgeAccount(_caller);
        }
    }

    /// @notice Query if a contract implements an interface
    /// @param _interfaceId The interface identifier, as specified in ERC-165
    /// @dev This function checks if the diamond supports the given interface ID
    /// @return `true` if the contract implements `_interfaceId` and
    /// `_interfaceId` is not 0xffffffff, `false` otherwise
    function supportsInterface(bytes4 _interfaceId) external view returns (bool) {
        ERC165Storage storage erc165Storage = getErc165Storage();

        // If the ERC165 interface itself is being queried, return true
        // since this facet implements ERC165
        if (_interfaceId == type(IERC165).interfaceId) {
            return true;
        }

        return erc165Storage.supportedInterfaces[_interfaceId];
    }
}
