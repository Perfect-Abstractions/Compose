// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/// @title LibERC20 — ERC-7802 Library
/// @notice Provides internal functions and storage layout for ERC-7802 token logic.
/// @dev Uses ERC-8042 for storage location standardization and ERC-6093 for error conventions
library LibERC7802 {
    /// @notice Revert when a provided receiver is invalid(e.g,zero address) .
    /// @param _receiver The invalid reciever address.
    error ERC7802InvalidReciever(address _receiver);

    /// @notice Thrown when the sender address is invalid (e.g., zero address).
    /// @param _sender The invalid sender address.

    error ERC7802InvalidSender(address _sender);

    /// @notice Revert when caller is not a trusted bridge.
    /// @param _caller The unauthorized caller.
    error ERC7802InvalidBridgeAccount(address _caller);

    // @notice Revert when caller address is invalid.
    /// @param _caller is the invalid address.
    error ERC7802InvalidCallerAddress(address _caller);

    error ERC7802InvalidOwner(address bridge);

    // @notice Revert when an interface id is not supported. // the interfaces supported are IERC165 and 7805
    /// @param interfaceId The unsupported interface id.
    error ERC7802InvalidInterfaceId(bytes4 interfaceId);

    error ERC7802InsufficientBalance(address from, uint256 accountBalance, uint256 value);
    /// @notice Emitted when tokens are minted via a cross-chain bridge.
    /// @param to The recipient of minted tokens.
    /// @param amount The amount minted.
    /// @param sender The bridge account that triggered the mint (msg.sender).

    event CrosschainMint(address indexed to, uint256 amount, address indexed sender);

    /// @notice Emitted when a crosschain transfer burns tokens.
    /// @param from     Address of the account tokens are being burned from.
    /// @param amount   Amount of tokens burned.
    /// @param sender   Address of the caller (msg.sender) who invoked crosschainBurn.
    event CrosschainBurn(address indexed from, uint256 amount, address indexed sender);

    /// @notice Mint tokens through a crosschain transfer.
    /// @param to     Address to mint tokens to.
    /// @param amount Amount of tokens to mint.

    event Transfer(address indexed from, address indexed to, uint256 amount);

    /// @notice Emitted when there is a valid supported interface call
    ///@param  InterfaceId The supported interface identifier.
    event Interface(bytes4 indexed InterfaceId);

    /// @notice Storage slot for ERC-7802 using ERC8042 for storage location standardization

    bytes32 constant STORAGE_POSITION = keccak256("compose.erc7802");

    struct ERC7802Storage {
        address owner;
        uint256 totalSupply;
        mapping(address owner => uint256 balance) balanceOf;
        mapping(address => bool) _trustedBridges;
        mapping(bytes4 => bool) _supportedInterfaces;
    }

    /// @notice Return storage pointer to ERC7802Storage
    /// @dev Inline assembly to point storage to a fixed slot.
    /// @return s Pointer to storage struct.

    function getStorage() internal pure returns (ERC7802Storage storage s) {
        bytes32 position = STORAGE_POSITION;

        assembly {
            s.slot := position
        }
    }

    // the bridge account must be a trusted account
    /// @notice Internal crosschain mint logic. MUST be called only after validating caller.
    /// @dev Increases totalSupply and recipient balance and emits CrosschainMint.
    /// @param _account The account to mint tokens to.
    /// @param _value The amount to mint.
    function crooschainMint(address _account, uint256 _value) internal {
        ERC7802Storage storage s = getStorage();

        if (s._trustedBridges[msg.sender] == false) revert ERC7802InvalidBridgeAccount(msg.sender);
        if (_account == address(0)) revert ERC7802InvalidReciever(address(0));

        unchecked {
            s.totalSupply += _value;
            s.balanceOf[_account] += _value;
        }

        emit CrosschainMint(_account, _value, msg.sender);
    }

    /// @notice Internal crosschain burn logic. MUST be called only after validating caller.
    /// @dev Decreases totalSupply and the `from` balance and emits CrosschainBurn.
    /// @param _from The account to burn tokens from.
    /// @param _value The amount to burn.
    function crosschainBurn(address _from, uint256 _value) internal {
        ERC7802Storage storage s = getStorage();

        if (s._trustedBridges[msg.sender] == false) revert ERC7802InvalidBridgeAccount(msg.sender);
        if (_from == address(0)) revert ERC7802InvalidReciever(address(0));

        uint256 accountBalance = s.balanceOf[_from];

        if (accountBalance < _value) revert ERC7802InsufficientBalance(_from, accountBalance, _value);

        unchecked {
            s.totalSupply -= _value;
            s.balanceOf[_from] -= _value;
        }

        emit CrosschainBurn(_from, _value, msg.sender);
    }

    //ERC165 and 7805 supports
    /// @notice Query whether an interface id is supported (ERC-165 style).
    /// @param interfaceId The interface id to query.

    function supportInterface(bytes4 interfaceId) internal {
        ERC7802Storage storage s = getStorage();
        if (interfaceId != 0x33331994 || interfaceId == 0x01ffc9a7) revert ERC7802InvalidInterfaceId(interfaceId);

        s._supportedInterfaces[interfaceId] = true;

        emit Interface(interfaceId);
    }

    // @notice Add a trusted bridge address. Owner-only.
    /// @param _bridge The bridge address to add.
    function addTrustedBridges(address _bridge) internal {
        ERC7802Storage storage s = getStorage();

        if (msg.sender != s.owner) revert ERC7802InvalidOwner(msg.sender);
        s._trustedBridges[_bridge] = true;
    }

    /// @notice Remove a trusted bridge address. Owner-only.
    /// @param _bridge The bridge address to remove.
    function removeTrustedBridges(address _bridge) internal {
        ERC7802Storage storage s = getStorage();

        if (msg.sender != s.owner) revert ERC7802InvalidOwner(msg.sender);
        s._trustedBridges[_bridge] = false;
    }

    /// @notice Internal check to check if the bridge is trusted.
    /// @dev Reverts if caller is zero or not in the trusted bridges mapping.
    /// @param _caller The address to validate

    function _checkTokenBridge(address _caller) internal {
        ERC7802Storage storage s = getStorage();

        if (_caller == address(0)) revert ERC7802InvalidBridgeAccount(address(0));
        if (s._trustedBridges[_caller] == false) revert ERC7802InvalidBridgeAccount(_caller);
    }
}
