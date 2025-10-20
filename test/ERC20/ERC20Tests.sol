// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {ERC20Facet} from "../../src/ERC20/ERC20/ERC20Facet.sol";
import {ERC20Mock} from "./ERC20Mock.sol";

/// @title ERC20Tests
/// @notice Tests for the ERC20 implementation following Compose's philosophy.
/// @dev Tests use alice, bob, and charlie as standard test addresses.
contract ERC20Tests is Test{
    ERC20Mock public token;

    // test addresses
    address public alice;
    address public bob;
    address public charlie;

    // constants (token parameters)
    string constant TOKEN_NAME = "Test Token";
    string constant TOKEN_SYMBOL = "TEST";
    uint8 constant TOKEN_DECIMALS = 18;
    uint256 constant INITIAL_SUPPLY = 1_000_000 * 10**18; // 1 million tokens

    /// @notice Sets up the test environment before each test.
    /// @dev Deploys fresh instance of ERC20Mock (which extends ERC20Facet).
    ///      Initializes token parameters and mints initial supply to alice.
    ///      Creates deterministic addresses for alice, bob, and charlie.
    function setUp() public {
        // test addresses
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");

        // deploy contract
        token = new ERC20Mock();

        // initialize token parameters
        token.initialize(TOKEN_NAME, TOKEN_SYMBOL, TOKEN_DECIMALS);

        // mint initial supply to alice
        token.mint(alice, INITIAL_SUPPLY);
    }


    // ===================== Metadata Tests =======================

    /// @notice Tests that the token name is correctly set and retrievable.
    /// @dev Verifies the name() view function works as expected.
    function test_Name() public view {
        assertEq(token.name(), TOKEN_NAME);
    }

    /// @notice Tests that the token symbol is correctly set and retrievable.
    /// @dev Verifies the symbol() view function works as expected.
    function test_Symbol() public view {
        assertEq(token.symbol(), TOKEN_SYMBOL);
    }

    /// @notice Tests that the token decimals are correctly set and retrievable.
    /// @dev Verifies the decimals() view function works as expected.
    function test_Decimals() public view {
        assertEq(token.decimals(), TOKEN_DECIMALS);
    }

    /// @notice Tests that the total supply reflects minted tokens.
    /// @dev Initial supply was minted to alice in setUp().
    function test_TotalSupply() public view {
        assertEq(token.totalSupply(), INITIAL_SUPPLY);
    }

    /// @notice Tests that alice's balance matches the initial supply.
    /// @dev Alice received all tokens in setUp().
    function test_InitialBalance() public view {
        assertEq(token.balanceOf(alice), INITIAL_SUPPLY);
    }

    // ==================== Transfer Tests ========================

    /// @notice Tests a successful token transfer from alice to bob.
    /// @dev Verifies balances are updated correctly and Transfer event is emitted.
    function test_Transfer() public {
        uint256 amount = 1000 * 10**18;

        // alice's balance before transfer
        uint256 aliceBalanceBefore = token.balanceOf(alice);

        // expect transfer event emission
        vm.expectEmit(true, true, false, true);
        emit ERC20Facet.Transfer(alice, bob, amount);

        // Alice transfers tokens to bob
        vm.prank(alice);
        token.transfer(bob, amount);

        // verify balances are updated correctly
        assertEq(token.balanceOf(alice), aliceBalanceBefore - amount);
        assertEq(token.balanceOf(bob), amount);
    }

    /// @notice Tests transfering entire balance.
    /// @dev Edge case: sender should have zero balance after transfer.
    function test_TransferEntireBalance() public {
        uint256 aliceBalance = token.balanceOf(alice);

        vm.prank(alice);
        token.transfer(bob, aliceBalance);

        assertEq(token.balanceOf(alice), 0);
        assertEq(token.balanceOf(bob), aliceBalance);
    }

    /// @notice Tests transfering zero tokens.
    /// @dev Edge case: should succeed but not change balances.
    function test_TransferZeroAmount() public {
        uint256 aliceBalanceBefore = token.balanceOf(alice);
        uint256 bobBalanceBefore = token.balanceOf(bob);

        vm.prank(alice);
        token.transfer(bob, 0);

        assertEq(token.balanceOf(alice), aliceBalanceBefore);
        assertEq(token.balanceOf(bob), bobBalanceBefore);
    }

    /// @notice Tests that transfer to zero address reverts.
    /// @dev Security: prevents accidental token burning via transfer.
    function test_TransferToZeroAddressReverts() public {
        uint256 amount = 100 * 10**18;

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC20Facet.ERC20InvalidReceiver.selector,
                address(0)
            )
        );
        token.transfer(address(0), amount);
    }

    /// @notice Tests that transfer with insufficient balance reverts.
    /// @dev Security: prevents overdraft.
    function test_TransferInsufficientBalanceReverts() public {
        uint256 bobBalance = token.balanceOf(bob);
        uint256 transferAmount = bobBalance + 1;

        vm.prank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC20Facet.ERC20InsufficientBalance.selector,
                bob,
                bobBalance,
                transferAmount
            )
        );
        token.transfer(alice, transferAmount);
    }

    // =============== Approve And Allowance Tests =============================

    /// @notice Tests setting allowance via approve().
    /// @dev Verifies Approval event is emitted and allowance is set correctly.
    function test_Approve() public {
        uint256 amount = 500 * 10**18;

        // expect approval event
        vm.expectEmit(true, true, false, true);
        emit ERC20Facet.Approval(alice, bob, amount);

        // Alice approves bob to spend tokens
        vm.prank(alice);
        token.approve(bob, amount);

        // verify allowance
        assertEq(token.allowance(alice, bob), amount);
    }

    /// @notice Tests approving zero amount.
    /// @dev Edge case: useful for revoking approvals.
    function test_ApproveZeroAmount() public {
        vm.prank(alice);
        token.approve(bob, 0);

        assertEq(token.allowance(alice, bob), 0);
    }

    /// @notice Tests that approving maximum uint256 works.
    /// @dev Edge case: common pattern for unlimited approval.
    function test_ApproveMaxAmount() public {
        uint256 maxAmount = type(uint256).max;

        vm.prank(alice);
        token.approve(bob, maxAmount);

        assertEq(token.allowance(alice, bob), maxAmount);
    }

    /// @notice Tests that approve overwrites previous allowance.
    /// @dev Important: new approval replaces old one, doesn't add to it.
    function test_ApproveOverwrite() public {
        uint256 firstAmount = 100 * 10**18;
        uint256 secondAmount = 200 * 10**18;

        vm.startPrank(alice);
        token.approve(bob, firstAmount);
        assertEq(token.allowance(alice, bob), firstAmount);

        token.approve(bob, secondAmount);
        assertEq(token.allowance(alice, bob), secondAmount);
        vm.stopPrank();
    }

    /// @notice Tests that approving zero address as spender reverts.
    /// @dev Security: prevents accidental approval to invalid address.
    function test_ApproveZeroAddressReverts() public {
        uint256 amount = 100 * 10**18;

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC20Facet.ERC20InvalidSpender.selector,
                address(0)
            )
        );
        token.approve(address(0), amount);
    }

    // =================== transferFrom tests =========================

    /// @notice Tests successful transferFrom after approval.
    /// @dev Verifies allowance is decreased and balances are updated.
    function test_TransferFrom() public {
        uint256 approvalAmount = 1000 * 10**18;
        uint256 transferAmount = 500 * 10**18;

        // Alice approves bob
        vm.prank(alice);
        token.approve(bob, approvalAmount);

        uint256 aliceBalanceBefore = token.balanceOf(alice);
        uint256 charlieBalanceBefore = token.balanceOf(charlie);

        // Bob transfers from alice to charlie
        vm.expectEmit(true, true, false, true);
        emit ERC20Facet.Transfer(alice, charlie, transferAmount);

        vm.prank(bob);
        token.transferFrom(alice, charlie, transferAmount);

        // verify balances
        assertEq(token.balanceOf(alice), aliceBalanceBefore - transferAmount);
        assertEq(token.balanceOf(charlie), charlieBalanceBefore + transferAmount);

        // verify allowance decreased
        assertEq(token.allowance(alice, bob), approvalAmount - transferAmount);
    }

    /// @notice Tests transferFrom using entire allowance.
    /// @dev Edge case: allowance should be zero after.
    function test_TransferFromEntireAllowance() public {
        uint256 amount = 500 * 10**18;

        vm.prank(alice);
        token.approve(bob, amount);

        vm.prank(bob);
        token.transferFrom(alice, charlie, amount);

        assertEq(token.allowance(alice, bob), 0);
        assertEq(token.balanceOf(charlie), amount);
    }

    /// @notice Tests that transferFrom with insufficient allowance reverts.
    /// @dev Security: prevents unauthorized spending beyond approval.
    function test_TransferFromInsufficientAllowanceReverts() public {
        uint256 approvalAmount = 100 * 10**18;
        uint256 transferAmount = 200 * 10**18;

        vm.prank(alice);
        token.approve(bob, approvalAmount);

        vm.prank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC20Facet.ERC20InsufficientAllowance.selector,
                bob,
                approvalAmount,
                transferAmount
            )
        );
        token.transferFrom(alice, charlie, transferAmount);
    }

    /// @notice Tests that transferFrom with insufficient balance reverts.
    /// @dev Security: checks balance even if allowance is sufficient.
    function test_TransferFromInsufficientBalanceReverts() public {
        uint256 aliceBalance = token.balanceOf(alice);
        uint256 transferAmount = aliceBalance + 1;

        // Bob gets approval for more than alice's balance
        vm.prank(alice);
        token.approve(bob, transferAmount);

        vm.prank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC20Facet.ERC20InsufficientBalance.selector,
                alice,
                aliceBalance,
                transferAmount
            )
        );
        token.transferFrom(alice, charlie, transferAmount);
    }

    /// @notice Tests that transferFrom from zero address reverts.
    /// @dev Security: prevents invalid sender.
    function test_TransferFromZeroAddressSenderReverts() public {
        uint256 amount = 100 * 10**18;

        vm.prank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC20Facet.ERC20InvalidSender.selector,
                address(0)
            )
        );
        token.transferFrom(address(0), charlie, amount);
    }

    /// @notice Tests that transferFrom to zero address reverts.
    /// @dev Security: prevents invalid receiver.
    function test_TransferFromZeroAddressReceiverReverts() public {
        uint256 amount = 100 * 10**18;

        vm.prank(alice);
        token.approve(bob, amount);

        vm.prank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC20Facet.ERC20InvalidReceiver.selector,
                address(0)
            )
        );
        token.transferFrom(alice, address(0), amount);
    }


    // =================== Burn and BurnFrom tests =========================

    /// @notice Tests burning tokens from caller's balance.
    /// @dev Verifies total supply decreases and Transfer to zero address is emitted.
    function test_Burn() public {
        uint256 burnAmount = 100 * 10**18;
        uint256 aliceBalanceBefore = token.balanceOf(alice);
        uint256 totalSupplyBefore = token.totalSupply();

        // expect transfer to zero address
        vm.expectEmit(true, true, false, true);
        emit ERC20Facet.Transfer(alice, address(0), burnAmount);

        vm.prank(alice);
        token.burn(burnAmount);

        // verify balance decreased
        assertEq(token.balanceOf(alice), aliceBalanceBefore - burnAmount);

        // Note: totalSupply is NOT decreased in burn() external function
        assertEq(token.totalSupply(), totalSupplyBefore);
    }

    /// @notice Tests burning entire balance.
    /// @dev Edge case: caller should have zero balance after.
    function test_BurnEntireBalance() public {
        uint256 aliceBalance = token.balanceOf(alice);

        vm.prank(alice);
        token.burn(aliceBalance);

        assertEq(token.balanceOf(alice), 0);
    }

    /// @notice Tests that burning more than balance reverts.
    /// @dev Security: prevents burning tokens you don't have.
    function test_BurnInsufficientBalanceReverts() public {
        uint256 aliceBalance = token.balanceOf(alice);
        uint256 burnAmount = aliceBalance + 1;

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC20Facet.ERC20InsufficientBalance.selector,
                alice,
                aliceBalance,
                burnAmount
            )
        );
        token.burn(burnAmount);
    }

    /// @notice Tests burning tokens from another account with approval.
    /// @dev Verifies allowance is decreased and tokens are burned.
    function test_BurnFrom() public {
        uint256 approvalAmount = 500 * 10**18;
        uint256 burnAmount = 200 * 10**18;

        // Alice approves bob to burn her tokens
        vm.prank(alice);
        token.approve(bob, approvalAmount);

        uint256 aliceBalanceBefore = token.balanceOf(alice);

        // Bob burns alice's tokens
        vm.expectEmit(true, true, false, true);
        emit ERC20Facet.Transfer(bob, address(0), burnAmount);

        vm.prank(bob);
        token.burnFrom(alice, burnAmount);

        // alice's balance decreased
        assertEq(token.balanceOf(alice), aliceBalanceBefore - burnAmount);

        // verify allowance decreased
        assertEq(token.allowance(alice, bob), approvalAmount - burnAmount);
    }

    /// @notice Tests burning entire allowance.
    /// @dev Edge case: allowance should be zero after.
    function test_BurnFromEntireAllowance() public {
        uint256 amount = 300 * 10**18;

        vm.prank(alice);
        token.approve(bob, amount);

        vm.prank(bob);
        token.burnFrom(alice, amount);

        assertEq(token.allowance(alice, bob), 0);
    }

    /// @notice Tests that burnFrom with insufficient allowance reverts.
    /// @dev Security: prevents unauthorized burning beyond approval.
    function test_BurnFromInsufficientAllowanceReverts() public {
        uint256 approvalAmount = 100 * 10**18;
        uint256 burnAmount = 200 * 10**18;

        vm.prank(alice);
        token.approve(bob, approvalAmount);

        vm.prank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC20Facet.ERC20InsufficientAllowance.selector,
                bob,
                approvalAmount,
                burnAmount
            )
        );
        token.burnFrom(alice, burnAmount);
    }

    /// @notice Tests that burnFrom with insufficient balance reverts.
    /// @dev Security: can't burn more than account owns.
    function test_BurnFromInsufficientBalanceReverts() public {
        uint256 aliceBalance = token.balanceOf(alice);
        uint256 burnAmount = aliceBalance + 1;

        vm.prank(alice);
        token.approve(bob, burnAmount);

        vm.prank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC20Facet.ERC20InsufficientBalance.selector,
                alice,
                aliceBalance,
                burnAmount
            )
        );
        token.burnFrom(alice, burnAmount);
    }

    
    // =================== EIP-2612 PERMIT TESTS ==========================

    /// @notice Tests the nonces() view function returns initial nonce.
    /// @dev Initial nonce should be 0 for all addresses.
    function test_Nonces_Initial() public view {
        assertEq(token.nonces(alice), 0);
        assertEq(token.nonces(bob), 0);
        assertEq(token.nonces(charlie), 0);
    }

    /// @notice Tests the DOMAIN_SEPARATOR() view function.
    /// @dev Domain separator should be consistent and deterministic.
    function test_DomainSeparator() public view {
        bytes32 separator = token.DOMAIN_SEPARATOR();

        // verify it's not zero
        assertTrue(separator != bytes32(0));

        // verify it's consistent across calls
        assertEq(token.DOMAIN_SEPARATOR(), separator);
    }

    /// @notice Tests valid permit with correct signature.
    /// @dev gasless approvals via EIP-2612.
    function test_Permit_ValidSignature() public {
        // private key for alice
        uint256 alicePrivateKey = 0xA11CE;
        address aliceAddress = vm.addr(alicePrivateKey);

        // Mint tokens to alice
        token.mint(aliceAddress, 1000 * 10**18);

        uint256 value = 500 * 10**18;
        uint256 deadline = block.timestamp + 1 days;
        uint256 nonce = token.nonces(aliceAddress);

        // Create the permit digest
        bytes32 domainSeparator = token.DOMAIN_SEPARATOR();
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                aliceAddress,
                bob,
                value,
                nonce,
                deadline
            )
        );
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, structHash)
        );

        // sign the digest
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePrivateKey, digest);

        // expect Approval event
        vm.expectEmit(true, true, false, true);
        emit ERC20Facet.Approval(aliceAddress, bob, value);

        // execute permit
        token.permit(aliceAddress, bob, value, deadline, v, r, s);

        // verify allowance was set
        assertEq(token.allowance(aliceAddress, bob), value);

        // verify nonce was incremented
        assertEq(token.nonces(aliceAddress), nonce + 1);
    }

    /// @notice Tests permit with expired deadline reverts.
    /// @dev Security: prevents replay of old signatures.
    function test_Permit_ExpiredDeadlineReverts() public {
        uint256 alicePrivateKey = 0xA11CE;
        address aliceAddress = vm.addr(alicePrivateKey);

        uint256 value = 500 * 10**18;
        uint256 deadline = block.timestamp - 1; // already expired
        uint256 nonce = token.nonces(aliceAddress);

        // create signature (though expired)
        bytes32 domainSeparator = token.DOMAIN_SEPARATOR();
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                aliceAddress,
                bob,
                value,
                nonce,
                deadline
            )
        );
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, structHash)
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePrivateKey, digest);

        // should revert with ERC2612InvalidSignature
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC20Facet.ERC2612InvalidSignature.selector,
                aliceAddress,
                bob,
                value,
                deadline,
                v,
                r,
                s
            )
        );
        token.permit(aliceAddress, bob, value, deadline, v, r, s);
    }

    /// @notice Tests permit with invalid signature reverts.
    /// @dev Security: prevents unauthorized approvals.
    function test_Permit_InvalidSignatureReverts() public {
        uint256 alicePrivateKey = 0xA11CE;
        address aliceAddress = vm.addr(alicePrivateKey);

        uint256 bobPrivateKey = 0xB0B;

        uint256 value = 500 * 10**18;
        uint256 deadline = block.timestamp + 1 days;
        uint256 nonce = token.nonces(aliceAddress);

        // Create digest for alice
        bytes32 domainSeparator = token.DOMAIN_SEPARATOR();
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                aliceAddress,
                bob,
                value,
                nonce,
                deadline
            )
        );
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, structHash)
        );

        // sign with bob's key instead of alice's (wrong signer)
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(bobPrivateKey, digest);

        // should revert because signer doesn't match owner
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC20Facet.ERC2612InvalidSignature.selector,
                aliceAddress,
                bob,
                value,
                deadline,
                v,
                r,
                s
            )
        );
        token.permit(aliceAddress, bob, value, deadline, v, r, s);
    }

    /// @notice Tests permit with incorrect nonce reverts.
    /// @dev Security: prevents replay attacks with old nonces.
    function test_Permit_WrongNonceReverts() public {
        uint256 alicePrivateKey = 0xA11CE;
        address aliceAddress = vm.addr(alicePrivateKey);

        uint256 value = 500 * 10**18;
        uint256 deadline = block.timestamp + 1 days;
        uint256 wrongNonce = 99; // wrong nonce

        // create signature with wrong nonce
        bytes32 domainSeparator = token.DOMAIN_SEPARATOR();
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                aliceAddress,
                bob,
                value,
                wrongNonce,
                deadline
            )
        );
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, structHash)
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePrivateKey, digest);

        // should revert because nonce doesn't match
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC20Facet.ERC2612InvalidSignature.selector,
                aliceAddress,
                bob,
                value,
                deadline,
                v,
                r,
                s
            )
        );
        token.permit(aliceAddress, bob, value, deadline, v, r, s);
    }

    /// @notice Tests multiple permits increment nonce correctly.
    /// @dev Each successful permit should increment nonce by 1.
    function test_Permit_NonceIncrement() public {
        uint256 alicePrivateKey = 0xA11CE;
        address aliceAddress = vm.addr(alicePrivateKey);

        uint256 value = 500 * 10**18;
        uint256 deadline = block.timestamp + 1 days;

        // First permit
        assertEq(token.nonces(aliceAddress), 0);

        {
            bytes32 domainSeparator = token.DOMAIN_SEPARATOR();
            bytes32 structHash = keccak256(
                abi.encode(
                    keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                    aliceAddress,
                    bob,
                    value,
                    0, // nonce
                    deadline
                )
            );
            bytes32 digest = keccak256(
                abi.encodePacked("\x19\x01", domainSeparator, structHash)
            );
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePrivateKey, digest);
            token.permit(aliceAddress, bob, value, deadline, v, r, s);
        }

        assertEq(token.nonces(aliceAddress), 1);

        // second permit
        {
            bytes32 domainSeparator = token.DOMAIN_SEPARATOR();
            bytes32 structHash = keccak256(
                abi.encode(
                    keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                    aliceAddress,
                    charlie,
                    value,
                    1, // nonce
                    deadline
                )
            );
            bytes32 digest = keccak256(
                abi.encodePacked("\x19\x01", domainSeparator, structHash)
            );
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePrivateKey, digest);
            token.permit(aliceAddress, charlie, value, deadline, v, r, s);
        }

        assertEq(token.nonces(aliceAddress), 2);
    }

    /// @notice Tests permit then transferFrom integration.
    /// @dev verifies permit creates allowance that can be used in transferFrom.
    function test_Permit_ThenTransferFrom() public {
        uint256 alicePrivateKey = 0xA11CE;
        address aliceAddress = vm.addr(alicePrivateKey);

        // mint tokens to alice
        uint256 balance = 1000 * 10**18;
        token.mint(aliceAddress, balance);

        uint256 value = 500 * 10**18;
        uint256 deadline = block.timestamp + 1 days;
        uint256 nonce = token.nonces(aliceAddress);

        // create permit signature
        bytes32 domainSeparator = token.DOMAIN_SEPARATOR();
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                aliceAddress,
                bob,
                value,
                nonce,
                deadline
            )
        );
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, structHash)
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePrivateKey, digest);

        // execute permit
        token.permit(aliceAddress, bob, value, deadline, v, r, s);

        // bob can use transferFrom
        uint256 transferAmount = 300 * 10**18;
        vm.prank(bob);
        token.transferFrom(aliceAddress, charlie, transferAmount);

        // verify transfer succeeded
        assertEq(token.balanceOf(aliceAddress), balance - transferAmount);
        assertEq(token.balanceOf(charlie), transferAmount);
        assertEq(token.allowance(aliceAddress, bob), value - transferAmount);
    }

    /// @notice Tests permit with maximum uint256 value.
    /// @dev Edge case: unlimited approval via permit.
    function test_Permit_MaxValue() public {
        uint256 alicePrivateKey = 0xA11CE;
        address aliceAddress = vm.addr(alicePrivateKey);

        uint256 value = type(uint256).max;
        uint256 deadline = block.timestamp + 1 days;
        uint256 nonce = token.nonces(aliceAddress);

        bytes32 domainSeparator = token.DOMAIN_SEPARATOR();
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                aliceAddress,
                bob,
                value,
                nonce,
                deadline
            )
        );
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, structHash)
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePrivateKey, digest);

        token.permit(aliceAddress, bob, value, deadline, v, r, s);

        assertEq(token.allowance(aliceAddress, bob), type(uint256).max);
    }

    /// @notice Tests permit at exact deadline boundary.
    /// @dev Edge case: permit should succeed when block.timestamp == deadline.
    function test_Permit_AtDeadline() public {
        uint256 alicePrivateKey = 0xA11CE;
        address aliceAddress = vm.addr(alicePrivateKey);

        uint256 value = 500 * 10**18;
        uint256 deadline = block.timestamp; // Exact current time
        uint256 nonce = token.nonces(aliceAddress);

        bytes32 domainSeparator = token.DOMAIN_SEPARATOR();
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                aliceAddress,
                bob,
                value,
                nonce,
                deadline
            )
        );
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, structHash)
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePrivateKey, digest);

        // should succeed at exact deadline
        token.permit(aliceAddress, bob, value, deadline, v, r, s);
        assertEq(token.allowance(aliceAddress, bob), value);
    }

}