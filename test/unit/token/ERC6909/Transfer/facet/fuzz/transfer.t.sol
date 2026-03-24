// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC6909TransferFacet_Base_Test} from "test/unit/token/ERC6909/Transfer/ERC6909TransferFacetBase.t.sol";
import {ERC6909StorageUtils} from "test/utils/storage/ERC6909StorageUtils.sol";
import {ERC6909TransferFacet} from "src/token/ERC6909/Transfer/ERC6909TransferFacet.sol";

/**
 * @dev BTT spec: test/trees/ERC6909.tree
 */
contract Transfer_ERC6909TransferFacet_Fuzz_Test is ERC6909TransferFacet_Base_Test {
    using ERC6909StorageUtils for address;

    function testFuzz_RevertWhen_ReceiverZero_Transfer(uint256 id, uint256 amount) external {
        vm.stopPrank();
        vm.prank(users.alice);
        vm.expectRevert(abi.encodeWithSelector(ERC6909TransferFacet.ERC6909InvalidReceiver.selector, address(0)));
        facet.transfer(address(0), id, amount);
    }

    function testFuzz_RevertWhen_InsufficientBalance_Transfer(uint256 id, uint256 balance, uint256 amount) external {
        vm.assume(balance < type(uint256).max);
        amount = bound(amount, balance + 1, type(uint256).max);
        seedBalance(address(facet), users.alice, id, balance);
        vm.stopPrank();
        vm.prank(users.alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC6909TransferFacet.ERC6909InsufficientBalance.selector, users.alice, balance, amount, id
            )
        );
        facet.transfer(users.bob, id, amount);
    }

    function testFuzz_ShouldUpdateBalancesAndEmit_Transfer(address receiver, uint256 id, uint256 amount) external {
        vm.assume(receiver != address(0));
        vm.assume(receiver != users.alice);
        vm.assume(amount != 0);
        vm.assume(amount < type(uint256).max);
        seedBalance(address(facet), users.alice, id, amount);
        vm.stopPrank();
        vm.prank(users.alice);
        vm.expectEmit(true, true, true, true);
        emit ERC6909TransferFacet.Transfer(users.alice, users.alice, receiver, id, amount);
        facet.transfer(receiver, id, amount);
        assertEq(address(facet).balanceOf(users.alice, id), 0, "from");
        assertEq(address(facet).balanceOf(receiver, id), amount, "to");
    }

    function test_ShouldSucceed_Transfer_WhenAmountZero() external {
        uint256 id = 1;
        seedBalance(address(facet), users.alice, id, 100);
        vm.stopPrank();
        vm.prank(users.alice);
        vm.expectEmit(true, true, true, true);
        emit ERC6909TransferFacet.Transfer(users.alice, users.alice, users.bob, id, 0);
        facet.transfer(users.bob, id, 0);
        assertEq(address(facet).balanceOf(users.alice, id), 100, "from unchanged");
        assertEq(address(facet).balanceOf(users.bob, id), 0, "to unchanged");
    }

    function testFuzz_RevertWhen_SenderZero_TransferFrom(address receiver, uint256 id, uint256 amount) external {
        vm.assume(receiver != address(0));
        vm.stopPrank();
        vm.prank(users.alice);
        vm.expectRevert(abi.encodeWithSelector(ERC6909TransferFacet.ERC6909InvalidSender.selector, address(0)));
        facet.transferFrom(address(0), receiver, id, amount);
    }

    function testFuzz_RevertWhen_ReceiverZero_TransferFrom(address sender, uint256 id, uint256 amount) external {
        vm.assume(sender != address(0));
        seedBalance(address(facet), sender, id, amount);
        vm.stopPrank();
        vm.prank(sender);
        vm.expectRevert(abi.encodeWithSelector(ERC6909TransferFacet.ERC6909InvalidReceiver.selector, address(0)));
        facet.transferFrom(sender, address(0), id, amount);
    }

    function testFuzz_RevertWhen_InsufficientBalance_TransferFrom(
        address sender,
        address receiver,
        uint256 id,
        uint256 balance,
        uint256 spend
    ) external {
        vm.assume(sender != address(0) && receiver != address(0));
        vm.assume(sender != users.bob);
        balance = bound(balance, 0, type(uint256).max - 2);
        spend = bound(spend, balance + 1, type(uint256).max);

        seedBalance(address(facet), sender, id, balance);
        seedAllowance(address(facet), sender, users.bob, id, type(uint256).max);

        vm.stopPrank();
        vm.prank(users.bob);
        vm.expectRevert(
            abi.encodeWithSelector(ERC6909TransferFacet.ERC6909InsufficientBalance.selector, sender, balance, spend, id)
        );
        facet.transferFrom(sender, receiver, id, spend);
    }

    function testFuzz_RevertWhen_InsufficientAllowance_TransferFrom(
        address sender,
        address receiver,
        uint256 id,
        uint256 balance,
        uint256 allowanceAmt,
        uint256 spend
    ) external {
        vm.assume(sender != address(0) && receiver != address(0));
        vm.assume(sender != users.bob);
        balance = bound(balance, 1, type(uint256).max - 1);
        allowanceAmt = bound(allowanceAmt, 0, balance - 1);
        spend = bound(spend, allowanceAmt + 1, balance);
        vm.assume(spend < type(uint256).max);

        seedBalance(address(facet), sender, id, balance);
        seedAllowance(address(facet), sender, users.bob, id, allowanceAmt);

        vm.stopPrank();
        vm.prank(users.bob);
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC6909TransferFacet.ERC6909InsufficientAllowance.selector, users.bob, allowanceAmt, spend, id
            )
        );
        facet.transferFrom(sender, receiver, id, spend);
    }

    function test_ShouldNotDecreaseAllowance_TransferFrom_WhenAllowanceMax() external {
        uint256 id = 7;
        uint256 amt = 50;
        seedBalance(address(facet), users.alice, id, amt);
        seedAllowance(address(facet), users.alice, users.bob, id, type(uint256).max);
        vm.stopPrank();
        vm.prank(users.bob);
        facet.transferFrom(users.alice, users.charlee, id, amt);
        assertEq(address(facet).allowance(users.alice, users.bob, id), type(uint256).max, "allowance still max");
    }

    function test_ShouldBypassAllowance_TransferFrom_WhenCallerIsOperator() external {
        uint256 id = 3;
        uint256 amt = 40;
        seedBalance(address(facet), users.alice, id, amt);
        seedIsOperator(address(facet), users.alice, users.bob, true);
        vm.stopPrank();
        vm.prank(users.bob);
        vm.expectEmit(true, true, true, true);
        emit ERC6909TransferFacet.Transfer(users.bob, users.alice, users.charlee, id, amt);
        facet.transferFrom(users.alice, users.charlee, id, amt);
        assertEq(address(facet).balanceOf(users.alice, id), 0, "from");
        assertEq(address(facet).balanceOf(users.charlee, id), amt, "to");
    }

    function test_ShouldBypassAllowance_TransferFrom_WhenCallerIsSender() external {
        uint256 id = 9;
        uint256 amt = 25;
        seedBalance(address(facet), users.alice, id, amt);
        vm.stopPrank();
        vm.prank(users.alice);
        facet.transferFrom(users.alice, users.bob, id, amt);
        assertEq(address(facet).balanceOf(users.bob, id), amt, "to");
    }

    function testFuzz_ShouldDecreaseAllowanceAndBalances_TransferFrom(
        address sender,
        address receiver,
        uint256 id,
        uint256 balance,
        uint256 allowanceAmt,
        uint256 spend
    ) external {
        vm.assume(sender != address(0) && receiver != address(0));
        vm.assume(sender != receiver);
        vm.assume(sender != users.bob);
        balance = bound(balance, 2, type(uint256).max / 2);
        spend = bound(spend, 1, balance);
        allowanceAmt = bound(allowanceAmt, spend, balance);

        seedBalance(address(facet), sender, id, balance);
        seedAllowance(address(facet), sender, users.bob, id, allowanceAmt);

        vm.stopPrank();
        vm.prank(users.bob);
        vm.expectEmit(true, true, true, true);
        emit ERC6909TransferFacet.Transfer(users.bob, sender, receiver, id, spend);
        facet.transferFrom(sender, receiver, id, spend);

        assertEq(address(facet).balanceOf(sender, id), balance - spend, "from bal");
        assertEq(address(facet).balanceOf(receiver, id), spend, "to bal");
        assertEq(address(facet).allowance(sender, users.bob, id), allowanceAmt - spend, "allowance");
    }
}
