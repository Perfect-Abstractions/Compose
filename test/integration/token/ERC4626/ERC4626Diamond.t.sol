// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC20ApproveFacet} from "src/token/ERC20/Approve/ERC20ApproveFacet.sol";
import {ERC20DataFacet} from "src/token/ERC20/Data/ERC20DataFacet.sol";
import {ERC4626ConvertToAssetsFacet} from "src/token/ERC4626/ConvertToAssets/ERC4626ConvertToAssetsFacet.sol";
import {ERC4626ConvertToSharesFacet} from "src/token/ERC4626/ConvertToShares/ERC4626ConvertToSharesFacet.sol";
import {ERC4626DataFacet} from "src/token/ERC4626/Data/ERC4626DataFacet.sol";
import {ERC4626DepositFacet} from "src/token/ERC4626/Deposit/ERC4626DepositFacet.sol";
import {ERC4626MintFacet} from "src/token/ERC4626/Mint/ERC4626MintFacet.sol";
import {ERC4626RedeemFacet} from "src/token/ERC4626/Redeem/ERC4626RedeemFacet.sol";
import {ERC4626WithdrawFacet} from "src/token/ERC4626/Withdraw/ERC4626WithdrawFacet.sol";
import {ERC4626_Base_Test} from "test/unit/token/ERC4626/ERC4626Base.t.sol";
import {DiamondProxyHarness} from "test/utils/harnesses/diamond/DiamondProxyHarness.sol";
import {ERC20StorageUtils} from "test/utils/storage/ERC20StorageUtils.sol";

/**
 * @dev BTT spec: test/trees/ERC4626.tree (Diamond integration).
 */
contract ERC4626Diamond_Integration_Test is ERC4626_Base_Test {
    using ERC20StorageUtils for address;

    address internal vault;

    function setUp() public override {
        super.setUp();
        address[] memory facets = new address[](9);
        facets[0] = address(new ERC4626DataFacet());
        facets[1] = address(new ERC4626ConvertToSharesFacet());
        facets[2] = address(new ERC4626ConvertToAssetsFacet());
        facets[3] = address(new ERC4626DepositFacet());
        facets[4] = address(new ERC4626MintFacet());
        facets[5] = address(new ERC4626WithdrawFacet());
        facets[6] = address(new ERC4626RedeemFacet());
        facets[7] = address(new ERC20DataFacet());
        facets[8] = address(new ERC20ApproveFacet());

        vault = address(new DiamondProxyHarness(facets, users.admin));
        vm.label(vault, "ERC4626Diamond");
        configureVault(vault);
    }

    function testFuzz_ShouldDepositAndRedeemAcrossFacets(uint64 input) external {
        uint256 assets = bound(input, 1, type(uint64).max);
        ERC4626DataFacet data = ERC4626DataFacet(vault);
        ERC20DataFacet shares = ERC20DataFacet(vault);
        ERC4626DepositFacet deposit = ERC4626DepositFacet(vault);
        ERC4626RedeemFacet redeem = ERC4626RedeemFacet(vault);

        assertEq(data.asset(), address(assetToken));
        assertEq(data.totalAssets(), 0);
        address(assetToken).mint(users.alice, assets);
        assetToken.approve(vault, assets);

        uint256 expectedShares = ERC4626ConvertToSharesFacet(vault).convertToShares(assets);
        assertEq(expectedShares, assets * 10);
        assertEq(deposit.previewDeposit(assets), expectedShares);
        assertEq(deposit.deposit(assets, users.alice), expectedShares);
        assertEq(data.totalAssets(), assets);
        assertEq(shares.balanceOf(users.alice), expectedShares);
        assertEq(shares.totalSupply(), expectedShares);
        assertEq(redeem.maxRedeem(users.alice), expectedShares);
        assertEq(ERC4626ConvertToAssetsFacet(vault).convertToAssets(expectedShares), assets);
        assertEq(redeem.previewRedeem(expectedShares), assets);

        assertEq(redeem.redeem(expectedShares, users.receiver, users.alice), assets);
        assertEq(assetToken.balanceOf(users.receiver), assets);
        assertEq(data.totalAssets(), 0);
        assertEq(shares.balanceOf(users.alice), 0);
        assertEq(shares.totalSupply(), 0);
    }

    function test_ShouldMintAndWithdrawWithShareAllowanceAcrossFacets() external {
        ERC4626MintFacet mint = ERC4626MintFacet(vault);
        ERC4626WithdrawFacet withdraw = ERC4626WithdrawFacet(vault);
        ERC20DataFacet shares = ERC20DataFacet(vault);
        address(assetToken).mint(users.alice, 10);
        assetToken.approve(vault, 10);
        assetToken.observeSupply(vault);

        assertEq(mint.previewMint(100), 10);
        assertEq(mint.mint(100, users.alice), 10);
        assertEq(assetToken.observedSupply(), 0, "pull before minting shares");
        assertEq(withdraw.maxWithdraw(users.alice), 10);
        assertEq(withdraw.previewWithdraw(4), 40);
        ERC20ApproveFacet(vault).approve(users.bob, 50);
        setMsgSender(users.bob);

        assertEq(withdraw.withdraw(4, users.receiver, users.alice), 40);
        assertEq(assetToken.observedSupply(), 60, "burn before paying assets");
        assertEq(shares.balanceOf(users.alice), 60);
        assertEq(shares.totalSupply(), 60);
        assertEq(shares.allowance(users.alice, users.bob), 10);
        assertEq(assetToken.balanceOf(users.receiver), 4);
        assertEq(ERC4626DataFacet(vault).totalAssets(), 6);
    }

    function test_ShouldCountDirectAssetTransfersWithoutMintingShares() external {
        ERC4626DepositFacet deposit = ERC4626DepositFacet(vault);
        address(assetToken).mint(users.alice, 20);
        assetToken.approve(vault, 10);
        assertEq(deposit.deposit(10, users.alice), 100);

        assetToken.transfer(vault, 10);

        assertEq(ERC4626DataFacet(vault).totalAssets(), 20);
        assertEq(ERC20DataFacet(vault).totalSupply(), 100);
        assertEq(ERC20DataFacet(vault).balanceOf(users.alice), 100);
        assertEq(ERC4626ConvertToSharesFacet(vault).convertToShares(21), 110);
        assertEq(deposit.previewDeposit(21), 110);
        assertEq(ERC4626ConvertToAssetsFacet(vault).convertToAssets(110), 21);
        assertEq(ERC4626RedeemFacet(vault).previewRedeem(110), 21);
    }

    function test_ShouldMintQuotedShares_WhenAssetsArriveBeforeFirstDeposit() external {
        ERC4626DataFacet data = ERC4626DataFacet(vault);
        ERC20DataFacet shares = ERC20DataFacet(vault);
        ERC4626DepositFacet deposit = ERC4626DepositFacet(vault);

        address(assetToken).mint(users.bob, 12);
        setMsgSender(users.bob);
        assetToken.transfer(vault, 12);

        assertEq(data.totalAssets(), 12);
        assertEq(shares.totalSupply(), 0);

        address(assetToken).mint(users.alice, 7);
        setMsgSender(users.alice);
        assetToken.approve(vault, 7);

        uint256 quotedShares = deposit.previewDeposit(7);
        assertEq(quotedShares, 5);
        assertEq(deposit.deposit(7, users.alice), quotedShares);
        assertEq(shares.balanceOf(users.alice), quotedShares);
        assertEq(shares.balanceOf(users.bob), 0);
        assertEq(shares.totalSupply(), quotedShares);
        assertEq(data.totalAssets(), 19);
    }

    function test_ShouldExecuteQuotedAmounts_WhenTwoUsersUseFundedVault() external {
        ERC4626DepositFacet deposit = ERC4626DepositFacet(vault);
        ERC4626MintFacet mint = ERC4626MintFacet(vault);
        ERC4626WithdrawFacet withdraw = ERC4626WithdrawFacet(vault);
        ERC4626RedeemFacet redeem = ERC4626RedeemFacet(vault);
        ERC4626ConvertToSharesFacet convert = ERC4626ConvertToSharesFacet(vault);

        address(assetToken).mint(users.alice, 10);
        assetToken.approve(vault, 10);
        assertEq(deposit.deposit(10, users.alice), 100);

        address(assetToken).mint(users.charlee, 6);
        setMsgSender(users.charlee);
        assetToken.transfer(vault, 6);

        address(assetToken).mint(users.bob, 6);
        setMsgSender(users.bob);
        assetToken.approve(vault, 6);
        assetToken.observeSupply(vault);
        assetToken.observeQuote(17);

        uint256 beforeDepositQuote = convert.convertToShares(17);
        assertEq(deposit.previewDeposit(4), 25);
        assertEq(deposit.deposit(4, users.bob), 25);
        assertEq(assetToken.observedQuoteBeforeTransfer(), beforeDepositQuote, "pre-deposit quote");

        assertEq(mint.previewMint(10), 2);
        assertEq(mint.mint(10, users.bob), 2);
        assertEq(assetToken.balanceOf(users.bob), 0, "assets paid for deposit and mint");

        setMsgSender(users.alice);
        assertEq(withdraw.previewWithdraw(3), 19);
        assertEq(withdraw.withdraw(3, users.receiver, users.alice), 19);
        assertEq(assetToken.observedQuoteAfterTransfer(), convert.convertToShares(17), "post-withdraw quote");

        setMsgSender(users.bob);
        assertEq(redeem.previewRedeem(17), 2);
        assertEq(redeem.redeem(17, users.receiver, users.bob), 2);

        ERC20DataFacet shares = ERC20DataFacet(vault);
        assertEq(shares.balanceOf(users.alice), 81);
        assertEq(shares.balanceOf(users.bob), 18);
        assertEq(shares.totalSupply(), 99);
        assertEq(assetToken.balanceOf(users.receiver), 5);
        assertEq(ERC4626DataFacet(vault).totalAssets(), 17);
    }

    function testFuzz_ShouldNotGainAssets_WhenDepositingAndImmediatelyRedeeming(uint64 addedAssets, uint64 input)
        external
    {
        uint256 donation = bound(addedAssets, 1, 100);
        uint256 assets = bound(input, 20, 1000);
        ERC4626DepositFacet deposit = ERC4626DepositFacet(vault);
        ERC4626RedeemFacet redeem = ERC4626RedeemFacet(vault);
        ERC4626ConvertToSharesFacet toShares = ERC4626ConvertToSharesFacet(vault);
        ERC4626ConvertToAssetsFacet toAssets = ERC4626ConvertToAssetsFacet(vault);

        address(assetToken).mint(users.alice, 10 + donation);
        assetToken.approve(vault, 10);
        assertEq(deposit.deposit(10, users.alice), 100);
        assetToken.transfer(vault, donation);

        uint256 quotedShares = toShares.convertToShares(assets);
        uint256 quotedAssets = toAssets.convertToAssets(quotedShares);

        address(assetToken).mint(users.bob, assets);
        setMsgSender(users.bob);
        assertEq(toShares.convertToShares(assets), quotedShares, "caller-independent shares quote");
        assertEq(toAssets.convertToAssets(quotedShares), quotedAssets, "caller-independent assets quote");
        assetToken.approve(vault, assets);
        assertEq(deposit.deposit(assets, users.bob), quotedShares);

        uint256 expected = redeem.previewRedeem(quotedShares);
        uint256 received = redeem.redeem(quotedShares, users.bob, users.bob);
        assertEq(received, expected);
        assertLe(received, assets, "round trip cannot gain assets");
        assertEq(assetToken.balanceOf(users.bob), received);
        assertEq(ERC20DataFacet(vault).balanceOf(users.bob), 0);
        assertEq(ERC20DataFacet(vault).totalSupply(), 100);
    }
}
