// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/// @title LibERC20Bridgeable — ERC-7802 like Library
/// @notice Provides internal functions and storage layout for ERC-7802 token logic.
/// @dev Uses ERC-8042 for storage location standardization and ERC-6093 for error conventions
library LibERC20Bridgeable {
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

    /// @notice Storage slot for ERC-20 Bridgeable  using ERC8042 for storage location standardization
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
    function erc20Storage() internal pure returns (ERC20Storage storage s) {
        bytes32 position = ERC20_STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }
    /// @notice Storage slot for ERC-20 Bridgeable using ERC8042 as template

    bytes32 constant BRIDGEABLE_STORAGE_POSITION = keccak256("compose.erc20.bridgeable");

    struct ERC20BridgeableStorage {
        mapping(address => bool) trustedBridges;
    }

    function bridgeStorage() internal pure returns (ERC20BridgeableStorage storage s) {
        bytes32 position = BRIDGEABLE_STORAGE_POSITION;

        assembly {
            s.slot := position
        }
    }

    // the bridge account must be a trusted account
    /// @notice Internal crosschain mint logic. MUST be called only after validating caller.
    /// @dev Increases totalSupply and recipient balance and emits CrosschainMint.
    /// @param _account The account to mint tokens to.
    /// @param _value The amount to mint.
    function crosschainMint(address _account, uint256 _value) internal {
        ERC20Storage storage erc20 = erc20Storage();
        ERC20BridgeableStorage storage bridge = bridgeStorage();

        if (bridge.trustedBridges[msg.sender] == false) {
            revert ERC20InvalidBridgeAccount(msg.sender);
        }
        if (_account == address(0)) {
            revert ERC20InvalidReciever(address(0));
        }
        unchecked {
            erc20.totalSupply += _value;
            erc20.balanceOf[_account] += _value;
        }

        emit CrosschainMint(_account, _value, msg.sender);
    }

    /// @notice Internal crosschain burn logic. MUST be called only after validating caller.
    /// @dev Decreases totalSupply and the `from` balance and emits CrosschainBurn.
    /// @param _from The account to burn tokens from.
    /// @param _value The amount to burn.
    function crosschainBurn(address _from, uint256 _value) internal {
        ERC20Storage storage erc20 = erc20Storage();
        ERC20BridgeableStorage storage bridge = bridgeStorage();

        if (bridge.trustedBridges[msg.sender] == false) {
            revert ERC20InvalidBridgeAccount(msg.sender);
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

        emit CrosschainBurn(_from, _value, msg.sender);
    }
    /// @notice Internal check to check if the bridge is trusted.
    /// @dev Reverts if caller is zero or not in the trusted bridges mapping.
    /// @param _caller The address to validate

    function checkTokenBridge(address _caller) internal view {
        ERC20BridgeableStorage storage bridge = bridgeStorage();

        if (_caller == address(0)) {
            revert ERC20InvalidBridgeAccount(address(0));
        }
        if (bridge.trustedBridges[_caller] == false) {
            revert ERC20InvalidBridgeAccount(_caller);
        }
    }
}
