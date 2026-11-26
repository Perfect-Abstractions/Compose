// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

/**
 * @dev Minimal interface for reading the vault's asset balance.
 */
interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
}

contract ERC4626DataFacet {
    /**
     * @dev Storage position determined by the keccak256 hash of the diamond storage identifier.
     */
    bytes32 constant ERC4626_STORAGE_POSITION = keccak256("erc4626");

    /**
     * @dev ERC4626-specific storage layout.
     * @custom:storage-location erc8042:erc4626
     */
    struct ERC4626Storage {
        IERC20 asset;
    }

    /**
     * @notice Returns the ERC4626 storage struct from the predefined diamond storage slot.
     * @return s The ERC4626 storage struct reference.
     */
    function getERC4626Storage() internal pure returns (ERC4626Storage storage s) {
        bytes32 position = ERC4626_STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }

    /**
     * @notice Returns the underlying asset of the vault.
     * @return assetTokenAddress The address of the underlying ERC-20 token.
     */
    function asset() external view returns (address assetTokenAddress) {
        ERC4626Storage storage erc4626s = getERC4626Storage();
        return address(erc4626s.asset);
    }

    /**
     * @notice Returns the total underlying assets held by the vault.
     * @return totalManagedAssets The vault's actual asset balance, excluding virtual assets.
     */
    function totalAssets() external view returns (uint256 totalManagedAssets) {
        ERC4626Storage storage erc4626s = getERC4626Storage();
        return erc4626s.asset.balanceOf(address(this));
    }

    /**
     * @notice Exports the function selectors of the ERC4626DataFacet.
     * @return selectors The packed vault data function selectors.
     */
    function exportSelectors() external pure returns (bytes memory) {
        return bytes.concat(this.asset.selector, this.totalAssets.selector);
    }
}
