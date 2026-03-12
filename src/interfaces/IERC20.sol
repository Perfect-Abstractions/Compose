// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

/**
 * @title ERC-20 Token Standard Interface
 * @notice Interface for ERC-20 token contracts with custom errors
 * @dev This interface includes all custom errors used by ERC-20 implementations
 */
interface IERC20 {
    /**
     * @notice Thrown when an account has insufficient balance for a transfer or burn.
     * @param _sender Address attempting the transfer.
     * @param _balance Current balance of the sender.
     * @param _needed Amount required to complete the operation.
     */
    error ERC20InsufficientBalance(address _sender, uint256 _balance, uint256 _needed);

    /**
     * @notice Thrown when the sender address is invalid (e.g., zero address).
     * @param _sender Invalid sender address.
     */
    error ERC20InvalidSender(address _sender);

    /**
     * @notice Thrown when the receiver address is invalid (e.g., zero address).
     * @param _receiver Invalid receiver address.
     */
    error ERC20InvalidReceiver(address _receiver);

    /**
     * @notice Thrown when a spender tries to use more than the approved allowance.
     * @param _spender Address attempting to spend.
     * @param _allowance Current allowance for the spender.
     * @param _needed Amount required to complete the operation.
     */
    error ERC20InsufficientAllowance(address _spender, uint256 _allowance, uint256 _needed);

    /**
     * @notice Thrown when the spender address is invalid (e.g., zero address).
     * @param _spender Invalid spender address.
     */
    error ERC20InvalidSpender(address _spender);

    /**
     * @notice Thrown when a permit signature is invalid or expired.
     * @param _owner The address that signed the permit.
     * @param _spender The address that was approved.
     * @param _value The amount that was approved.
     * @param _deadline The deadline for the permit.
     * @param _v The recovery byte of the signature.
     * @param _r The r value of the signature.
     * @param _s The s value of the signature.
     */
    error ERC2612InvalidSignature(
        address _owner, address _spender, uint256 _value, uint256 _deadline, uint8 _v, bytes32 _r, bytes32 _s
    );

    /**
     * @notice Emitted when tokens are transferred between two addresses.
     * @param _from Address sending the tokens.
     * @param _to Address receiving the tokens.
     * @param _value Amount of tokens transferred.
     */
    event Transfer(address indexed _from, address indexed _to, uint256 _value);

    /**
     * @notice Emitted when an approval is made for a spender by an owner.
     * @param _owner The address granting the allowance.
     * @param _spender The address receiving the allowance.
     * @param _value The amount approved.
     */
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);

    /**
     * @notice Returns the name of the token.
     * @return The token name.
     */
    function name() external view returns (string memory);

    /**
     * @notice Returns the symbol of the token.
     * @return The token symbol.
     */
    function symbol() external view returns (string memory);

    /**
     * @notice Returns the number of decimals used for token precision.
     * @return The number of decimals.
     */
    function decimals() external view returns (uint8);

    /**
     * @notice Returns the total supply of tokens.
     * @return The total token supply.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @notice Returns the balance of a specific account.
     * @param _account The address of the account.
     * @return The account balance.
     */
    function balanceOf(address _account) external view returns (uint256);

    /**
     * @notice Returns the remaining number of tokens that a spender is allowed to spend on behalf of an owner.
     * @param _owner The address of the token owner.
     * @param _spender The address of the spender.
     * @return The remaining allowance.
     */
    function allowance(address _owner, address _spender) external view returns (uint256);

    /**
     * @notice Approves a spender to transfer up to a certain amount of tokens on behalf of the caller.
     * @dev Emits an {Approval} event.
     * @param _spender The address approved to spend tokens.
     * @param _value The number of tokens to approve.
     * @return True if the operation succeeded.
     */
    function approve(address _spender, uint256 _value) external returns (bool);

    /**
     * @notice Transfers tokens to another address.
     * @dev Emits a {Transfer} event.
     * @param _to The address to receive the tokens.
     * @param _value The amount of tokens to transfer.
     * @return True if the operation succeeded.
     */
    function transfer(address _to, uint256 _value) external returns (bool);

    /**
     * @notice Transfers tokens on behalf of another account, provided sufficient allowance exists.
     * @dev Emits a {Transfer} event and decreases the spender's allowance.
     * @param _from The address to transfer tokens from.
     * @param _to The address to transfer tokens to.
     * @param _value The amount of tokens to transfer.
     * @return True if the operation succeeded.
     */
    function transferFrom(address _from, address _to, uint256 _value) external returns (bool);

    /**
     * @notice Burns (destroys) a specific amount of tokens from the caller's balance.
     * @dev Emits a {Transfer} event to the zero address.
     * @param _value The amount of tokens to burn.
     */
    function burn(uint256 _value) external;

    /**
     * @notice Burns tokens from another account, deducting from the caller's allowance.
     * @dev Emits a {Transfer} event to the zero address.
     * @param _account The address whose tokens will be burned.
     * @param _value The amount of tokens to burn.
     */
    function burnFrom(address _account, uint256 _value) external;

    /**
     * @notice Returns the current nonce for an owner.
     * @dev This value changes each time a permit is used.
     * @param _owner The address of the owner.
     * @return The current nonce.
     */
    function nonces(address _owner) external view returns (uint256);

    /**
     * @notice Returns the domain separator used in the encoding of the signature for {permit}.
     * @dev This value is unique to a contract and chain ID combination to prevent replay attacks.
     * @return The domain separator.
     */
    function DOMAIN_SEPARATOR() external view returns (bytes32);

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
    ) external;
}
