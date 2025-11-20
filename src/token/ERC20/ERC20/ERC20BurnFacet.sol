// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

contract ERC20BurnFacet {

    /// @notice Thrown when an account has insufficient balance for a transfer or burn.
    /// @param _sender Address attempting the transfer.
    /// @param _balance Current balance of the sender.
    /// @param _needed Amount required to complete the operation.
    error ERC20InsufficientBalance(address _sender, uint256 _balance, uint256 _needed);

    /// @notice Thrown when a spender tries to use more than the approved allowance.
    /// @param _spender Address attempting to spend.
    /// @param _allowance Current allowance for the spender.
    /// @param _needed Amount required to complete the operation.
    error ERC20InsufficientAllowance(address _spender, uint256 _allowance, uint256 _needed);

    /// @notice Thrown when the sender address is invalid (e.g., zero address).
    /// @param _sender Invalid sender address.
    error ERC20InvalidSender(address _sender);

    /// @notice Thrown when the receiver address is invalid (e.g., zero address).
    /// @param _receiver Invalid receiver address.
    error ERC20InvalidReceiver(address _receiver);

    /// @notice Thrown when the spender address is invalid (e.g., zero address).
    /// @param _spender Invalid spender address.
    error ERC20InvalidSpender(address _spender);

    /// @notice Emitted when tokens are transferred between two addresses.
    /// @param _from Address sending the tokens.
    /// @param _to Address receiving the tokens.
    /// @param _value Amount of tokens transferred.
    event Transfer(address indexed _from, address indexed _to, uint256 _value);

    /// @notice Emitted when an approval is made for a spender by an owner.
    /// @param _owner The address granting the allowance.
    /// @param _spender The address receiving the allowance.
    /// @param _value The amount approved.
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);

    // @dev Storage position determined by the keccak256 hash of the diamond storage identifier.
    bytes32 constant STORAGE_POSITION = keccak256("compose.erc20burn");

    /**
     * @dev ERC-8042 compliant storage struct for ERC20 token data.
     * @custom:storage-location erc8042:compose.erc20burn
     */
     struct ERC20BurnStorage {        
        mapping(address owner => uint256 balance) balanceOf;        
        mapping(address owner => mapping(address spender => uint256 allowance)) allowances;
        uint256 totalSupply;
    }

    /**
     * @notice Returns the ERC20 storage struct from the predefined diamond storage slot.
     * @dev Uses inline assembly to set the storage slot reference.
     * @return s The ERC20 storage struct reference.
     */
    function getStorage() internal pure returns (ERC20BurnStorage storage s) {
        bytes32 position = STORAGE_POSITION;
        assembly {
            s.slot := position
        }
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
     * @notice Transfers tokens on behalf of another account, provided sufficient allowance exists.
     * @dev Emits a {Transfer} event and decreases the spender's allowance.
     * @param _from The address to transfer tokens from.
     * @param _to The address to transfer tokens to.
     * @param _value The amount of tokens to transfer.
     * @return True if the transfer was successful.
     */
    function transferFrom(address _from, address _to, uint256 _value) external returns (bool) {
        ERC20BurnStorage storage s = getStorage();
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
        ERC20BurnStorage storage s = getStorage();
        if (_spender == address(0)) {
            revert ERC20InvalidSpender(address(0));
        }
        s.allowances[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    /**
     * @notice Burns (destroys) a specific amount of tokens from the caller's balance.
     * @dev Emits a {Transfer} event to the zero address.
     * @param _value The amount of tokens to burn.
     */
    function burn(uint256 _value) external {
        ERC20BurnStorage storage s = getStorage();
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
        ERC20BurnStorage storage s = getStorage();
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
}