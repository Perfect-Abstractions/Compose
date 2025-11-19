// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

contract ERC20Facet {
    /// @notice Thrown when an account has insufficient balance for a transfer or burn.
    /// @param _sender Address attempting the transfer.
    /// @param _balance Current balance of the sender.
    /// @param _needed Amount required to complete the operation.
    error ERC20InsufficientBalance(address _sender, uint256 _balance, uint256 _needed);

    /// @notice Thrown when the sender address is invalid (e.g., zero address).
    /// @param _sender Invalid sender address.
    error ERC20InvalidSender(address _sender);

    /// @notice Thrown when the receiver address is invalid (e.g., zero address).
    /// @param _receiver Invalid receiver address.
    error ERC20InvalidReceiver(address _receiver);

    /// @notice Thrown when a spender tries to use more than the approved allowance.
    /// @param _spender Address attempting to spend.
    /// @param _allowance Current allowance for the spender.
    /// @param _needed Amount required to complete the operation.
    error ERC20InsufficientAllowance(address _spender, uint256 _allowance, uint256 _needed);

    /// @notice Thrown when the spender address is invalid (e.g., zero address).
    /// @param _spender Invalid spender address.
    error ERC20InvalidSpender(address _spender);

    /// @notice Thrown when a permit signature is invalid or expired.
    /// @param _owner The address that signed the permit.
    /// @param _spender The address that was approved.
    /// @param _value The amount that was approved.
    /// @param _deadline The deadline for the permit.
    /// @param _v The recovery byte of the signature.
    /// @param _r The r value of the signature.
    /// @param _s The s value of the signature.
    error ERC2612InvalidSignature(
        address _owner, address _spender, uint256 _value, uint256 _deadline, uint8 _v, bytes32 _r, bytes32 _s
    );

    /// @notice Emitted when an approval is made for a spender by an owner.
    /// @param _owner The address granting the allowance.
    /// @param _spender The address receiving the allowance.
    /// @param _value The amount approved.
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);

    /// @notice Emitted when tokens are transferred between two addresses.
    /// @param _from Address sending the tokens.
    /// @param _to Address receiving the tokens.
    /// @param _value Amount of tokens transferred.
    event Transfer(address indexed _from, address indexed _to, uint256 _value);

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
        mapping(address owner => mapping(address spender => uint256 allowance)) allowances;
        mapping(address owner => uint256) nonces;
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

    /**
     * @notice Returns the name of the token.
     * @return The token name.
     */
    function name() external view returns (string memory) {
        return getStorage().name;
    }

    /**
     * @notice Returns the symbol of the token.
     * @return The token symbol.
     */
    function symbol() external view returns (string memory) {
        return getStorage().symbol;
    }

    /**
     * @notice Returns the number of decimals used for token precision.
     * @return The number of decimals.
     */
    function decimals() external view returns (uint8) {
        return getStorage().decimals;
    }

    /**
     * @notice Returns the total supply of tokens.
     * @return The total token supply.
     */
    function totalSupply() external view returns (uint256) {
        return getStorage().totalSupply;
    }

    /**
     * @notice Returns the balance of a specific account.
     * @param _account The address of the account.
     * @return The account balance.
     */
    function balanceOf(address _account) external view returns (uint256) {
        return getStorage().balanceOf[_account];
    }

    /**
     * @notice Returns the remaining number of tokens that a spender is allowed to spend on behalf of an owner.
     * @param _owner The address of the token owner.
     * @param _spender The address of the spender.
     * @return The remaining allowance.
     */
    function allowance(address _owner, address _spender) external view returns (uint256) {
        return getStorage().allowances[_owner][_spender];
    }

    /**
     * @notice Approves a spender to transfer up to a certain amount of tokens on behalf of the caller.
     * @dev Emits an {Approval} event.
     * @param _spender The address approved to spend tokens.
     * @param _value The number of tokens to approve.
     * @return True if the approval was successful.
     */
    function approve(address _spender, uint256 _value) external returns (bool) {
        ERC20Storage storage s = getStorage();
        if (_spender == address(0)) {
            revert ERC20InvalidSpender(address(0));
        }
        s.allowances[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    /**
     * @notice Transfers tokens to another address.
     * @dev Emits a {Transfer} event.
     * @param _to The address to receive the tokens.
     * @param _value The amount of tokens to transfer.
     * @return True if the transfer was successful.
     */
    function transfer(address _to, uint256 _value) external returns (bool) {
        ERC20Storage storage s = getStorage();
        if (_to == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        uint256 fromBalance = s.balanceOf[msg.sender];
        if (fromBalance < _value) {
            revert ERC20InsufficientBalance(msg.sender, fromBalance, _value);
        }
        unchecked {
            s.balanceOf[msg.sender] = fromBalance - _value;
        }
        s.balanceOf[_to] += _value;
        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    /**
     * @notice Transfers tokens on behalf of another account, provided sufficient allowance exists.
     * @dev Emits a {Transfer} event and decreases the spender's allowance.
     * @param _from The address to transfer tokens from.
     * @param _to The address to transfer tokens to.
     * @param _value The amount of tokens to transfer.
     * @return True if the transfer was successful.
     */
    function transferFrom(address _from, address _to, uint256 _value) external returns (bool) {
        ERC20Storage storage s = getStorage();
        if (_from == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        if (_to == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        uint256 currentAllowance = s.allowances[_from][msg.sender];
        if (currentAllowance < _value) {
            revert ERC20InsufficientAllowance(msg.sender, currentAllowance, _value);
        }
        uint256 fromBalance = s.balanceOf[_from];
        if (fromBalance < _value) {
            revert ERC20InsufficientBalance(_from, fromBalance, _value);
        }
        unchecked {
            if (currentAllowance != type(uint256).max) {
                s.allowances[_from][msg.sender] = currentAllowance - _value;
            }
            s.balanceOf[_from] = fromBalance - _value;
        }
        s.balanceOf[_to] += _value;
        emit Transfer(_from, _to, _value);
        return true;
    }

    /**
     * @notice Burns (destroys) a specific amount of tokens from the caller's balance.
     * @dev Emits a {Transfer} event to the zero address.
     * @param _value The amount of tokens to burn.
     */
    function burn(uint256 _value) external {
        ERC20Storage storage s = getStorage();
        uint256 balance = s.balanceOf[msg.sender];
        if (balance < _value) {
            revert ERC20InsufficientBalance(msg.sender, balance, _value);
        }
        unchecked {
            s.balanceOf[msg.sender] = balance - _value;
            s.totalSupply -= _value;
        }
        emit Transfer(msg.sender, address(0), _value);
    }

    /**
     * @notice Burns tokens from another account, deducting from the caller's allowance.
     * @dev Emits a {Transfer} event to the zero address.
     * @param _account The address whose tokens will be burned.
     * @param _value The amount of tokens to burn.
     */
    function burnFrom(address _account, uint256 _value) external {
        ERC20Storage storage s = getStorage();
        uint256 currentAllowance = s.allowances[_account][msg.sender];
        if (currentAllowance < _value) {
            revert ERC20InsufficientAllowance(msg.sender, currentAllowance, _value);
        }
        uint256 balance = s.balanceOf[_account];
        if (balance < _value) {
            revert ERC20InsufficientBalance(_account, balance, _value);
        }
        unchecked {
            if (currentAllowance != type(uint256).max) {
                s.allowances[_account][msg.sender] = currentAllowance - _value;
            }
            s.balanceOf[_account] = balance - _value;
            s.totalSupply -= _value;
        }
        emit Transfer(_account, address(0), _value);
    }

    // EIP-2612 Permit Extension

    /**
     * @notice Returns the current nonce for an owner.
     * @dev This value changes each time a permit is used.
     * @param _owner The address of the owner.
     * @return The current nonce.
     */
    function nonces(address _owner) external view returns (uint256) {
        return getStorage().nonces[_owner];
    }

    /**
     * @notice Returns the domain separator used in the encoding of the signature for {permit}.
     * @dev This value is unique to a contract and chain ID combination to prevent replay attacks.
     * @return The domain separator.
     */
    function DOMAIN_SEPARATOR() external view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(getStorage().name)),
                keccak256("1"),
                block.chainid,
                address(this)
            )
        );
    }

    /**
     * @notice Sets the allowance for a spender via a signature.
     * @dev This function implements EIP-2612 permit functionality.
     * @param _owner The address of the token owner.
     * @param _spender The address of the spender.
     * @param _value The amount of tokens to approve.
     * @param _deadline The deadline for the permit (timestamp).
     * @param _v The recovery byte of the signature.
     * @param _r The r value of the signature.
     * @param _s The s value of the signature.
     */
    function permit(
        address _owner,
        address _spender,
        uint256 _value,
        uint256 _deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external {
        if (_spender == address(0)) {
            revert ERC20InvalidSpender(address(0));
        }
        if (block.timestamp > _deadline) {
            revert ERC2612InvalidSignature(_owner, _spender, _value, _deadline, _v, _r, _s);
        }

        ERC20Storage storage s = getStorage();
        uint256 currentNonce = s.nonces[_owner];
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                _owner,
                _spender,
                _value,
                currentNonce,
                _deadline
            )
        );

        bytes32 hash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                keccak256(
                    abi.encode(
                        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                        keccak256(bytes(s.name)),
                        keccak256("1"),
                        block.chainid,
                        address(this)
                    )
                ),
                structHash
            )
        );

        address signer = ecrecover(hash, _v, _r, _s);
        if (signer != _owner || signer == address(0)) {
            revert ERC2612InvalidSignature(_owner, _spender, _value, _deadline, _v, _r, _s);
        }

        s.allowances[_owner][_spender] = _value;
        s.nonces[_owner] = currentNonce + 1;
        emit Approval(_owner, _spender, _value);
    }
}
