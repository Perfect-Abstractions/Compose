// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {Test} from "forge-std/Test.sol";
import {ERC20PermitFacet} from "../../../../src/token/ERC20/ERC20/ERC20PermitFacet.sol";
import {ERC20PermitFacetHarness} from "./harnesses/ERC20PermitFacetHarness.sol";

contract ERC20BurnFacetTest is Test {
    ERC20PermitFacetHarness public token;

    address public alice;
    address public bob;
    address public charlie;

    string constant TOKEN_NAME = "Test Token";
    uint256 constant INITIAL_SUPPLY = 1000000e18;
    uint256 constant TOTAL_SUPPLY = 1000000000e18;

    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);

    function setUp() public {
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");

        token = new ERC20PermitFacetHarness();
        token.initialize(TOKEN_NAME, TOTAL_SUPPLY);
        token.mint(alice, INITIAL_SUPPLY);
    }

    function test_Nonces() public view {
        assertEq(token.nonces(alice), 0);
        assertEq(token.nonces(bob), 0);
    }

    function test_DOMAIN_SEPARATOR() public view {
        bytes32 expectedDomainSeparator = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(TOKEN_NAME)),
                keccak256("1"),
                block.chainid,
                address(token)
            )
        );
        assertEq(token.DOMAIN_SEPARATOR(), expectedDomainSeparator);
    }

    function test_DOMAIN_SEPARATOR_ConsistentWithinSameChain() public view {
        // First call - computes domain separator
        bytes32 separator1 = token.DOMAIN_SEPARATOR();

        // Second call - recomputes and should return same value for same chain ID
        bytes32 separator2 = token.DOMAIN_SEPARATOR();

        assertEq(separator1, separator2);
    }

    function test_DOMAIN_SEPARATOR_RecalculatesAfterFork() public {
        // Get initial domain separator on chain 1
        uint256 originalChainId = block.chainid;
        bytes32 separator1 = token.DOMAIN_SEPARATOR();

        // Simulate chain fork (chain ID changes)
        vm.chainId(originalChainId + 1);

        // Domain separator should recalculate with new chain ID
        bytes32 separator2 = token.DOMAIN_SEPARATOR();

        // Separators should be different
        assertTrue(separator1 != separator2);

        // New separator should match expected value for new chain ID
        bytes32 expectedSeparator = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(TOKEN_NAME)),
                keccak256("1"),
                originalChainId + 1,
                address(token)
            )
        );
        assertEq(separator2, expectedSeparator);
    }

    function test_Permit() public {
        uint256 ownerPrivateKey = 0xA11CE;
        address owner = vm.addr(ownerPrivateKey);
        address spender = bob;
        uint256 value = 100e18;
        uint256 nonce = 0;
        uint256 deadline = block.timestamp + 1 hours;

        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                owner,
                spender,
                value,
                nonce,
                deadline
            )
        );

        bytes32 hash = keccak256(abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, hash);

        vm.expectEmit(true, true, true, true);
        emit Approval(owner, spender, value);
        token.permit(owner, spender, value, deadline, v, r, s);

        assertEq(token.allowance(owner, spender), value);
        assertEq(token.nonces(owner), 1);
    }

    function test_Permit_IncreasesNonce() public {
        uint256 ownerPrivateKey = 0xB0B;
        address owner = vm.addr(ownerPrivateKey);
        uint256 deadline = block.timestamp + 1 hours;

        for (uint256 i = 0; i < 3; i++) {
            bytes32 structHash = keccak256(
                abi.encode(
                    keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                    owner,
                    bob,
                    100e18,
                    i,
                    deadline
                )
            );

            bytes32 hash = keccak256(abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash));
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, hash);

            token.permit(owner, bob, 100e18, deadline, v, r, s);
            assertEq(token.nonces(owner), i + 1);
        }
    }

    function test_RevertWhen_PermitExpired() public {
        uint256 ownerPrivateKey = 0xA11CE;
        address owner = vm.addr(ownerPrivateKey);
        uint256 value = 100e18;
        uint256 deadline = block.timestamp - 1;

        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                owner,
                bob,
                value,
                0,
                deadline
            )
        );

        bytes32 hash = keccak256(abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, hash);

        vm.expectRevert(
            abi.encodeWithSelector(ERC20PermitFacet.ERC2612InvalidSignature.selector, owner, bob, value, deadline, v, r, s)
        );
        token.permit(owner, bob, value, deadline, v, r, s);
    }

    function test_RevertWhen_PermitInvalidSignature() public {
        uint256 ownerPrivateKey = 0xA11CE;
        address owner = vm.addr(ownerPrivateKey);
        uint256 wrongPrivateKey = 0xBAD;
        uint256 value = 100e18;
        uint256 deadline = block.timestamp + 1 hours;

        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                owner,
                bob,
                value,
                0,
                deadline
            )
        );

        bytes32 hash = keccak256(abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(wrongPrivateKey, hash);

        vm.expectRevert(
            abi.encodeWithSelector(ERC20PermitFacet.ERC2612InvalidSignature.selector, owner, bob, value, deadline, v, r, s)
        );
        token.permit(owner, bob, value, deadline, v, r, s);
    }

    function test_RevertWhen_PermitReplay() public {
        uint256 ownerPrivateKey = 0xA11CE;
        address owner = vm.addr(ownerPrivateKey);
        uint256 value = 100e18;
        uint256 deadline = block.timestamp + 1 hours;

        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                owner,
                bob,
                value,
                0,
                deadline
            )
        );

        bytes32 hash = keccak256(abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, hash);

        token.permit(owner, bob, value, deadline, v, r, s);

        vm.expectRevert(
            abi.encodeWithSelector(ERC20PermitFacet.ERC2612InvalidSignature.selector, owner, bob, value, deadline, v, r, s)
        );
        token.permit(owner, bob, value, deadline, v, r, s);
    }

    function test_RevertWhen_PermitZeroAddressSpender() public {
        uint256 ownerPrivateKey = 0xA11CE;
        address owner = vm.addr(ownerPrivateKey);
        uint256 value = 100e18;
        uint256 deadline = block.timestamp + 1 hours;

        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                owner,
                address(0),
                value,
                0,
                deadline
            )
        );

        bytes32 hash = keccak256(abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, hash);

        vm.expectRevert(abi.encodeWithSelector(ERC20PermitFacet.ERC20InvalidSpender.selector, address(0)));
        token.permit(owner, address(0), value, deadline, v, r, s);
    }

    function test_Permit_MaxValue() public {
        uint256 ownerPrivateKey = 0xA11CE;
        address owner = vm.addr(ownerPrivateKey);
        uint256 value = type(uint256).max;
        uint256 deadline = block.timestamp + 1 hours;

        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                owner,
                bob,
                value,
                0,
                deadline
            )
        );

        bytes32 hash = keccak256(abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, hash);

        token.permit(owner, bob, value, deadline, v, r, s);

        assertEq(token.allowance(owner, bob), type(uint256).max);
        assertEq(token.nonces(owner), 1);
    }

    function test_Permit_ThenTransferFrom() public {
        uint256 ownerPrivateKey = 0xA11CE;
        address owner = vm.addr(ownerPrivateKey);
        uint256 permitValue = 500e18;
        uint256 transferAmount = 300e18;
        uint256 deadline = block.timestamp + 1 hours;

        token.mint(owner, 1000e18);

        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                owner,
                bob,
                permitValue,
                0,
                deadline
            )
        );

        bytes32 hash = keccak256(abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, hash);

        token.permit(owner, bob, permitValue, deadline, v, r, s);

        uint256 ownerBalanceBefore = token.balanceOf(owner);

        vm.prank(bob);
        token.transferFrom(owner, charlie, transferAmount);

        assertEq(token.balanceOf(owner), ownerBalanceBefore - transferAmount);
        assertEq(token.balanceOf(charlie), transferAmount);
        assertEq(token.allowance(owner, bob), permitValue - transferAmount);
    }

    function test_RevertWhen_PermitWrongNonce() public {
        uint256 ownerPrivateKey = 0xA11CE;
        address owner = vm.addr(ownerPrivateKey);
        uint256 value = 100e18;
        uint256 wrongNonce = 99;
        uint256 deadline = block.timestamp + 1 hours;

        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                owner,
                bob,
                value,
                wrongNonce,
                deadline
            )
        );

        bytes32 hash = keccak256(abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, hash);

        vm.expectRevert(
            abi.encodeWithSelector(ERC20PermitFacet.ERC2612InvalidSignature.selector, owner, bob, value, deadline, v, r, s)
        );
        token.permit(owner, bob, value, deadline, v, r, s);
    }

    function test_Permit_ZeroValue() public {
        uint256 ownerPrivateKey = 0xA11CE;
        address owner = vm.addr(ownerPrivateKey);
        uint256 value = 0;
        uint256 deadline = block.timestamp + 1 hours;

        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                owner,
                bob,
                value,
                0,
                deadline
            )
        );

        bytes32 hash = keccak256(abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, hash);

        token.permit(owner, bob, value, deadline, v, r, s);

        assertEq(token.allowance(owner, bob), 0);
        assertEq(token.nonces(owner), 1);
    }

    function test_Permit_MultipleDifferentSpenders() public {
        uint256 ownerPrivateKey = 0xA11CE;
        address owner = vm.addr(ownerPrivateKey);
        uint256 deadline = block.timestamp + 1 hours;

        address[] memory spenders = new address[](3);
        spenders[0] = bob;
        spenders[1] = charlie;
        spenders[2] = makeAddr("dave");

        uint256[] memory values = new uint256[](3);
        values[0] = 100e18;
        values[1] = 200e18;
        values[2] = 300e18;

        for (uint256 i = 0; i < spenders.length; i++) {
            bytes32 structHash = keccak256(
                abi.encode(
                    keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                    owner,
                    spenders[i],
                    values[i],
                    i,
                    deadline
                )
            );

            bytes32 hash = keccak256(abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash));
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, hash);

            token.permit(owner, spenders[i], values[i], deadline, v, r, s);
            assertEq(token.allowance(owner, spenders[i]), values[i]);
        }

        assertEq(token.nonces(owner), 3);
    }

    function test_Permit_OverwritesExistingAllowance() public {
        uint256 ownerPrivateKey = 0xA11CE;
        address owner = vm.addr(ownerPrivateKey);
        uint256 deadline = block.timestamp + 1 hours;

        token.mint(owner, 1000e18);

        vm.prank(owner);
        token.approve(bob, 100e18);
        assertEq(token.allowance(owner, bob), 100e18);

        uint256 newValue = 500e18;
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                owner,
                bob,
                newValue,
                0,
                deadline
            )
        );

        bytes32 hash = keccak256(abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, hash);

        token.permit(owner, bob, newValue, deadline, v, r, s);

        assertEq(token.allowance(owner, bob), newValue);
    }

    function test_RevertWhen_PermitMalformedSignature() public {
        uint256 ownerPrivateKey = 0xA11CE;
        address owner = vm.addr(ownerPrivateKey);
        uint256 value = 100e18;
        uint256 deadline = block.timestamp + 1 hours;

        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                owner,
                bob,
                value,
                0,
                deadline
            )
        );

        bytes32 hash = keccak256(abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, hash);

        // Test with invalid v value (should be 27 or 28)
        vm.expectRevert(
            abi.encodeWithSelector(ERC20PermitFacet.ERC2612InvalidSignature.selector, owner, bob, value, deadline, 99, r, s)
        );
        token.permit(owner, bob, value, deadline, 99, r, s);

        // Test with zero r value
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC20PermitFacet.ERC2612InvalidSignature.selector, owner, bob, value, deadline, v, bytes32(0), s
            )
        );
        token.permit(owner, bob, value, deadline, v, bytes32(0), s);

        // Test with zero s value
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC20PermitFacet.ERC2612InvalidSignature.selector, owner, bob, value, deadline, v, r, bytes32(0)
            )
        );
        token.permit(owner, bob, value, deadline, v, r, bytes32(0));
    }

    function testFuzz_Permit(uint256 ownerKey, address spender, uint256 value, uint256 deadline) public {
        vm.assume(ownerKey != 0 && ownerKey < type(uint256).max / 2);
        vm.assume(spender != address(0));
        vm.assume(deadline > block.timestamp);

        address owner = vm.addr(ownerKey);

        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                owner,
                spender,
                value,
                0,
                deadline
            )
        );

        bytes32 hash = keccak256(abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerKey, hash);

        token.permit(owner, spender, value, deadline, v, r, s);

        assertEq(token.allowance(owner, spender), value);
        assertEq(token.nonces(owner), 1);
    }
}