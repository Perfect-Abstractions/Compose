// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

/**
 * @title ERC-6909 Minimal Multi-Token Interface
 * @notice Interface for ERC-6909 multi-token contracts with custom errors.
 */
interface IERC6909 {
    /**
     * @notice Thrown when the sender has insufficient balance.
     */
    error ERC6909InsufficientBalance(address _sender, uint256 _balance, uint256 _needed, uint256 _id);

    /**
     * @notice Thrown when the spender has insufficient allowance.
     */
    error ERC6909InsufficientAllowance(address _spender, uint256 _allowance, uint256 _needed, uint256 _id);

    /**
     * @notice Thrown when the approver address is invalid.
     */
    error ERC6909InvalidApprover(address _approver);

    /**
     * @notice Thrown when the receiver address is invalid.
     */
    error ERC6909InvalidReceiver(address _receiver);

    /**
     * @notice Thrown when the sender address is invalid.
     */
    error ERC6909InvalidSender(address _sender);

    /**
     * @notice Thrown when the spender address is invalid.
     */
    error ERC6909InvalidSpender(address _spender);

    /**
     * @notice Emitted when a transfer occurs.
     */
    event Transfer(
        address _caller, address indexed _sender, address indexed _receiver, uint256 indexed _id, uint256 _amount
    );

    /**
     * @notice Emitted when an operator is set.
     */
    event OperatorSet(address indexed _owner, address indexed _spender, bool _approved);

    /**
     * @notice Emitted when an approval occurs.
     */
    event Approval(address indexed _owner, address indexed _spender, uint256 indexed _id, uint256 _amount);

    /**
     * @notice Owner balance of an id.
     * @param _owner The address of the owner.
     * @param _id The id of the token.
     * @return The balance of the token.
     */
    function balanceOf(address _owner, uint256 _id) external view returns (uint256);

    /**
     * @notice Spender allowance of an id.
     * @param _owner The address of the owner.
     * @param _spender The address of the spender.
     * @param _id The id of the token.
     * @return The allowance of the token.
     */
    function allowance(address _owner, address _spender, uint256 _id) external view returns (uint256);

    /**
     * @notice Checks if a spender is approved by an owner as an operator.
     * @param _owner The address of the owner.
     * @param _spender The address of the spender.
     * @return The approval status.
     */
    function isOperator(address _owner, address _spender) external view returns (bool);

    /**
     * @notice Approves an amount of an id to a spender.
     * @param _spender The address of the spender.
     * @param _id The id of the token.
     * @param _amount The amount of the token.
     * @return Whether the approval succeeded.
     */
    function approve(address _spender, uint256 _id, uint256 _amount) external returns (bool);

    /**
     * @notice Sets or removes a spender as an operator for the caller.
     * @param _spender The address of the spender.
     * @param _approved The approval status.
     * @return Whether the operator update succeeded.
     */
    function setOperator(address _spender, bool _approved) external returns (bool);

    /**
     * @notice Transfers an amount of an id from the caller to a receiver.
     * @param _receiver The address of the receiver.
     * @param _id The id of the token.
     * @param _amount The amount of the token.
     * @return Whether the transfer succeeded.
     */
    function transfer(address _receiver, uint256 _id, uint256 _amount) external returns (bool);

    /**
     * @notice Transfers an amount of an id from a sender to a receiver.
     * @param _sender The address of the sender.
     * @param _receiver The address of the receiver.
     * @param _id The id of the token.
     * @param _amount The amount of the token.
     * @return Whether the transfer succeeded.
     */
    function transferFrom(address _sender, address _receiver, uint256 _id, uint256 _amount) external returns (bool);
}
