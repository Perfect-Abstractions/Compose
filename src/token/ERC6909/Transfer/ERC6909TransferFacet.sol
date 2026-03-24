// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

contract ERC6909TransferFacet {
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
     * @notice Emitted when a transfer occurs.
     */
    event Transfer(
        address _caller, address indexed _sender, address indexed _receiver, uint256 indexed _id, uint256 _amount
    );

    /**
     * @dev Storage position determined by the keccak256 hash of the diamond storage identifier.
     */
    bytes32 constant STORAGE_POSITION = keccak256("erc6909");

    /**
     * @custom:storage-location erc8042:erc6909
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
     * @notice Exports the function selectors of the ERC6909TransferFacet
     * @dev This function is use as a selector discovery mechanism for diamonds
     * @return selectors The exported function selectors of the ERC6909TransferFacet
     */
    function exportSelectors() external pure returns (bytes memory) {
        return bytes.concat(this.transfer.selector, this.transferFrom.selector);
    }
}
