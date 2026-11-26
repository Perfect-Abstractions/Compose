// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC4626_Base_Test} from "test/unit/token/ERC4626/ERC4626Base.t.sol";
import {ERC4626AssetMock} from "test/utils/mocks/ERC4626AssetMock.sol";
import {ERC20StorageUtils} from "test/utils/storage/ERC20StorageUtils.sol";

abstract contract ActionBehavior is ERC4626_Base_Test {
    using ERC20StorageUtils for address;

    bytes4 internal constant INVALID_RECEIVER = bytes4(keccak256("ERC20InvalidReceiver(address)"));
    bytes4 internal constant INVALID_SENDER = bytes4(keccak256("ERC20InvalidSender(address)"));
    bytes4 internal constant INSUFFICIENT_SHARES = bytes4(keccak256("ERC4626InsufficientShares(uint256,uint256)"));
    bytes4 internal constant INSUFFICIENT_ASSETS = bytes4(keccak256("ERC4626InsufficientAssets(uint256,uint256)"));
    bytes4 internal constant INSUFFICIENT_ALLOWANCE =
        bytes4(keccak256("ERC20InsufficientAllowance(address,uint256,uint256)"));
    bytes4 internal constant TRANSFER_FAILED =
        bytes4(keccak256("TransferFailed(address,address,address,uint256,bytes)"));

    event Transfer(address indexed from, address indexed to, uint256 shares);
    event Deposit(address indexed sender, address indexed owner, uint256 assets, uint256 shares);
    event Withdraw(
        address indexed sender, address indexed receiver, address indexed owner, uint256 assets, uint256 shares
    );

    function vault() internal view virtual returns (address);
    function quote(uint256 amount) internal view virtual returns (uint256);
    function limit(address owner) internal view virtual returns (uint256);
    function exactShares() internal pure virtual returns (bool);

    function expectZeroQuoteRevert(bool assets) internal {
        vm.expectRevert(abi.encodeWithSelector(assets ? INSUFFICIENT_ASSETS : INSUFFICIENT_SHARES, 0, 1));
    }

    function checkQuote(uint64 amount, uint64 assets, uint64 shares, bool assetsToShares, bool roundUp) internal {
        seedVault(vault(), assets, shares);
        uint256 assetTotal = uint256(assets) + 1;
        uint256 shareTotal = uint256(shares) + 10;
        uint256 product = uint256(amount) * (assetsToShares ? shareTotal : assetTotal);
        uint256 denominator = assetsToShares ? assetTotal : shareTotal;
        uint256 expected = roundUp ? (product + denominator - 1) / denominator : product / denominator;
        assertEq(quote(amount), expected, "preview rounding");
    }
}

/**
 * @dev BTT spec: test/trees/ERC4626.tree (Deposit and Mint).
 */
abstract contract EntryBehavior is ActionBehavior {
    using ERC20StorageUtils for address;

    function enter(uint256 amount, address receiver) internal virtual returns (uint256);

    function test_ShouldReturnUnlimitedEntryLimit() external view {
        assertEq(limit(users.receiver), type(uint256).max);
    }

    function testFuzz_ShouldQuoteEntryWithVirtualOffsets(uint64 amount, uint64 assets, uint64 shares) external {
        bool sharesIn = exactShares();
        checkQuote(amount, assets, shares, !sharesIn, sharesIn);
    }

    function test_RevertWhen_ReceiverIsZero() external {
        vm.expectRevert(abi.encodeWithSelector(INVALID_RECEIVER, address(0)));
        enter(10, address(0));
    }

    function test_RevertWhen_EntryQuoteIsZero() external {
        assertEq(quote(0), 0);
        expectZeroQuoteRevert(exactShares());
        enter(0, users.receiver);
    }

    function testFuzz_ShouldMintSharesAndEmitEvents(uint64 amount) external {
        checkSuccessfulEntry(bound(amount, 1, type(uint64).max));
    }

    function test_ShouldAcceptAssetWithNoTransferReturnData() external {
        assetToken.setTransferResult(ERC4626AssetMock.TransferResult.NoData);
        checkSuccessfulEntry(11);
    }

    function test_RevertWhen_AssetTransferReturnsFalse() external {
        checkFailedEntry(ERC4626AssetMock.TransferResult.False);
    }

    function test_RevertWhen_AssetTransferReverts() external {
        checkFailedEntry(ERC4626AssetMock.TransferResult.Revert);
    }

    function test_RevertWhen_AssetTransferReturnsMalformedData() external {
        checkFailedEntry(ERC4626AssetMock.TransferResult.Malformed);
    }

    function checkSuccessfulEntry(uint256 amount) internal {
        uint256 result = quote(amount);
        uint256 assets = exactShares() ? result : amount;
        uint256 shares = exactShares() ? amount : result;
        address target = vault();
        address(assetToken).mint(users.alice, assets);
        assetToken.approve(target, assets);

        vm.expectEmit(true, true, false, true, target);
        emit Transfer(address(0), users.receiver, shares);
        vm.expectEmit(true, true, false, true, target);
        emit Deposit(users.alice, users.receiver, assets, shares);

        assertEq(enter(amount, users.receiver), result, "quote matches execution");
        assertEq(target.balanceOf(users.receiver), shares, "receiver shares");
        assertEq(target.totalSupply(), shares, "share supply");
        assertEq(assetToken.balanceOf(target), assets, "vault assets");
        assertEq(assetToken.balanceOf(users.alice), 0, "payer assets");
        assertEq(assetToken.allowance(users.alice, target), 0, "asset allowance");
    }

    function checkFailedEntry(ERC4626AssetMock.TransferResult result) internal {
        address target = vault();
        uint256 amount = 11;
        uint256 assets = exactShares() ? quote(amount) : amount;
        address(assetToken).mint(users.alice, assets);
        assetToken.approve(target, assets);
        assetToken.setTransferResult(result);

        if (result == ERC4626AssetMock.TransferResult.Malformed && !exactShares()) {
            vm.expectRevert();
        } else {
            vm.expectPartialRevert(TRANSFER_FAILED);
        }
        enter(amount, users.receiver);

        assertEq(assetToken.balanceOf(target), 0, "vault assets");
        assertEq(assetToken.balanceOf(users.alice), assets, "payer assets");
        assertEq(assetToken.allowance(users.alice, target), assets, "asset allowance");
        assertEq(target.balanceOf(users.receiver), 0, "receiver shares");
        assertEq(target.totalSupply(), 0, "share supply");
    }
}

/**
 * @dev BTT spec: test/trees/ERC4626.tree (Withdraw and Redeem).
 */
abstract contract ExitBehavior is ActionBehavior {
    using ERC20StorageUtils for address;

    function leave(uint256 amount, address receiver, address owner) internal virtual returns (uint256);

    function testFuzz_ShouldQuoteExitWithVirtualOffsets(uint64 amount, uint64 assets, uint64 shares) external {
        bool sharesIn = exactShares();
        checkQuote(amount, assets, shares, !sharesIn, !sharesIn);
    }

    function testFuzz_ShouldReturnOwnerLimit(uint64 actualAssets, uint64 ownerShares, uint64 otherShares) external {
        uint256 supply = uint256(ownerShares) + otherShares;
        address target = vault();
        seedVault(target, actualAssets, supply);
        target.setBalance(users.alice, ownerShares);
        target.setBalance(users.bob, otherShares);
        uint256 expected =
            exactShares() ? ownerShares : uint256(ownerShares) * (uint256(actualAssets) + 1) / (supply + 10);
        assertEq(limit(users.alice), expected);
    }

    function test_RevertWhen_ExitExceedsLimit() external {
        seedExit();
        uint256 maximum = limit(users.alice);
        uint256 amount = maximum + 1;
        bytes4 errorSelector = exactShares() ? INSUFFICIENT_SHARES : INSUFFICIENT_ASSETS;
        vm.expectRevert(abi.encodeWithSelector(errorSelector, maximum, amount));
        leave(amount, users.receiver, users.alice);
    }

    function test_RevertWhen_ReceiverIsZero() external {
        vm.expectRevert(abi.encodeWithSelector(INVALID_RECEIVER, address(0)));
        leave(1, address(0), users.alice);
    }

    function test_RevertWhen_OwnerIsZero() external {
        bytes4 errorSelector = exactShares() ? INVALID_SENDER : INVALID_RECEIVER;
        vm.expectRevert(abi.encodeWithSelector(errorSelector, address(0)));
        leave(1, users.receiver, address(0));
    }

    function test_RevertWhen_ExitQuoteIsZero() external {
        seedExit();
        assertEq(quote(0), 0);
        expectZeroQuoteRevert(exactShares());
        leave(0, users.receiver, users.alice);
    }

    function testFuzz_ShouldBurnSharesAndEmitEvents_WhenOwnerExits(uint64 amount) external {
        seedExit();
        uint256 maximum = limit(users.alice);
        uint256 minimum = exactShares() ? 10 : 1;
        checkSuccessfulExit(bound(amount, minimum, maximum), users.alice, 0, 0);
    }

    function test_ShouldAllowExactMaximum() external {
        seedExit();
        checkSuccessfulExit(limit(users.alice), users.alice, 0, 0);
        assertEq(limit(users.alice), 0);
    }

    function test_ShouldSpendFiniteShareAllowance() external {
        seedExit();
        uint256 shares = exactShares() ? 11 : quote(11);
        checkSuccessfulExit(11, users.bob, shares + 1, 1);
    }

    function test_ShouldPreserveUnlimitedShareAllowance() external {
        seedExit();
        checkSuccessfulExit(11, users.bob, type(uint256).max, type(uint256).max);
    }

    function test_RevertWhen_ShareAllowanceIsInsufficient() external {
        seedExit();
        uint256 shares = exactShares() ? 11 : quote(11);
        vault().setAllowance(users.alice, users.bob, shares - 1);
        setMsgSender(users.bob);

        vm.expectRevert(abi.encodeWithSelector(INSUFFICIENT_ALLOWANCE, users.bob, shares - 1, shares));
        leave(11, users.receiver, users.alice);
    }

    function test_ShouldAcceptAssetWithNoTransferReturnData() external {
        seedExit();
        assetToken.setTransferResult(ERC4626AssetMock.TransferResult.NoData);
        checkSuccessfulExit(11, users.alice, 0, 0);
    }

    function test_RevertWhen_AssetTransferReturnsFalse() external {
        checkFailedExit(ERC4626AssetMock.TransferResult.False);
    }

    function test_RevertWhen_AssetTransferReverts() external {
        checkFailedExit(ERC4626AssetMock.TransferResult.Revert);
    }

    function test_RevertWhen_AssetTransferReturnsMalformedData() external {
        checkFailedExit(ERC4626AssetMock.TransferResult.Malformed);
    }

    function seedExit() internal {
        seedVault(vault(), 100, 1000);
        vault().setBalance(users.alice, 1000);
    }

    function checkSuccessfulExit(uint256 amount, address caller, uint256 allowance, uint256 remaining) internal {
        address target = vault();
        uint256 result = quote(amount);
        uint256 assets = exactShares() ? result : amount;
        uint256 shares = exactShares() ? amount : result;
        target.setAllowance(users.alice, caller, allowance);
        setMsgSender(caller);

        vm.expectEmit(true, true, false, true, target);
        emit Transfer(users.alice, address(0), shares);
        vm.expectEmit(true, true, true, true, target);
        emit Withdraw(caller, users.receiver, users.alice, assets, shares);

        assertEq(leave(amount, users.receiver, users.alice), result, "quote matches execution");
        assertEq(target.balanceOf(users.alice), 1000 - shares, "owner share balance");
        assertEq(target.totalSupply(), 1000 - shares, "share supply");
        assertEq(target.allowance(users.alice, caller), remaining, "share allowance");
        assertEq(assetToken.balanceOf(target), 100 - assets, "vault assets");
        assertEq(assetToken.balanceOf(users.receiver), assets, "receiver assets");
    }

    function checkFailedExit(ERC4626AssetMock.TransferResult result) internal {
        seedExit();
        address target = vault();
        uint256 shares = exactShares() ? 11 : quote(11);
        target.setAllowance(users.alice, users.bob, shares);
        assetToken.setTransferResult(result);
        setMsgSender(users.bob);

        vm.expectPartialRevert(TRANSFER_FAILED);
        leave(11, users.receiver, users.alice);

        assertEq(target.balanceOf(users.alice), 1000, "owner share balance");
        assertEq(target.totalSupply(), 1000, "share supply");
        assertEq(target.allowance(users.alice, users.bob), shares, "share allowance");
        assertEq(assetToken.balanceOf(target), 100, "vault assets");
        assertEq(assetToken.balanceOf(users.receiver), 0, "receiver assets");
    }
}
