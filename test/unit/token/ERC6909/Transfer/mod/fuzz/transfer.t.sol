// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC6909TransferMod_Base_Test} from "test/unit/token/ERC6909/Transfer/ERC6909TransferModBase.t.sol";
import {ERC6909StorageUtils} from "test/utils/storage/ERC6909StorageUtils.sol";
import {ERC6909TransferFacet} from "src/token/ERC6909/Transfer/ERC6909TransferFacet.sol";

/**
 * @dev BTT spec: test/trees/ERC6909.tree
 */
contract Transfer_ERC6909TransferMod_Fuzz_Test is ERC6909TransferMod_Base_Test {
    using ERC6909StorageUtils for address;

    function testFuzz_RevertWhen_ReceiverZero_Transfer(uint256 id, uint256 amount) external {
        vm.stopPrank();
        vm.prank(users.alice);
        vm.expectRevert(abi.encodeWithSelector(ERC6909TransferFacet.ERC6909InvalidReceiver.selector, address(0)));
        harness.transfer(address(0), id, amount);
    }

    function testFuzz_ShouldUpdateBalances_Transfer(address receiver, uint256 id, uint256 amount) external {
        vm.assume(receiver != address(0));
        vm.assume(receiver != users.alice);
        vm.assume(amount != 0);
        vm.assume(amount < type(uint256).max);
        seedBalance(address(harness), users.alice, id, amount);
        vm.stopPrank();
        vm.prank(users.alice);
        harness.transfer(receiver, id, amount);
        assertEq(address(harness).balanceOf(users.alice, id), 0, "from");
        assertEq(address(harness).balanceOf(receiver, id), amount, "to");
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

        seedBalance(address(harness), sender, id, balance);
        seedAllowance(address(harness), sender, users.bob, id, allowanceAmt);

        vm.stopPrank();
        vm.prank(users.bob);
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC6909TransferFacet.ERC6909InsufficientAllowance.selector, users.bob, allowanceAmt, spend, id
            )
        );
        harness.transferFrom(sender, receiver, id, spend);
    }

    function test_ShouldBypassAllowance_TransferFrom_WhenCallerIsOperator() external {
        uint256 id = 3;
        uint256 amt = 40;
        seedBalance(address(harness), users.alice, id, amt);
        seedIsOperator(address(harness), users.alice, users.bob, true);
        vm.stopPrank();
        vm.prank(users.bob);
        harness.transferFrom(users.alice, users.charlee, id, amt);
        assertEq(address(harness).balanceOf(users.alice, id), 0, "from");
        assertEq(address(harness).balanceOf(users.charlee, id), amt, "to");
    }
}
