// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/// @title LibBlob
/// @notice SSTORE2-style library for storing and reading arbitrary data as contract code
/// @dev Deploys contracts whose bytecode is the data, enabling efficient reads via EXTCODECOPY
library LibBlob {
    error DeployFailed();

    /// @notice Writes data to a new contract and returns its address
    /// @param data The data to store
    /// @return blob The address of the deployed blob contract
    function write(bytes memory data) internal returns (address blob) {
        // Deploy contract with initcode that returns the data as runtime code
        // Format: PUSH2 <length> RETURNDATASIZE DUP2 PUSH1 0x0a RETURNDATASIZE CODECOPY RETURN <data>
        bytes memory init = abi.encodePacked(hex"61", uint16(data.length), hex"3d81600a3d39f3", data);
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
