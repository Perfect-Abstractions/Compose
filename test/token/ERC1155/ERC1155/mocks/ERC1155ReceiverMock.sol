// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {IERC1155Receiver} from "../../../../../src/interfaces/IERC1155Receiver.sol";

/**
 * @title ERC1155ReceiverMock
 * @notice Mock implementation of IERC1155Receiver for testing transfer acceptance/rejection
 * @dev Supports configurable return values and error conditions to test various scenarios
 */
contract ERC1155ReceiverMock is IERC1155Receiver {
    enum RevertType {
        None,
        RevertWithoutMessage,
        RevertWithMessage,
        RevertWithCustomError,
        Panic
    }

    bytes4 private immutable _recRetval;
    bytes4 private immutable _batRetval;
    RevertType private immutable _error;

    event Received(address operator, address from, uint256 id, uint256 value, bytes data, uint256 gas);
    event BatchReceived(address operator, address from, uint256[] ids, uint256[] values, bytes data, uint256 gas);

    error CustomError(bytes4);

    constructor(bytes4 recRetval, bytes4 batRetval, RevertType error) {
        _recRetval = recRetval;
        _batRetval = batRetval;
        _error = error;
    }

    function onERC1155Received(address operator, address from, uint256 id, uint256 value, bytes calldata data)
        external
        override
        returns (bytes4)
    {
        if (_error == RevertType.RevertWithoutMessage) {
            revert();
        } else if (_error == RevertType.RevertWithMessage) {
            revert("ERC1155ReceiverMock: reverting on receive");
        } else if (_error == RevertType.RevertWithCustomError) {
            revert CustomError(_recRetval);
        } else if (_error == RevertType.Panic) {
            uint256 a = uint256(0) / uint256(0);
            a;
        }

        emit Received(operator, from, id, value, data, gasleft());
        return _recRetval;
    }

    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external override returns (bytes4) {
        if (_error == RevertType.RevertWithoutMessage) {
            revert();
        } else if (_error == RevertType.RevertWithMessage) {
            revert("ERC1155ReceiverMock: reverting on batch receive");
        } else if (_error == RevertType.RevertWithCustomError) {
            revert CustomError(_batRetval);
        } else if (_error == RevertType.Panic) {
            uint256 a = uint256(0) / uint256(0);
            a;
        }

        emit BatchReceived(operator, from, ids, values, data, gasleft());
        return _batRetval;
    }
}
