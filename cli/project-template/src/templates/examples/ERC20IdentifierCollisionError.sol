// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

contract ERC20IdentifierCollisionError {
    /**
     * @dev Reuses the ERC20 diamond storage identifier with an incompatible layout.
     */
    bytes32 constant STORAGE_POSITION = keccak256("erc20");

    /**
     * @dev Intentionally collides with the required ERC20 storage layout.
     * @custom:storage-location erc8042:erc20
     */
    struct ERC20Storage {
        bool paused;
        mapping(address owner => uint256 balance) balanceOf;
        uint256 totalSupply;
        mapping(address owner => mapping(address spender => uint256 allowance)) allowance;
    }

    /**
     * @notice Returns the intentionally incompatible ERC20 storage struct.
     * @return s The ERC20 storage struct reference.
     */
    function getStorage() internal pure returns (ERC20Storage storage s) {
        bytes32 position = STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }

    /**
     * @notice Unique probe function used to keep selector validation clean.
     * @return True when the incompatible layout's paused flag is set.
     */
    function identifierCollisionProbe() external view returns (bool) {
        return getStorage().paused;
    }

    /**
     * @notice Exports a non-colliding selector so identifier validation can surface.
     * @return selectors The exported function selectors.
     */
    function exportSelectors() external pure returns (bytes memory) {
        return bytes.concat(this.identifierCollisionProbe.selector);
    }
}
