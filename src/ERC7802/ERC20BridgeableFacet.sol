    // SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

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

    error ERC20InvalidOwner(address _bridge);

    // @notice Revert when an interface id is not supported. // the interfaces supported are IERC165 and 7805
    /// @param interfaceId The unsupported interface id.
    error ERC20InvalidInterfaceId(bytes4 _interfaceId);

    error ERC20InsufficientBalance(address _from, uint256 _accountBalance, uint256 _value);
    /// @notice Emitted when tokens are minted via a cross-chain bridge.
    /// @param to The recipient of minted tokens.
    /// @param amount The amount minted.
    /// @param sender The bridge account that triggered the mint (msg.sender).

    event CrosschainMint(address indexed _to, uint256 _amount, address indexed _sender);

    /// @notice Emitted when a crosschain transfer burns tokens.
    /// @param from     Address of the account tokens are being burned from.
    /// @param amount   Amount of tokens burned.
    /// @param sender   Address of the caller (msg.sender) who invoked crosschainBurn.
    event CrosschainBurn(address indexed _from, uint256 _amount, address indexed _sender);

    /// @notice Mint tokens through a crosschain transfer.
    /// @param to     Address to mint tokens to.
    /// @param amount Amount of tokens to mint.

    event Transfer(address indexed _from, address indexed _to, uint256 _amount);

    /// @notice Emitted when an interface ID is registered or supported.
    /// @param interfaceId The supported interface identifier.
    event Interface(bytes4 indexed _interfaceId);

    /// @notice Storage slot for ERC-7802 using ERC8042

    bytes32 constant STORAGE_POSITION = keccak256("compose.erc7802");

    struct ERC20BridgeableStorage {
        address owner;
        uint256 totalSupply;
        mapping(address owner => uint256 balance) balanceOf;
        mapping(address => bool) trustedBridges;
        mapping(bytes4 => bool) supportedInterfaces;
    }

    /// @notice Return storage pointer to ERC7802Storage
    /// @dev Inline assembly to point storage to a fixed slot.
    /// @return s Pointer to storage struct.

    function getStorage() internal pure returns (ERC20BridgeableStorage storage s) {
        bytes32 position = STORAGE_POSITION;

        assembly {
            s.slot := position
        }
    }

    function getOwner() external view returns (address) {
        return getStorage().owner;
    }

    /// @notice Returns the total supply of tokens.
    /// @return The total token supply.

    function totalSupply() external view returns (uint256) {
        return getStorage().totalSupply;
    }

    ///@notice Returns the balance of a specific account.
    ///@param _account The address of the account.
    ///@return The account balance.

    function balanceOf(address _account) external view returns (uint256) {
        return getStorage().balanceOf[_account];
    }

    /// @notice Internal crosschain mint logic. MUST be called only after validating caller.
    /// @dev Increases totalSupply and recipient balance and emits CrosschainMint.
    /// @param _account The account to mint tokens to.
    /// @param _value The amount to mint.
    function crosschainMint(address _account, uint256 _value) external {
        ERC20BridgeableStorage storage s = getStorage();

        if (s.trustedBridges[msg.sender] == false) revert ERC20InvalidBridgeAccount(msg.sender);
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
        EERC20BridgeableStorage storage s = getStorage();

        if (s.trustedBridges[msg.sender] == false) revert ERC20InvalidBridgeAccount(msg.sender);
        if (_from == address(0)) revert ERC20InvalidReciever(address(0));

        uint256 accountBalance = s.balanceOf[_from];

        if (accountBalance < _value) revert ERC20InsufficientBalance(_from, accountBalance, _value);

        unchecked {
            s.totalSupply -= _value;
            s.balanceOf[_from] -= _value;
        }

        emit CrosschainBurn(_from, _value, msg.sender);
    }

   
}
