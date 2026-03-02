// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

/**
 * @title OwnerDataFacet
 */
contract OwnerDataFacet {
    /**
     * @notice Storage position determined by the keccak256 hash of the diamond storage identifier.
     */
    bytes32 constant STORAGE_POSITION = keccak256("erc173.owner");

    /**
     * @custom:storage-location erc8042:erc173.owner
     */
    struct OwnerStorage {
        address owner;
    }

    /**
     * @notice Returns the owner storage struct.
     * @return s The owner storage struct.
     */
    function getStorage() internal pure returns (OwnerStorage storage s) {
        bytes32 position = STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }

    /**
     * @notice Get the address of the owner
     * @return The address of the owner.
     */
    function owner() external view returns (address) {
        return getStorage().owner;
    }
}
