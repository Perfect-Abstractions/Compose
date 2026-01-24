// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

/**
 * @title ERC-6909 Minimal Multi-Token Interface
 * @notice A complete, dependency-free ERC-6909 implementation using the diamond storage pattern.
 */
contract ERC6909Facet {
    /**
     * @notice Thrown when the sender has insufficient balance.
     */
    error ERC6909InsufficientBalance(address _sender, uint256 _balance, uint256 _needed, uint256 _id);

    /**
     * @notice Thrown when the spender has insufficient allowance.
     */
    error ERC6909InsufficientAllowance(address _spender, uint256 _allowance, uint256 _needed, uint256 _id);

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
     * @dev Storage position determined by the keccak256 hash of the diamond storage identifier.
     */
    bytes32 constant STORAGE_POSITION = keccak256("compose.erc6909");

    /**
     * @custom:storage-location erc8042:compose.erc6909
     */
    struct ERC6909Storage {
        mapping(address owner => mapping(uint256 id => uint256 amount)) balanceOf;
        mapping(address owner => mapping(address spender => mapping(uint256 id => uint256 amount))) allowance;
        mapping(address owner => mapping(address spender => bool)) isOperator;
    }

    /**
     * @notice Returns a pointer to the ERC-6909 storage struct.
     * @dev Uses inline assembly to access the storage slot defined by STORAGE_POSITION.
     * @return s The ERC6909Storage struct in storage.
     */
    function getStorage() internal pure returns (ERC6909Storage storage s) {
        bytes32 position = STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }

    /**
     * @notice Owner balance of an id.
     * @param _owner The address of the owner.
     * @param _id The id of the token.
     * @return The balance of the token.
     */
    function balanceOf(address _owner, uint256 _id) external view returns (uint256) {
        return getStorage().balanceOf[_owner][_id];
    }

    /**
     * @notice Spender allowance of an id.
     * @param _owner The address of the owner.
     * @param _spender The address of the spender.
     * @param _id The id of the token.
     * @return The allowance of the token.
     */
    function allowance(address _owner, address _spender, uint256 _id) external view returns (uint256) {
        return getStorage().allowance[_owner][_spender][_id];
    }

    /**
     * @notice Checks if a spender is approved by an owner as an operator.
     * @param _owner The address of the owner.
     * @param _spender The address of the spender.
     * @return The approval status.
     */
    function isOperator(address _owner, address _spender) external view returns (bool) {
        return getStorage().isOperator[_owner][_spender];
    }

    /**
     * @notice Transfers an amount of an id from the caller to a receiver.
     * @param _receiver The address of the receiver.
     * @param _id The id of the token.
     * @param _amount The amount of the token.
     * @return Whether the transfer succeeded.
     */
    function transfer(address _receiver, uint256 _id, uint256 _amount) external returns (bool) {
        if (_receiver == address(0)) {
            revert ERC6909InvalidReceiver(address(0));
        }

        ERC6909Storage storage s = getStorage();

        uint256 fromBalance = s.balanceOf[msg.sender][_id];

        if (fromBalance < _amount) {
            revert ERC6909InsufficientBalance(msg.sender, fromBalance, _amount, _id);
        }

        unchecked {
            s.balanceOf[msg.sender][_id] = fromBalance - _amount;
        }

        s.balanceOf[_receiver][_id] += _amount;

        emit Transfer(msg.sender, msg.sender, _receiver, _id, _amount);

        return true;
    }

    /**
     * @notice Transfers an amount of an id from a sender to a receiver.
     * @param _sender The address of the sender.
     * @param _receiver The address of the receiver.
     * @param _id The id of the token.
     * @param _amount The amount of the token.
     * @return Whether the transfer succeeded.
     */
    function transferFrom(address _sender, address _receiver, uint256 _id, uint256 _amount) external returns (bool) {
        if (_sender == address(0)) {
            revert ERC6909InvalidSender(address(0));
        }

        if (_receiver == address(0)) {
            revert ERC6909InvalidReceiver(address(0));
        }

        ERC6909Storage storage s = getStorage();

        if (msg.sender != _sender && !s.isOperator[_sender][msg.sender]) {
            uint256 currentAllowance = s.allowance[_sender][msg.sender][_id];
            if (currentAllowance < type(uint256).max) {
                if (currentAllowance < _amount) {
                    revert ERC6909InsufficientAllowance(msg.sender, currentAllowance, _amount, _id);
                }
                unchecked {
                    s.allowance[_sender][msg.sender][_id] = currentAllowance - _amount;
                }
            }
        }

        uint256 fromBalance = s.balanceOf[_sender][_id];
        if (fromBalance < _amount) {
            revert ERC6909InsufficientBalance(_sender, fromBalance, _amount, _id);
        }
        unchecked {
            s.balanceOf[_sender][_id] = fromBalance - _amount;
        }

        s.balanceOf[_receiver][_id] += _amount;

        emit Transfer(msg.sender, _sender, _receiver, _id, _amount);

        return true;
    }

    /**
     * @notice Approves an amount of an id to a spender.
     * @param _spender The address of the spender.
     * @param _id The id of the token.
     * @param _amount The amount of the token.
     * @return Whether the approval succeeded.
     */
    function approve(address _spender, uint256 _id, uint256 _amount) external returns (bool) {
        if (_spender == address(0)) {
            revert ERC6909InvalidSpender(address(0));
        }

        ERC6909Storage storage s = getStorage();

        s.allowance[msg.sender][_spender][_id] = _amount;

        emit Approval(msg.sender, _spender, _id, _amount);

        return true;
    }

    /**
     * @notice Sets or removes a spender as an operator for the caller.
     * @param _spender The address of the spender.
     * @param _approved The approval status.
     * @return Whether the operator update succeeded.
     */
    function setOperator(address _spender, bool _approved) external returns (bool) {
        if (_spender == address(0)) {
            revert ERC6909InvalidSpender(address(0));
        }

        ERC6909Storage storage s = getStorage();

        s.isOperator[msg.sender][_spender] = _approved;

        emit OperatorSet(msg.sender, _spender, _approved);

        return true;
    }
}
