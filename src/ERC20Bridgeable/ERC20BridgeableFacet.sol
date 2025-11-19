 // SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/// @title ERC20Bridgeable — ERC-7802-like Implementation Facet
/// @notice Provides  functions and storage layout for ERC20-Bridgeable token logic.
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

    /// @notice Revert when the owner is invalid .
    /// @param _bridge The invalid  address.
    error ERC20InvalidOwner(address _bridge);

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
    bytes32 constant STORAGE_POSITION = keccak256("compose.erc20");

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
    function getStorage() internal pure returns (ERC20Storage storage s) {
        bytes32 position = STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }

  bytes32 constant STORAGE_POSITION1 = keccak256("compose.owner");

    /// @custom:storage-location erc8042:compose.owner
    struct OwnerStorage {
        address owner;
    }

    /// @notice Returns a pointer to the ERC-173 storage struct.
    /// @dev Uses inline assembly to access the storage slot defined by STORAGE_POSITION.
    /// @return s1 The OwnerStorage struct in storage.
    function getStorage1() internal pure returns (OwnerStorage storage s1) {
        bytes32 position = STORAGE_POSITION1;
        assembly {
            s1.slot := position
        }
    }

    /// @notice Storage slot for ERC-20 Bridgeable using ERC8042 as template

    bytes32 constant STORAGE_POSITION2 = keccak256("compose.erc20.bridgeable");

    struct ERC20BridgeableStorage {
        mapping(address => bool) trustedBridges;
    }

    function getStorage2() internal pure returns (ERC20BridgeableStorage storage s2) {
        bytes32 position = STORAGE_POSITION2;

        assembly {
            s2.slot := position
        }
    }

    /// @notice Internal crosschain mint logic. MUST be called only after validating caller.
    /// @dev Increases totalSupply and recipient balance and emits CrosschainMint.
    /// @param _account The account to mint tokens to.
    /// @param _value The amount to mint.

    function crosschainMint(address _account, uint256 _value) external {
        ERC20Storage storage s = getStorage();
        ERC20BridgeableStorage storage s2 = getStorage2();

        if (s2.trustedBridges[msg.sender] == false) revert ERC20InvalidBridgeAccount(msg.sender);
        if (_account == address(0)) revert ERC20InvalidReciever(address(0));

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
    function crosschainBurn(address _from, uint256 _value) external {
        ERC20Storage storage s = getStorage();
        ERC20BridgeableStorage storage s2 = getStorage2();
        
        if (s2.trustedBridges[msg.sender] == false) revert ERC20InvalidBridgeAccount(msg.sender);
        if (_from == address(0)) revert ERC20InvalidReciever(address(0));

        uint256 accountBalance = s.balanceOf[_from];

        if (accountBalance < _value) revert ERC20InsufficientBalance(_from, accountBalance, _value);

        unchecked {
            s.totalSupply -= _value;
            s.balanceOf[_from] -= _value;
        }

        emit CrosschainBurn(_from, _value, msg.sender);
    }

    // @notice Add a trusted bridge address. Owner-only.
    /// @param _bridge The bridge address to add.
    function addTrustedBridges(address _bridge) external {
        ERC20BridgeableStorage storage s2 = getStorage2();
        OwnerStorage storage s1 = getStorage1();
        if (msg.sender != s1.owner) revert ERC20InvalidOwner(msg.sender);
        s2.trustedBridges[_bridge] = true;
    }

    /// @notice Remove a trusted bridge address. Owner-only.
    /// @param _bridge The bridge address to remove.
    function removeTrustedBridges(address _bridge) external {
        ERC20BridgeableStorage storage s2 = getStorage2();
        OwnerStorage storage s1 = getStorage1();
        if (msg.sender != s1.owner) revert ERC20InvalidOwner(msg.sender);
        s2.trustedBridges[_bridge] = false;
    }

    /// @notice Internal check to check if the bridge is trusted.
    /// @dev Reverts if caller is zero or not in the trusted bridges mapping.
    /// @param _caller The address to validate

    function checkTokenBridge(address _caller) external {
        ERC20BridgeableStorage storage s2 = getStorage2();

        if (_caller == address(0)) revert ERC20InvalidBridgeAccount(address(0));
        if (s2.trustedBridges[_caller] == false) revert ERC20InvalidBridgeAccount(_caller);
    }
}
