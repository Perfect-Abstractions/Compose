// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/// @title LibBlob
/// @notice SSTORE2-style library for storing and reading arbitrary data as contract code
/// @dev Deploys contracts whose bytecode is the data, enabling efficient reads via EXTCODECOPY
library LibBlob {
    error DeployFailed();
    error BlobTooLarge(uint256 requested, uint256 maxAllowed);

    uint256 internal constant MAX_BLOB_SIZE = 24_576;

    /// @notice Writes data to a new contract and returns its address
    /// @param data The data to store
    /// @return blob The address of the deployed blob contract
    function write(bytes memory data) internal returns (address blob) {
        uint256 length = data.length;
        if (length > MAX_BLOB_SIZE) {
            revert BlobTooLarge(length, MAX_BLOB_SIZE);
        }
        // Deploy contract with initcode that returns the data as runtime code
        // Opcodes: PUSH2 (0x61) <length>, RETURNDATASIZE (0x3d), DUP2 (0x81), 
        //          PUSH1 0x0a (0x600a), RETURNDATASIZE (0x3d), CODECOPY (0x39), RETURN (0xf3)
        // This creates a contract whose code is exactly the input data
        bytes memory init = abi.encodePacked(hex"61", uint16(length), hex"3d81600a3d39f3", data);
        assembly ("memory-safe") {
            blob := create(0, add(init, 0x20), mload(init))
        }
        if (blob == address(0)) {
            revert DeployFailed();
        }
    }

    /// @notice Reads all data from a blob contract
    /// @param blob The address of the blob contract
    /// @return data The stored data
    function read(address blob) internal view returns (bytes memory data) {
        uint256 size;
        assembly ("memory-safe") {
            size := extcodesize(blob)
        }
        data = new bytes(size);
        assembly ("memory-safe") {
            extcodecopy(blob, add(data, 0x20), 0, size)
        }
    }
}
