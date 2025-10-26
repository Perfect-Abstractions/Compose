// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {Test} from "forge-std/Test.sol";
import {ERC20Facet} from "../../src/token/ERC20/ERC20/ERC20Facet.sol";
import {ERC20FacetHarness} from "./harnesses/ERC20FacetHarness.sol";

contract ERC20FacetTest is Test {
    ERC20FacetHarness public token;

    address public alice;
    address public bob;
    address public charlie;

    string constant TOKEN_NAME = "Test Token";
    string constant TOKEN_SYMBOL = "TEST";
    uint8 constant TOKEN_DECIMALS = 18;
    uint256 constant INITIAL_SUPPLY = 1000000e18;

    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);

    function setUp() public {
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");

        token = new ERC20FacetHarness();
        token.initialize(TOKEN_NAME, TOKEN_SYMBOL, TOKEN_DECIMALS);
        token.mint(alice, INITIAL_SUPPLY);
    }

    // ============================================
    // Metadata Tests
    // ============================================

    function test_Name() public view {
        assertEq(token.name(), TOKEN_NAME);
    }

    function test_Symbol() public view {
        assertEq(token.symbol(), TOKEN_SYMBOL);
    }

    function test_Decimals() public view {
        assertEq(token.decimals(), TOKEN_DECIMALS);
    }

    function test_TotalSupply() public view {
        assertEq(token.totalSupply(), INITIAL_SUPPLY);
    }

    function test_BalanceOf() public view {
        assertEq(token.balanceOf(alice), INITIAL_SUPPLY);
        assertEq(token.balanceOf(bob), 0);
    }

    // ============================================
    // Transfer Tests
    // ============================================

    function test_Transfer() public {
        uint256 amount = 100e18;

        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit Transfer(alice, bob, amount);
        bool success = token.transfer(bob, amount);

        assertTrue(success);
        assertEq(token.balanceOf(alice), INITIAL_SUPPLY - amount);
        assertEq(token.balanceOf(bob), amount);
    }

    function test_Transfer_ReturnsTrue() public {
        uint256 amount = 100e18;

        vm.prank(alice);
        bool result = token.transfer(bob, amount);

        assertTrue(result, "transfer should return true");
    }

    function test_Transfer_ToSelf() public {
        uint256 amount = 100e18;

        vm.prank(alice);
        token.transfer(alice, amount);

        assertEq(token.balanceOf(alice), INITIAL_SUPPLY);
    }

    function test_Transfer_ZeroAmount() public {
        vm.prank(alice);
        token.transfer(bob, 0);

        assertEq(token.balanceOf(alice), INITIAL_SUPPLY);
        assertEq(token.balanceOf(bob), 0);
    }

    function test_Transfer_EntireBalance() public {
        vm.prank(alice);
        token.transfer(bob, INITIAL_SUPPLY);

        assertEq(token.balanceOf(alice), 0);
        assertEq(token.balanceOf(bob), INITIAL_SUPPLY);
    }

    function test_Fuzz_Transfer(address to, uint256 amount) public {
        vm.assume(to != address(0));
        vm.assume(amount <= INITIAL_SUPPLY);

        vm.prank(alice);
        token.transfer(to, amount);

        if (to == alice) {
            assertEq(token.balanceOf(alice), INITIAL_SUPPLY);
        } else {
            assertEq(token.balanceOf(alice), INITIAL_SUPPLY - amount);
            assertEq(token.balanceOf(to), amount);
        }
    }

    function test_RevertWhen_TransferToZeroAddress() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ERC20Facet.ERC20InvalidReceiver.selector, address(0)));
        token.transfer(address(0), 100e18);
    }

    function test_RevertWhen_TransferInsufficientBalance() public {
        uint256 amount = INITIAL_SUPPLY + 1;

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(ERC20Facet.ERC20InsufficientBalance.selector, alice, INITIAL_SUPPLY, amount)
        );
        token.transfer(bob, amount);
    }

    function test_RevertWhen_TransferFromZeroBalance() public {
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(ERC20Facet.ERC20InsufficientBalance.selector, bob, 0, 1));
        token.transfer(alice, 1);
    }

    function test_RevertWhen_TransferOverflowsRecipient() public {
        uint256 maxBalance = type(uint256).max - 100;

        // Mint near-max tokens to bob
        token.mint(bob, maxBalance);

        // Alice tries to transfer 200 tokens to bob, which would overflow
        vm.prank(alice);
        vm.expectRevert(); // Arithmetic overflow
        token.transfer(bob, 200);
    }

    // ============================================
    // Approval Tests
    // ============================================

    function test_Approve() public {
        uint256 amount = 100e18;

        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit Approval(alice, bob, amount);
        bool success = token.approve(bob, amount);

        assertTrue(success);
        assertEq(token.allowance(alice, bob), amount);
    }

    function test_Approve_ReturnsTrue() public {
        uint256 amount = 100e18;

        vm.prank(alice);
        bool result = token.approve(bob, amount);

        assertTrue(result, "approve should return true");
    }

    function test_Approve_UpdateExisting() public {
        vm.startPrank(alice);
        token.approve(bob, 100e18);
        token.approve(bob, 200e18);
        vm.stopPrank();

        assertEq(token.allowance(alice, bob), 200e18);
    }

    function test_Approve_ZeroAmount() public {
        vm.startPrank(alice);
        token.approve(bob, 100e18);
        token.approve(bob, 0);
        vm.stopPrank();

        assertEq(token.allowance(alice, bob), 0);
    }

    function test_Fuzz_Approve(address spender, uint256 amount) public {
        vm.assume(spender != address(0));

        vm.prank(alice);
        token.approve(spender, amount);

        assertEq(token.allowance(alice, spender), amount);
    }

    function test_RevertWhen_ApproveZeroAddressSpender() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ERC20Facet.ERC20InvalidSpender.selector, address(0)));
        token.approve(address(0), 100e18);
    }

    // ============================================
    // TransferFrom Tests
    // ============================================

    function test_TransferFrom() public {
        uint256 amount = 100e18;

        vm.prank(alice);
        token.approve(bob, amount);

        vm.prank(bob);
        vm.expectEmit(true, true, true, true);
        emit Transfer(alice, charlie, amount);
        bool success = token.transferFrom(alice, charlie, amount);

        assertTrue(success);
        assertEq(token.balanceOf(alice), INITIAL_SUPPLY - amount);
        assertEq(token.balanceOf(charlie), amount);
        assertEq(token.allowance(alice, bob), 0);
    }

    function test_TransferFrom_ReturnsTrue() public {
        uint256 amount = 100e18;

        vm.prank(alice);
        token.approve(bob, amount);

        vm.prank(bob);
        bool result = token.transferFrom(alice, charlie, amount);

        assertTrue(result, "transferFrom should return true");
    }

    function test_TransferFrom_PartialAllowance() public {
        uint256 allowanceAmount = 200e18;
        uint256 transferAmount = 100e18;

        vm.prank(alice);
        token.approve(bob, allowanceAmount);

        vm.prank(bob);
        token.transferFrom(alice, charlie, transferAmount);

        assertEq(token.balanceOf(alice), INITIAL_SUPPLY - transferAmount);
        assertEq(token.balanceOf(charlie), transferAmount);
        assertEq(token.allowance(alice, bob), allowanceAmount - transferAmount);
    }

    function test_Fuzz_TransferFrom(uint256 approval, uint256 amount) public {
        vm.assume(approval <= INITIAL_SUPPLY);
        vm.assume(amount <= approval);

        vm.prank(alice);
        token.approve(bob, approval);

        vm.prank(bob);
        token.transferFrom(alice, charlie, amount);

        assertEq(token.balanceOf(alice), INITIAL_SUPPLY - amount);
        assertEq(token.balanceOf(charlie), amount);
        assertEq(token.allowance(alice, bob), approval - amount);
    }

    function test_TransferFrom_UnlimitedAllowance() public {
        uint256 amount = 100e18;
        uint256 maxAllowance = type(uint256).max;

        // Set unlimited allowance
        vm.prank(alice);
        token.approve(bob, maxAllowance);

        // Perform first transfer
        vm.prank(bob);
        token.transferFrom(alice, charlie, amount);

        // Check that allowance remains unchanged (unlimited)
        assertEq(token.allowance(alice, bob), maxAllowance);
        assertEq(token.balanceOf(alice), INITIAL_SUPPLY - amount);
        assertEq(token.balanceOf(charlie), amount);

        // Perform second transfer to verify allowance is still unlimited
        vm.prank(bob);
        token.transferFrom(alice, charlie, amount);

        // Check that allowance is still unchanged (unlimited)
        assertEq(token.allowance(alice, bob), maxAllowance);
        assertEq(token.balanceOf(alice), INITIAL_SUPPLY - 2 * amount);
        assertEq(token.balanceOf(charlie), 2 * amount);
    }

    function test_TransferFrom_UnlimitedAllowance_MultipleTransfers() public {
        uint256 maxAllowance = type(uint256).max;
        uint256 transferAmount = 50e18;
        uint256 numTransfers = 10;

        // Set unlimited allowance
        vm.prank(alice);
        token.approve(bob, maxAllowance);

        // Perform multiple transfers
        for (uint256 i = 0; i < numTransfers; i++) {
            vm.prank(bob);
            token.transferFrom(alice, charlie, transferAmount);

            // Verify allowance remains unlimited after each transfer
            assertEq(token.allowance(alice, bob), maxAllowance);
        }

        // Verify final balances
        assertEq(token.balanceOf(alice), INITIAL_SUPPLY - (transferAmount * numTransfers));
        assertEq(token.balanceOf(charlie), transferAmount * numTransfers);
    }

    function test_RevertWhen_TransferFromZeroAddressSender() public {
        vm.expectRevert(abi.encodeWithSelector(ERC20Facet.ERC20InvalidSender.selector, address(0)));
        token.transferFrom(address(0), bob, 100e18);
    }

    function test_RevertWhen_TransferFromZeroAddressReceiver() public {
        vm.prank(alice);
        token.approve(bob, 100e18);

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(ERC20Facet.ERC20InvalidReceiver.selector, address(0)));
        token.transferFrom(alice, address(0), 100e18);
    }

    function test_RevertWhen_TransferFromInsufficientAllowance() public {
        uint256 allowanceAmount = 50e18;
        uint256 transferAmount = 100e18;

        vm.prank(alice);
        token.approve(bob, allowanceAmount);

        vm.prank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(ERC20Facet.ERC20InsufficientAllowance.selector, bob, allowanceAmount, transferAmount)
        );
        token.transferFrom(alice, charlie, transferAmount);
    }

    function test_RevertWhen_TransferFromInsufficientBalance() public {
        uint256 amount = INITIAL_SUPPLY + 1;

        vm.prank(alice);
        token.approve(bob, amount);

        vm.prank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(ERC20Facet.ERC20InsufficientBalance.selector, alice, INITIAL_SUPPLY, amount)
        );
        token.transferFrom(alice, charlie, amount);
    }

    function test_RevertWhen_TransferFromNoAllowance() public {
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(ERC20Facet.ERC20InsufficientAllowance.selector, bob, 0, 100e18));
        token.transferFrom(alice, charlie, 100e18);
    }

    // ============================================
    // Burn Tests
    // ============================================

    function test_Burn() public {
        uint256 amount = 100e18;

        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit Transfer(alice, address(0), amount);
        token.burn(amount);

        assertEq(token.balanceOf(alice), INITIAL_SUPPLY - amount);
        assertEq(token.totalSupply(), INITIAL_SUPPLY - amount);
    }

    function test_Burn_EntireBalance() public {
        vm.prank(alice);
        token.burn(INITIAL_SUPPLY);

        assertEq(token.balanceOf(alice), 0);
        assertEq(token.totalSupply(), 0);
    }

    function test_Fuzz_Burn(uint256 amount) public {
        vm.assume(amount <= INITIAL_SUPPLY);

        vm.prank(alice);
        token.burn(amount);

        assertEq(token.balanceOf(alice), INITIAL_SUPPLY - amount);
        assertEq(token.totalSupply(), INITIAL_SUPPLY - amount);
    }

    function test_RevertWhen_BurnInsufficientBalance() public {
        uint256 amount = INITIAL_SUPPLY + 1;

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(ERC20Facet.ERC20InsufficientBalance.selector, alice, INITIAL_SUPPLY, amount)
        );
        token.burn(amount);
    }

    function test_RevertWhen_BurnFromZeroBalance() public {
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(ERC20Facet.ERC20InsufficientBalance.selector, bob, 0, 1));
        token.burn(1);
    }

    // ============================================
    // BurnFrom Tests
    // ============================================

    function test_BurnFrom() public {
        uint256 amount = 100e18;

        vm.prank(alice);
        token.approve(bob, amount);

        vm.prank(bob);
        vm.expectEmit(true, true, true, true);
        emit Transfer(alice, address(0), amount);
        token.burnFrom(alice, amount);

        assertEq(token.balanceOf(alice), INITIAL_SUPPLY - amount);
        assertEq(token.allowance(alice, bob), 0);
        assertEq(token.totalSupply(), INITIAL_SUPPLY - amount);
    }

    function test_BurnFrom_PartialAllowance() public {
        uint256 allowanceAmount = 200e18;
        uint256 burnAmount = 100e18;

        vm.prank(alice);
        token.approve(bob, allowanceAmount);

        vm.prank(bob);
        token.burnFrom(alice, burnAmount);

        assertEq(token.balanceOf(alice), INITIAL_SUPPLY - burnAmount);
        assertEq(token.allowance(alice, bob), allowanceAmount - burnAmount);
        assertEq(token.totalSupply(), INITIAL_SUPPLY - burnAmount);
    }

    function test_Fuzz_BurnFrom(uint256 approval, uint256 amount) public {
        vm.assume(approval <= INITIAL_SUPPLY);
        vm.assume(amount <= approval);

        vm.prank(alice);
        token.approve(bob, approval);

        vm.prank(bob);
        token.burnFrom(alice, amount);

        assertEq(token.balanceOf(alice), INITIAL_SUPPLY - amount);
        assertEq(token.allowance(alice, bob), approval - amount);
        assertEq(token.totalSupply(), INITIAL_SUPPLY - amount);
    }

    function test_BurnFrom_UnlimitedAllowance() public {
        uint256 amount = 100e18;
        uint256 maxAllowance = type(uint256).max;

        // Set unlimited allowance
        vm.prank(alice);
        token.approve(bob, maxAllowance);

        // Perform first burn
        vm.prank(bob);
        token.burnFrom(alice, amount);

        // Check that allowance remains unchanged (unlimited)
        assertEq(token.allowance(alice, bob), maxAllowance);
        assertEq(token.balanceOf(alice), INITIAL_SUPPLY - amount);
        assertEq(token.totalSupply(), INITIAL_SUPPLY - amount);

        // Perform second burn to verify allowance is still unlimited
        vm.prank(bob);
        token.burnFrom(alice, amount);

        // Check that allowance is still unchanged (unlimited)
        assertEq(token.allowance(alice, bob), maxAllowance);
        assertEq(token.balanceOf(alice), INITIAL_SUPPLY - 2 * amount);
        assertEq(token.totalSupply(), INITIAL_SUPPLY - 2 * amount);
    }

    function test_BurnFrom_UnlimitedAllowance_MultipleBurns() public {
        uint256 maxAllowance = type(uint256).max;
        uint256 burnAmount = 50e18;
        uint256 numBurns = 10;

        // Set unlimited allowance
        vm.prank(alice);
        token.approve(bob, maxAllowance);

        // Perform multiple burns
        for (uint256 i = 0; i < numBurns; i++) {
            vm.prank(bob);
            token.burnFrom(alice, burnAmount);

            // Verify allowance remains unlimited after each burn
            assertEq(token.allowance(alice, bob), maxAllowance);
        }

        // Verify final balances and total supply
        assertEq(token.balanceOf(alice), INITIAL_SUPPLY - (burnAmount * numBurns));
        assertEq(token.totalSupply(), INITIAL_SUPPLY - (burnAmount * numBurns));
    }

    function test_RevertWhen_BurnFromInsufficientAllowance() public {
        uint256 allowanceAmount = 50e18;
        uint256 burnAmount = 100e18;

        vm.prank(alice);
        token.approve(bob, allowanceAmount);

        vm.prank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(ERC20Facet.ERC20InsufficientAllowance.selector, bob, allowanceAmount, burnAmount)
        );
        token.burnFrom(alice, burnAmount);
    }

    function test_RevertWhen_BurnFromInsufficientBalance() public {
        uint256 amount = INITIAL_SUPPLY + 1;

        vm.prank(alice);
        token.approve(bob, amount);

        vm.prank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(ERC20Facet.ERC20InsufficientBalance.selector, alice, INITIAL_SUPPLY, amount)
        );
        token.burnFrom(alice, amount);
    }

    function test_RevertWhen_BurnFromNoAllowance() public {
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(ERC20Facet.ERC20InsufficientAllowance.selector, bob, 0, 100e18));
        token.burnFrom(alice, 100e18);
    }

    // ============================================
    // EIP-2612 Permit Tests
    // ============================================

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
            abi.encodeWithSelector(ERC20Facet.ERC2612InvalidSignature.selector, owner, bob, value, deadline, v, r, s)
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
            abi.encodeWithSelector(ERC20Facet.ERC2612InvalidSignature.selector, owner, bob, value, deadline, v, r, s)
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
            abi.encodeWithSelector(ERC20Facet.ERC2612InvalidSignature.selector, owner, bob, value, deadline, v, r, s)
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

        vm.expectRevert(abi.encodeWithSelector(ERC20Facet.ERC20InvalidSpender.selector, address(0)));
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
            abi.encodeWithSelector(ERC20Facet.ERC2612InvalidSignature.selector, owner, bob, value, deadline, v, r, s)
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
            abi.encodeWithSelector(ERC20Facet.ERC2612InvalidSignature.selector, owner, bob, value, deadline, 99, r, s)
        );
        token.permit(owner, bob, value, deadline, 99, r, s);

        // Test with zero r value
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC20Facet.ERC2612InvalidSignature.selector, owner, bob, value, deadline, v, bytes32(0), s
            )
        );
        token.permit(owner, bob, value, deadline, v, bytes32(0), s);

        // Test with zero s value
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC20Facet.ERC2612InvalidSignature.selector, owner, bob, value, deadline, v, r, bytes32(0)
            )
        );
        token.permit(owner, bob, value, deadline, v, r, bytes32(0));
    }

    function test_Fuzz_Permit(uint256 ownerKey, address spender, uint256 value, uint256 deadline) public {
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
