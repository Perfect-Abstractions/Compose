// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC1155MintMod_Base_Test} from "test/unit/token/ERC1155/Mint/ERC1155MintModBase.t.sol";
import {ERC1155StorageUtils} from "test/utils/storage/ERC1155StorageUtils.sol";
import {ERC1155ReceiverMock} from "test/utils/mocks/ERC1155ReceiverMock.sol";
import "src/token/ERC1155/Mint/ERC1155MintMod.sol";

/**
 * @dev BTT spec: test/trees/ERC1155.tree
 */
contract Mint_ERC1155MintMod_Fuzz_Test is ERC1155MintMod_Base_Test {
    using ERC1155StorageUtils for address;

    function testFuzz_ShouldRevert_Mint_WhenToIsZeroAddress(uint256 id, uint256 value) external {
        vm.expectRevert(abi.encodeWithSelector(ERC1155InvalidReceiver.selector, address(0)));
        harness.mint(address(0), id, value, "");
    }

    function testFuzz_ShouldIncrementBalanceAndEmit_Mint_WhenToNotZero(address to, uint256 id, uint256 value) external {
        vm.assume(to != address(0));
        vm.assume(to.code.length == 0);
        vm.assume(value != type(uint256).max);

        harness.mint(to, id, value, "");

        assertEq(address(harness).balanceOf(id, to), value, "balanceOf");
    }

    function testFuzz_ShouldIncrementBalance_Mint_WhenToIsReceiverContract(uint256 id, uint256 value) external {
        vm.assume(value != type(uint256).max);
        ERC1155ReceiverMock receiver = new ERC1155ReceiverMock(
            RECEIVER_SINGLE_MAGIC_VALUE, RECEIVER_BATCH_MAGIC_VALUE, ERC1155ReceiverMock.RevertType.None
        );

        harness.mint(address(receiver), id, value, "");

        assertEq(address(harness).balanceOf(id, address(receiver)), value, "balanceOf");
    }

    function testFuzz_ShouldRevert_Mint_WhenReceiverContractReturnsWrongValue(uint256 id, uint256 value) external {
        vm.assume(value != type(uint256).max);
        ERC1155ReceiverMock receiver =
            new ERC1155ReceiverMock(bytes4(0), bytes4(0), ERC1155ReceiverMock.RevertType.None);

        vm.expectRevert(abi.encodeWithSelector(ERC1155InvalidReceiver.selector, address(receiver)));
        harness.mint(address(receiver), id, value, "");
    }

    function test_ShouldRevert_Mint_WhenReceiverContractRevertsWithMessage(uint256 id, uint256 value) external {
        vm.assume(value != type(uint256).max);
        ERC1155ReceiverMock receiver = new ERC1155ReceiverMock(
            RECEIVER_SINGLE_MAGIC_VALUE, RECEIVER_BATCH_MAGIC_VALUE, ERC1155ReceiverMock.RevertType.RevertWithMessage
        );
        vm.expectRevert("ERC1155ReceiverMock: reverting on receive");
        harness.mint(address(receiver), id, value, "");
    }

    function test_ShouldRevert_Mint_WhenOverflowsRecipient() external {
        uint256 nearMax = type(uint256).max - 100;
        address(harness).setBalanceOf(1, users.alice, nearMax);
        vm.expectRevert();
        harness.mint(users.alice, 1, 200, "");
    }
}
