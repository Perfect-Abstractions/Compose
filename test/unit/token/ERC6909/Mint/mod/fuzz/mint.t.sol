// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {Vm} from "forge-std/Vm.sol";

import {ERC6909MintMod_Base_Test} from "test/unit/token/ERC6909/Mint/ERC6909MintModBase.t.sol";
import {ERC6909StorageUtils} from "test/utils/storage/ERC6909StorageUtils.sol";
import {ERC6909TransferFacet} from "src/token/ERC6909/Transfer/ERC6909TransferFacet.sol";

/**
 * @dev BTT spec: test/trees/ERC6909.tree
 */
contract Mint_ERC6909MintMod_Fuzz_Test is ERC6909MintMod_Base_Test {
    using ERC6909StorageUtils for address;

    function testFuzz_RevertWhen_AccountZero_Mint(uint256 id, uint256 value) external {
        vm.expectRevert(abi.encodeWithSelector(ERC6909TransferFacet.ERC6909InvalidReceiver.selector, address(0)));
        harness.mint(address(0), id, value);
    }

    function testFuzz_ShouldIncreaseBalance_Mint(address account, uint256 id, uint256 value) external {
        vm.assume(account != address(0));
        vm.assume(value != 0);
        vm.assume(value < type(uint256).max);

        harness.mint(account, id, value);

        assertEq(address(harness).balanceOf(account, id), value, "balance");
    }

    function test_ShouldEmitTransfer_Mint() external {
        uint256 id = 1;
        uint256 value = 100;
        vm.stopPrank();
        vm.recordLogs();
        harness.mint(users.alice, id, value);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length, 1, "one log");
        assertEq(logs[0].topics[0], keccak256("Transfer(address,address,address,uint256,uint256)"), "event sig");
        assertEq(address(uint160(uint256(logs[0].topics[1]))), address(0), "indexed sender");
        assertEq(address(uint160(uint256(logs[0].topics[2]))), users.alice, "indexed receiver");
        assertEq(uint256(logs[0].topics[3]), id, "indexed id");
        (address caller, uint256 amount) = abi.decode(logs[0].data, (address, uint256));
        assertEq(caller, address(this), "caller");
        assertEq(amount, value, "amount");
    }
}
