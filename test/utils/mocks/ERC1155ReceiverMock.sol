// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {IERC1155Receiver} from "src/interfaces/IERC1155Receiver.sol";

/**
 * @title ERC1155ReceiverMock
 * @notice Mock implementation of IERC1155Receiver for testing.
 * @dev Supports configurable return values, revert types (message, no message, custom error, panic),
 *      and emits Received/BatchReceived so callers can assert the data parameter is forwarded.
 */
contract ERC1155ReceiverMock is IERC1155Receiver {
    enum RevertType {
        None,
        RevertWithoutMessage,
        RevertWithMessage,
        RevertWithCustomError,
        Panic
    }

    error CustomError(bytes4);

    event Received(address operator, address from, uint256 id, uint256 value, bytes data, uint256 gas);
    event BatchReceived(address operator, address from, uint256[] ids, uint256[] values, bytes data, uint256 gas);

    bytes4 private immutable _singleRetval;
    bytes4 private immutable _batchRetval;
    RevertType private immutable _revertType;

    constructor(bytes4 singleRetval, bytes4 batchRetval, RevertType revertType) {
        _singleRetval = singleRetval;
        _batchRetval = batchRetval;
        _revertType = revertType;
    }

    function onERC1155Received(address operator, address from, uint256 id, uint256 value, bytes calldata data)
        external
        override
        returns (bytes4)
    {
        if (_revertType == RevertType.RevertWithoutMessage) {
            revert();
        }
        if (_revertType == RevertType.RevertWithMessage) {
            revert("ERC1155ReceiverMock: reverting on receive");
        }
        if (_revertType == RevertType.RevertWithCustomError) {
            revert CustomError(_singleRetval);
        }
        if (_revertType == RevertType.Panic) {
            uint256 x = 0;
            x = 1 / x; // division by zero panics
        }
        emit Received(operator, from, id, value, data, gasleft());
        return _singleRetval;
    }

    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external override returns (bytes4) {
        if (_revertType == RevertType.RevertWithoutMessage) {
            revert();
        }
        if (_revertType == RevertType.RevertWithMessage) {
            revert("ERC1155ReceiverMock: reverting on batch receive");
        }
        if (_revertType == RevertType.RevertWithCustomError) {
            revert CustomError(_batchRetval);
        }
        if (_revertType == RevertType.Panic) {
            uint256 x = 0;
            x = 1 / x; // division by zero panics
        }
        emit BatchReceived(operator, from, ids, values, data, gasleft());
        return _batchRetval;
    }
}
