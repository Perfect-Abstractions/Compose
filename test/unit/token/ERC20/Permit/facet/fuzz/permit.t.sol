// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC20PermitFacet_Base_Test} from "test/unit/token/ERC20/Permit/ERC20PermitFacetBase.t.sol";
import {ERC20StorageUtils} from "test/utils/storage/ERC20StorageUtils.sol";
import {ERC20PermitFacet} from "src/token/ERC20/Permit/ERC20PermitFacet.sol";

/**
 *  @dev BTT spec: test/trees/ERC20.tree
 */
contract Permit_ERC20PermitFacet_Fuzz_Unit_Test is ERC20PermitFacet_Base_Test {
    using ERC20StorageUtils for address;

    function testFuzz_ShouldRevert_WhenSpenderIsZeroAddress(
        address owner,
        uint256 value,
        uint256 deadline
    ) external {
        uint256 ownerPrivateKey = 0xA11CE;
        owner = vm.addr(ownerPrivateKey);
        deadline = bound(deadline, block.timestamp + 1, type(uint256).max);
        value = bound(value, 0, MAX_UINT256);
        bytes32 hash = _getPermitDigest(owner, ADDRESS_ZERO, value, 0, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, hash);

        vm.expectRevert(abi.encodeWithSelector(ERC20PermitFacet.ERC20InvalidSpender.selector, ADDRESS_ZERO));
        facet.permit(owner, ADDRESS_ZERO, value, deadline, v, r, s);
    }

    function testFuzz_ShouldRevert_WhenDeadlineExpired(
        address owner,
        address spender,
        uint256 value
    ) external {
        vm.assume(spender != ADDRESS_ZERO);
        uint256 ownerPrivateKey = 0xB0B;
        owner = vm.addr(ownerPrivateKey);
        value = bound(value, 0, MAX_UINT256);
        uint256 deadline = block.timestamp - 1;
        bytes32 hash = _getPermitDigest(owner, spender, value, 0, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, hash);

        vm.expectRevert(
            abi.encodeWithSelector(
                ERC20PermitFacet.ERC2612InvalidSignature.selector,
                owner,
                spender,
                value,
                deadline,
                v,
                r,
                s
            )
        );
        facet.permit(owner, spender, value, deadline, v, r, s);
    }

    function testFuzz_ShouldRevert_WhenSignatureInvalid(
        address spender,
        uint256 value,
        uint256 deadline
    ) external {
        vm.assume(spender != ADDRESS_ZERO);
        uint256 ownerPrivateKey = 0xA11CE;
        address owner = vm.addr(ownerPrivateKey);
        uint256 wrongPrivateKey = 0xB0B;
        deadline = bound(deadline, block.timestamp + 1, type(uint256).max);
        value = bound(value, 0, MAX_UINT256);
        bytes32 hash = _getPermitDigest(owner, spender, value, 0, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(wrongPrivateKey, hash);

        vm.expectRevert(
            abi.encodeWithSelector(
                ERC20PermitFacet.ERC2612InvalidSignature.selector,
                owner,
                spender,
                value,
                deadline,
                v,
                r,
                s
            )
        );
        facet.permit(owner, spender, value, deadline, v, r, s);
    }

    function testFuzz_Permit(
        address spender,
        uint256 value,
        uint256 deadline
    ) external {
        vm.assume(spender != ADDRESS_ZERO);
        uint256 ownerPrivateKey = 0xA11CE;
        address owner = vm.addr(ownerPrivateKey);
        deadline = bound(deadline, block.timestamp + 1, type(uint256).max);
        value = bound(value, 0, MAX_UINT256);
        bytes32 hash = _getPermitDigest(owner, spender, value, 0, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, hash);

        vm.expectEmit(address(facet));
        emit ERC20PermitFacet.Approval(owner, spender, value);
        facet.permit(owner, spender, value, deadline, v, r, s);

        assertEq(address(facet).allowance(owner, spender), value, "allowance");
        assertEq(facet.nonces(owner), 1, "nonce");
    }

    function test_Permit_IncrementsNonce() external {
        uint256 ownerPrivateKey = 0xC0C;
        address owner = vm.addr(ownerPrivateKey);
        address spender = users.bob;
        uint256 deadline = block.timestamp + 1 hours;

        for (uint256 i = 0; i < 3; i++) {
            uint256 value = (i + 1) * 100e18;
            bytes32 hash = _getPermitDigest(owner, spender, value, i, deadline);
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, hash);
            facet.permit(owner, spender, value, deadline, v, r, s);
            assertEq(facet.nonces(owner), i + 1, "nonce after permit");
        }
    }
}
