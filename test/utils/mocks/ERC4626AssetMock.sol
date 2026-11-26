// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC20DataFacet} from "src/token/ERC20/Data/ERC20DataFacet.sol";
import {ERC4626ConvertToSharesFacet} from "src/token/ERC4626/ConvertToShares/ERC4626ConvertToSharesFacet.sol";
import "src/token/ERC20/Approve/ERC20ApproveMod.sol" as ERC20ApproveMod;
import "src/token/ERC20/Transfer/ERC20TransferMod.sol" as ERC20TransferMod;

contract ERC4626AssetMock is ERC20DataFacet {
    enum TransferResult {
        Standard,
        NoData,
        False,
        Revert,
        Malformed
    }

    error TransferBlocked();

    TransferResult internal result;
    address internal observedVault;
    uint256 public observedSupply;
    uint256 internal quoteAssets;
    uint256 public observedQuoteBeforeTransfer;
    uint256 public observedQuoteAfterTransfer;

    function setTransferResult(TransferResult value) external {
        result = value;
    }

    function observeSupply(address vault) external {
        observedVault = vault;
        observedSupply = type(uint256).max;
    }

    function observeQuote(uint256 assets) external {
        quoteAssets = assets;
        observedQuoteBeforeTransfer = type(uint256).max;
        observedQuoteAfterTransfer = type(uint256).max;
    }

    function approve(address spender, uint256 assets) external returns (bool) {
        return ERC20ApproveMod.approve(spender, assets);
    }

    function transfer(address receiver, uint256 assets) external returns (bool) {
        recordBeforeTransfer();
        ERC20TransferMod.transfer(receiver, assets);
        recordAfterTransfer();
        return transferResult();
    }

    function transferFrom(address holder, address receiver, uint256 assets) external returns (bool) {
        recordBeforeTransfer();
        ERC20TransferMod.transferFrom(holder, receiver, assets);
        recordAfterTransfer();
        return transferResult();
    }

    function recordBeforeTransfer() internal {
        if (observedVault == address(0)) return;
        observedSupply = ERC20DataFacet(observedVault).totalSupply();
        if (quoteAssets != 0) {
            observedQuoteBeforeTransfer = ERC4626ConvertToSharesFacet(observedVault).convertToShares(quoteAssets);
        }
    }

    function recordAfterTransfer() internal {
        if (observedVault != address(0) && quoteAssets != 0) {
            observedQuoteAfterTransfer = ERC4626ConvertToSharesFacet(observedVault).convertToShares(quoteAssets);
        }
    }

    function transferResult() internal view returns (bool) {
        if (result == TransferResult.Revert) revert TransferBlocked();
        if (result == TransferResult.NoData) {
            assembly ("memory-safe") {
                return(0, 0)
            }
        }
        if (result == TransferResult.Malformed) {
            assembly ("memory-safe") {
                mstore(0, 1)
                return(31, 1)
            }
        }
        return result != TransferResult.False;
    }
}
