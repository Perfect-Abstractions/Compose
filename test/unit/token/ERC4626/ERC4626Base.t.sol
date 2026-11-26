// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {Base_Test} from "test/Base.t.sol";
import {ERC4626AssetMock} from "test/utils/mocks/ERC4626AssetMock.sol";
import {ERC20StorageUtils} from "test/utils/storage/ERC20StorageUtils.sol";

abstract contract ERC4626_Base_Test is Base_Test {
    using ERC20StorageUtils for address;

    bytes32 internal constant ERC4626_STORAGE_POSITION = keccak256("erc4626");
    ERC4626AssetMock internal assetToken;

    function setUp() public virtual override {
        super.setUp();
        assetToken = new ERC4626AssetMock();
        vm.label(address(assetToken), "UnderlyingAsset");
    }

    function configureVault(address vault) internal {
        vm.store(vault, ERC4626_STORAGE_POSITION, bytes32(uint256(uint160(address(assetToken)))));
    }

    function seedVault(address vault, uint256 assets, uint256 shares) internal {
        address(assetToken).setBalance(vault, assets);
        vault.setTotalSupply(shares);
    }
}
