// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

/* Compose
 * https://compose.diamonds
 */

import "src/diamond/DiamondMod.sol" as DiamondMod;
import {DiamondMod_Base_Test} from "test/unit/diamond/DiamondModBase.t.sol";
import {DIAMOND_TEST_STORAGE_POSITION, DispatchFacet} from "test/utils/mocks/diamond/DiamondFacetMocks.sol";

/**
 * @dev BTT spec: test/trees/Diamond.tree
 */
contract Fallback_DiamondMod_Fuzz_Unit_Test is DiamondMod_Base_Test {
    function test_ShouldRevertWithFunctionNotFoundForUnknownSelector() external {
        bytes4 unknownSelector = bytes4(keccak256("unknownFunction(uint256)"));
        bytes memory callData = abi.encodeWithSelector(unknownSelector, uint256(123));

        (bool success, bytes memory data) = address(harness).call(callData);

        assertEq(success, false, "fallback call");
        assertEq(data, abi.encodeWithSelector(DiamondMod.FunctionNotFound.selector, unknownSelector), "revert data");
    }

    function testFuzz_ShouldPreserveContextAndReturnData(uint96 _value, uint256 _argument, address _caller) external {
        vm.assume(_caller != address(0));
        harness.addFacets(_singleAddress(address(dispatchFacet)));
        vm.deal(_caller, _value);

        vm.stopPrank();
        vm.prank(_caller);
        (bool success, bytes memory data) =
            address(harness).call{value: _value}(abi.encodeCall(DispatchFacet.context, (_argument)));

        assertEq(success, true, "fallback call");
        assertEq(data, abi.encode(_caller, uint256(_value), _argument), "returndata");
        (address sender, uint256 value, uint256 argument) = abi.decode(data, (address, uint256, uint256));
        assertEq(sender, _caller, "msg.sender");
        assertEq(value, _value, "msg.value");
        assertEq(argument, _argument, "argument");
        assertEq(uint256(vm.load(address(harness), DIAMOND_TEST_STORAGE_POSITION)), _argument, "diamond storage");
        assertEq(uint256(vm.load(address(dispatchFacet), DIAMOND_TEST_STORAGE_POSITION)), 0, "facet storage");
    }

    function testFuzz_ShouldBubbleExactRevertData(uint256 _value) external {
        harness.addFacets(_singleAddress(address(dispatchFacet)));

        (bool success, bytes memory data) = address(harness).call(abi.encodeCall(DispatchFacet.fail, (_value)));

        assertEq(success, false, "fallback call");
        assertEq(data, abi.encodeWithSelector(DispatchFacet.DispatchFailure.selector, _value), "revert data");
    }
}
