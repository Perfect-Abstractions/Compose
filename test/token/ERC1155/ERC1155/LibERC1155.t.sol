// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {Test} from "forge-std/Test.sol";
import {LibERC1155Harness} from "./harnesses/LibERC1155Harness.sol";
import {LibERC1155} from "../../../../src/token/ERC1155/LibERC1155.sol";
import {ERC1155ReceiverMock} from "./mocks/ERC1155ReceiverMock.sol";

contract LibERC1155Test is Test {
    LibERC1155Harness public harness;

    address public alice;
    address public bob;
    address public charlie;

    string constant DEFAULT_URI = "https://token.uri/{id}.json";
    string constant BASE_URI = "https://base.uri/";
    string constant TOKEN_URI = "token1.json";

    uint256 constant TOKEN_ID_1 = 1;
    uint256 constant TOKEN_ID_2 = 2;
    uint256 constant TOKEN_ID_3 = 3;

    bytes4 constant RECEIVER_SINGLE_MAGIC_VALUE = 0xf23a6e61; // bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))
    bytes4 constant RECEIVER_BATCH_MAGIC_VALUE = 0xbc197c81; // bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))

    event TransferSingle(
        address indexed _operator, address indexed _from, address indexed _to, uint256 _id, uint256 _value
    );
    event TransferBatch(
        address indexed _operator, address indexed _from, address indexed _to, uint256[] _ids, uint256[] _values
    );
    event ApprovalForAll(address indexed _account, address indexed _operator, bool _approved);
    event URI(string _value, uint256 indexed _id);

    function setUp() public {
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");

        harness = new LibERC1155Harness();
        harness.initialize(DEFAULT_URI);
    }

    // ============================================
    // URI Tests
    // ============================================

    function test_Uri_DefaultUri() public view {
        assertEq(harness.uri(TOKEN_ID_1), DEFAULT_URI);
    }

    function test_Uri_SetBaseURI() public {
        harness.setBaseURI(BASE_URI);
        harness.setTokenURI(TOKEN_ID_1, TOKEN_URI);
        assertEq(harness.uri(TOKEN_ID_1), string.concat(BASE_URI, TOKEN_URI));
    }

    function test_Uri_SetTokenURI() public {
        vm.expectEmit(true, true, true, true);
        emit URI(TOKEN_URI, TOKEN_ID_1);
        harness.setTokenURI(TOKEN_ID_1, TOKEN_URI);
    }

    // ============================================
    // Mint Tests
    // ============================================

    function test_Mint() public {
        uint256 amount = 100;

        vm.expectEmit(true, true, true, true);
        emit TransferSingle(address(this), address(0), alice, TOKEN_ID_1, amount);
        harness.mint(alice, TOKEN_ID_1, amount);

        assertEq(harness.balanceOf(alice, TOKEN_ID_1), amount);
    }

    function test_Mint_Multiple() public {
        harness.mint(alice, TOKEN_ID_1, 100);
        harness.mint(bob, TOKEN_ID_1, 200);
        harness.mint(alice, TOKEN_ID_2, 50);

        assertEq(harness.balanceOf(alice, TOKEN_ID_1), 100);
        assertEq(harness.balanceOf(bob, TOKEN_ID_1), 200);
        assertEq(harness.balanceOf(alice, TOKEN_ID_2), 50);
    }

    function test_Mint_SameTokenMultipleTimes() public {
        harness.mint(alice, TOKEN_ID_1, 100);
        harness.mint(alice, TOKEN_ID_1, 50);

        assertEq(harness.balanceOf(alice, TOKEN_ID_1), 150);
    }

    function testFuzz_Mint(address to, uint256 id, uint256 amount) public {
        vm.assume(to != address(0));
        vm.assume(to.code.length == 0);
        vm.assume(amount < type(uint256).max / 2);

        harness.mint(to, id, amount);

        assertEq(harness.balanceOf(to, id), amount);
    }

    function test_RevertWhen_MintToZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(LibERC1155.ERC1155InvalidReceiver.selector, address(0)));
        harness.mint(address(0), TOKEN_ID_1, 100);
    }

    // ============================================
    // MintBatch Tests
    // ============================================

    function test_MintBatch() public {
        uint256[] memory ids = new uint256[](3);
        ids[0] = TOKEN_ID_1;
        ids[1] = TOKEN_ID_2;
        ids[2] = TOKEN_ID_3;

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 100;
        amounts[1] = 200;
        amounts[2] = 300;

        vm.expectEmit(true, true, true, true);
        emit TransferBatch(address(this), address(0), alice, ids, amounts);
        harness.mintBatch(alice, ids, amounts);

        assertEq(harness.balanceOf(alice, TOKEN_ID_1), 100);
        assertEq(harness.balanceOf(alice, TOKEN_ID_2), 200);
        assertEq(harness.balanceOf(alice, TOKEN_ID_3), 300);
    }

    function test_RevertWhen_MintBatchToZeroAddress() public {
        uint256[] memory ids = new uint256[](1);
        ids[0] = TOKEN_ID_1;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 100;

        vm.expectRevert(abi.encodeWithSelector(LibERC1155.ERC1155InvalidReceiver.selector, address(0)));
        harness.mintBatch(address(0), ids, amounts);
    }

    function test_RevertWhen_MintBatchArrayLengthMismatch() public {
        uint256[] memory ids = new uint256[](2);
        ids[0] = TOKEN_ID_1;
        ids[1] = TOKEN_ID_2;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 100;

        vm.expectRevert(abi.encodeWithSelector(LibERC1155.ERC1155InvalidArrayLength.selector, 2, 1));
        harness.mintBatch(alice, ids, amounts);
    }

    function test_MintBatch_EmptyArrays() public {
        uint256[] memory ids = new uint256[](0);
        uint256[] memory amounts = new uint256[](0);

        harness.mintBatch(alice, ids, amounts);
        // Should not revert
    }

    function test_Mint_ToReceiverContract() public {
        ERC1155ReceiverMock receiver = new ERC1155ReceiverMock(
            RECEIVER_SINGLE_MAGIC_VALUE, RECEIVER_BATCH_MAGIC_VALUE, ERC1155ReceiverMock.RevertType.None
        );

        harness.mint(address(receiver), TOKEN_ID_1, 100);
        assertEq(harness.balanceOf(address(receiver), TOKEN_ID_1), 100);
    }

    function test_RevertWhen_Mint_ToReceiverContractWithWrongReturnValue() public {
        ERC1155ReceiverMock receiver =
            new ERC1155ReceiverMock(0x00c0ffee, RECEIVER_BATCH_MAGIC_VALUE, ERC1155ReceiverMock.RevertType.None);

        vm.expectRevert(abi.encodeWithSelector(LibERC1155.ERC1155InvalidReceiver.selector, address(receiver)));
        harness.mint(address(receiver), TOKEN_ID_1, 100);
    }

    function test_RevertWhen_Mint_ToReceiverContractWithRevert() public {
        ERC1155ReceiverMock receiver = new ERC1155ReceiverMock(
            RECEIVER_SINGLE_MAGIC_VALUE, RECEIVER_BATCH_MAGIC_VALUE, ERC1155ReceiverMock.RevertType.RevertWithMessage
        );

        vm.expectRevert("ERC1155ReceiverMock: reverting on receive");
        harness.mint(address(receiver), TOKEN_ID_1, 100);
    }

    function test_MintBatch_ToReceiverContract() public {
        ERC1155ReceiverMock receiver = new ERC1155ReceiverMock(
            RECEIVER_SINGLE_MAGIC_VALUE, RECEIVER_BATCH_MAGIC_VALUE, ERC1155ReceiverMock.RevertType.None
        );

        uint256[] memory ids = new uint256[](2);
        ids[0] = TOKEN_ID_1;
        ids[1] = TOKEN_ID_2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100;
        amounts[1] = 200;

        harness.mintBatch(address(receiver), ids, amounts);
        assertEq(harness.balanceOf(address(receiver), TOKEN_ID_1), 100);
        assertEq(harness.balanceOf(address(receiver), TOKEN_ID_2), 200);
    }

    function test_RevertWhen_MintBatch_ToReceiverContractWithWrongReturnValue() public {
        ERC1155ReceiverMock receiver = new ERC1155ReceiverMock(
            RECEIVER_SINGLE_MAGIC_VALUE, RECEIVER_SINGLE_MAGIC_VALUE, ERC1155ReceiverMock.RevertType.None
        );

        uint256[] memory ids = new uint256[](1);
        ids[0] = TOKEN_ID_1;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 100;

        vm.expectRevert(abi.encodeWithSelector(LibERC1155.ERC1155InvalidReceiver.selector, address(receiver)));
        harness.mintBatch(address(receiver), ids, amounts);
    }

    // ============================================
    // Burn Tests
    // ============================================

    function test_Burn() public {
        harness.mint(alice, TOKEN_ID_1, 100);

        vm.expectEmit(true, true, true, true);
        emit TransferSingle(address(this), alice, address(0), TOKEN_ID_1, 30);
        harness.burn(alice, TOKEN_ID_1, 30);

        assertEq(harness.balanceOf(alice, TOKEN_ID_1), 70);
    }

    function test_Burn_AllBalance() public {
        harness.mint(alice, TOKEN_ID_1, 100);

        harness.burn(alice, TOKEN_ID_1, 100);

        assertEq(harness.balanceOf(alice, TOKEN_ID_1), 0);
    }

    function testFuzz_Burn(address from, uint256 id, uint256 mintAmount, uint256 burnAmount) public {
        vm.assume(from != address(0));
        vm.assume(from.code.length == 0);
        vm.assume(mintAmount < type(uint256).max / 2);
        vm.assume(burnAmount <= mintAmount);

        harness.mint(from, id, mintAmount);
        harness.burn(from, id, burnAmount);

        assertEq(harness.balanceOf(from, id), mintAmount - burnAmount);
    }

    function test_RevertWhen_BurnFromZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(LibERC1155.ERC1155InvalidSender.selector, address(0)));
        harness.burn(address(0), TOKEN_ID_1, 100);
    }

    function test_RevertWhen_BurnInsufficientBalance() public {
        harness.mint(alice, TOKEN_ID_1, 100);

        vm.expectRevert(
            abi.encodeWithSelector(LibERC1155.ERC1155InsufficientBalance.selector, alice, 100, 150, TOKEN_ID_1)
        );
        harness.burn(alice, TOKEN_ID_1, 150);
    }

    function test_RevertWhen_BurnZeroBalance() public {
        vm.expectRevert(abi.encodeWithSelector(LibERC1155.ERC1155InsufficientBalance.selector, alice, 0, 1, TOKEN_ID_1));
        harness.burn(alice, TOKEN_ID_1, 1);
    }

    // ============================================
    // BurnBatch Tests
    // ============================================

    function test_BurnBatch() public {
        uint256[] memory ids = new uint256[](3);
        ids[0] = TOKEN_ID_1;
        ids[1] = TOKEN_ID_2;
        ids[2] = TOKEN_ID_3;

        uint256[] memory mintAmounts = new uint256[](3);
        mintAmounts[0] = 100;
        mintAmounts[1] = 200;
        mintAmounts[2] = 300;

        harness.mintBatch(alice, ids, mintAmounts);

        uint256[] memory burnAmounts = new uint256[](3);
        burnAmounts[0] = 30;
        burnAmounts[1] = 50;
        burnAmounts[2] = 100;

        vm.expectEmit(true, true, true, true);
        emit TransferBatch(address(this), alice, address(0), ids, burnAmounts);
        harness.burnBatch(alice, ids, burnAmounts);

        assertEq(harness.balanceOf(alice, TOKEN_ID_1), 70);
        assertEq(harness.balanceOf(alice, TOKEN_ID_2), 150);
        assertEq(harness.balanceOf(alice, TOKEN_ID_3), 200);
    }

    function test_RevertWhen_BurnBatchFromZeroAddress() public {
        uint256[] memory ids = new uint256[](1);
        ids[0] = TOKEN_ID_1;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 100;

        vm.expectRevert(abi.encodeWithSelector(LibERC1155.ERC1155InvalidSender.selector, address(0)));
        harness.burnBatch(address(0), ids, amounts);
    }

    function test_RevertWhen_BurnBatchArrayLengthMismatch() public {
        uint256[] memory ids = new uint256[](2);
        ids[0] = TOKEN_ID_1;
        ids[1] = TOKEN_ID_2;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 100;

        harness.mint(alice, TOKEN_ID_1, 100);

        vm.expectRevert(abi.encodeWithSelector(LibERC1155.ERC1155InvalidArrayLength.selector, 2, 1));
        harness.burnBatch(alice, ids, amounts);
    }

    function test_RevertWhen_BurnBatchInsufficientBalance() public {
        uint256[] memory ids = new uint256[](2);
        ids[0] = TOKEN_ID_1;
        ids[1] = TOKEN_ID_2;

        uint256[] memory mintAmounts = new uint256[](2);
        mintAmounts[0] = 100;
        mintAmounts[1] = 50;

        harness.mintBatch(alice, ids, mintAmounts);

        uint256[] memory burnAmounts = new uint256[](2);
        burnAmounts[0] = 50;
        burnAmounts[1] = 100; // More than balance

        vm.expectRevert(
            abi.encodeWithSelector(LibERC1155.ERC1155InsufficientBalance.selector, alice, 50, 100, TOKEN_ID_2)
        );
        harness.burnBatch(alice, ids, burnAmounts);
    }

    // ============================================
    // SafeTransferFrom Tests
    // ============================================

    function test_SafeTransferFrom_ByOwner() public {
        harness.mint(alice, TOKEN_ID_1, 100);

        vm.expectEmit(true, true, true, true);
        emit TransferSingle(alice, alice, bob, TOKEN_ID_1, 30);

        vm.prank(alice);
        harness.safeTransferFrom(alice, bob, TOKEN_ID_1, 30);

        assertEq(harness.balanceOf(alice, TOKEN_ID_1), 70);
        assertEq(harness.balanceOf(bob, TOKEN_ID_1), 30);
    }

    function test_SafeTransferFrom_ByApprovedOperator() public {
        harness.mint(alice, TOKEN_ID_1, 100);

        vm.prank(alice);
        harness.setApprovalForAll(bob, true);

        vm.prank(bob);
        harness.safeTransferFrom(alice, charlie, TOKEN_ID_1, 30);

        assertEq(harness.balanceOf(alice, TOKEN_ID_1), 70);
        assertEq(harness.balanceOf(charlie, TOKEN_ID_1), 30);
    }

    function test_SafeTransferFrom_ToSelf() public {
        uint256 amount = 100;

        harness.mint(alice, TOKEN_ID_1, amount);

        vm.prank(alice);
        harness.safeTransferFrom(alice, alice, TOKEN_ID_1, 50);

        assertEq(harness.balanceOf(alice, TOKEN_ID_1), amount);
    }

    function test_SafeTransferFrom_ZeroAmount() public {
        harness.mint(alice, TOKEN_ID_1, 100);

        vm.prank(alice);
        harness.safeTransferFrom(alice, bob, TOKEN_ID_1, 0);

        assertEq(harness.balanceOf(alice, TOKEN_ID_1), 100);
        assertEq(harness.balanceOf(bob, TOKEN_ID_1), 0);
    }

    function testFuzz_SafeTransferFrom(address from, address to, uint256 id, uint256 amount) public {
        vm.assume(from != address(0) && to != address(0));
        vm.assume(from.code.length == 0 && to.code.length == 0);
        vm.assume(amount < type(uint256).max / 2);

        harness.mint(from, id, amount);

        vm.prank(from);
        harness.safeTransferFrom(from, to, id, amount);

        assertEq(harness.balanceOf(from, id), 0);
        assertEq(harness.balanceOf(to, id), amount);
    }

    function test_RevertWhen_SafeTransferFromToZeroAddress() public {
        harness.mint(alice, TOKEN_ID_1, 100);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(LibERC1155.ERC1155InvalidReceiver.selector, address(0)));
        harness.safeTransferFrom(alice, address(0), TOKEN_ID_1, 30);
    }

    function test_RevertWhen_SafeTransferFromFromZeroAddress() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(LibERC1155.ERC1155InvalidSender.selector, address(0)));
        harness.safeTransferFrom(address(0), bob, TOKEN_ID_1, 30);
    }

    function test_RevertWhen_SafeTransferFromWithoutApproval() public {
        harness.mint(alice, TOKEN_ID_1, 100);

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(LibERC1155.ERC1155MissingApprovalForAll.selector, bob, alice));
        harness.safeTransferFrom(alice, charlie, TOKEN_ID_1, 30);
    }

    function test_RevertWhen_SafeTransferFromInsufficientBalance() public {
        harness.mint(alice, TOKEN_ID_1, 100);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(LibERC1155.ERC1155InsufficientBalance.selector, alice, 100, 150, TOKEN_ID_1)
        );
        harness.safeTransferFrom(alice, bob, TOKEN_ID_1, 150);
    }

    function test_RevertWhen_SafeTransferFromZeroBalance() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(LibERC1155.ERC1155InsufficientBalance.selector, alice, 0, 1, TOKEN_ID_1));
        harness.safeTransferFrom(alice, bob, TOKEN_ID_1, 1);
    }

    function test_RevertWhen_MintOverflowsRecipient() public {
        uint256 nearMaxBalance = type(uint256).max - 100;

        // Mint near-max tokens to alice
        harness.mint(alice, TOKEN_ID_1, nearMaxBalance);

        // Try to mint more, which would overflow
        vm.expectRevert(); // Arithmetic overflow
        harness.mint(alice, TOKEN_ID_1, 200);
    }

    // ============================================
    // SafeBatchTransferFrom Tests
    // ============================================

    function test_SafeBatchTransferFrom_ByOwner() public {
        uint256[] memory ids = new uint256[](2);
        ids[0] = TOKEN_ID_1;
        ids[1] = TOKEN_ID_2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100;
        amounts[1] = 200;

        harness.mintBatch(alice, ids, amounts);

        uint256[] memory transferAmounts = new uint256[](2);
        transferAmounts[0] = 30;
        transferAmounts[1] = 50;

        vm.expectEmit(true, true, true, true);
        emit TransferBatch(alice, alice, bob, ids, transferAmounts);

        vm.prank(alice);
        harness.safeBatchTransferFrom(alice, bob, ids, transferAmounts);

        assertEq(harness.balanceOf(alice, TOKEN_ID_1), 70);
        assertEq(harness.balanceOf(alice, TOKEN_ID_2), 150);
        assertEq(harness.balanceOf(bob, TOKEN_ID_1), 30);
        assertEq(harness.balanceOf(bob, TOKEN_ID_2), 50);
    }

    function test_SafeBatchTransferFrom_ByApprovedOperator() public {
        uint256[] memory ids = new uint256[](2);
        ids[0] = TOKEN_ID_1;
        ids[1] = TOKEN_ID_2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100;
        amounts[1] = 200;

        harness.mintBatch(alice, ids, amounts);

        vm.prank(alice);
        harness.setApprovalForAll(bob, true);

        uint256[] memory transferAmounts = new uint256[](2);
        transferAmounts[0] = 30;
        transferAmounts[1] = 50;

        vm.prank(bob);
        harness.safeBatchTransferFrom(alice, charlie, ids, transferAmounts);

        assertEq(harness.balanceOf(alice, TOKEN_ID_1), 70);
        assertEq(harness.balanceOf(alice, TOKEN_ID_2), 150);
        assertEq(harness.balanceOf(charlie, TOKEN_ID_1), 30);
        assertEq(harness.balanceOf(charlie, TOKEN_ID_2), 50);
    }

    function test_RevertWhen_SafeBatchTransferFromToZeroAddress() public {
        uint256[] memory ids = new uint256[](1);
        ids[0] = TOKEN_ID_1;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 30;

        harness.mint(alice, TOKEN_ID_1, 100);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(LibERC1155.ERC1155InvalidReceiver.selector, address(0)));
        harness.safeBatchTransferFrom(alice, address(0), ids, amounts);
    }

    function test_RevertWhen_SafeBatchTransferFromFromZeroAddress() public {
        uint256[] memory ids = new uint256[](1);
        ids[0] = TOKEN_ID_1;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 30;

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(LibERC1155.ERC1155InvalidSender.selector, address(0)));
        harness.safeBatchTransferFrom(address(0), bob, ids, amounts);
    }

    function test_RevertWhen_SafeBatchTransferFromArrayLengthMismatch() public {
        uint256[] memory ids = new uint256[](2);
        ids[0] = TOKEN_ID_1;
        ids[1] = TOKEN_ID_2;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 30;

        harness.mint(alice, TOKEN_ID_1, 100);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(LibERC1155.ERC1155InvalidArrayLength.selector, 2, 1));
        harness.safeBatchTransferFrom(alice, bob, ids, amounts);
    }

    function test_RevertWhen_SafeBatchTransferFromWithoutApproval() public {
        uint256[] memory ids = new uint256[](1);
        ids[0] = TOKEN_ID_1;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 30;

        harness.mint(alice, TOKEN_ID_1, 100);

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(LibERC1155.ERC1155MissingApprovalForAll.selector, bob, alice));
        harness.safeBatchTransferFrom(alice, charlie, ids, amounts);
    }

    function test_RevertWhen_SafeBatchTransferFromInsufficientBalance() public {
        uint256[] memory ids = new uint256[](2);
        ids[0] = TOKEN_ID_1;
        ids[1] = TOKEN_ID_2;

        uint256[] memory mintAmounts = new uint256[](2);
        mintAmounts[0] = 100;
        mintAmounts[1] = 50;

        harness.mintBatch(alice, ids, mintAmounts);

        uint256[] memory transferAmounts = new uint256[](2);
        transferAmounts[0] = 30;
        transferAmounts[1] = 100; // More than balance

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(LibERC1155.ERC1155InsufficientBalance.selector, alice, 50, 100, TOKEN_ID_2)
        );
        harness.safeBatchTransferFrom(alice, bob, ids, transferAmounts);
    }

    // ============================================
    // BalanceOf Tests
    // ============================================

    function test_BalanceOf_AfterMint() public {
        harness.mint(alice, TOKEN_ID_1, 100);
        assertEq(harness.balanceOf(alice, TOKEN_ID_1), 100);
    }

    function test_BalanceOf_MultipleTokens() public {
        harness.mint(alice, TOKEN_ID_1, 100);
        harness.mint(alice, TOKEN_ID_2, 200);

        assertEq(harness.balanceOf(alice, TOKEN_ID_1), 100);
        assertEq(harness.balanceOf(alice, TOKEN_ID_2), 200);
    }

    function test_BalanceOf_ZeroAddress() public view {
        assertEq(harness.balanceOf(address(0), TOKEN_ID_1), 0);
    }

    // ============================================
    // BalanceOfBatch Tests
    // ============================================

    function test_BalanceOfBatch() public {
        harness.mint(alice, TOKEN_ID_1, 100);
        harness.mint(bob, TOKEN_ID_2, 200);
        harness.mint(charlie, TOKEN_ID_3, 300);

        address[] memory accounts = new address[](3);
        accounts[0] = alice;
        accounts[1] = bob;
        accounts[2] = charlie;

        uint256[] memory ids = new uint256[](3);
        ids[0] = TOKEN_ID_1;
        ids[1] = TOKEN_ID_2;
        ids[2] = TOKEN_ID_3;

        uint256[] memory balances = harness.balanceOfBatch(accounts, ids);

        assertEq(balances[0], 100);
        assertEq(balances[1], 200);
        assertEq(balances[2], 300);
    }

    function test_BalanceOfBatch_EmptyArrays() public view {
        address[] memory accounts = new address[](0);
        uint256[] memory ids = new uint256[](0);

        uint256[] memory balances = harness.balanceOfBatch(accounts, ids);
        assertEq(balances.length, 0);
    }

    function test_BalanceOfBatch_SameAccountMultipleTimes() public {
        harness.mint(alice, TOKEN_ID_1, 100);
        harness.mint(alice, TOKEN_ID_2, 200);

        address[] memory accounts = new address[](2);
        accounts[0] = alice;
        accounts[1] = alice;

        uint256[] memory ids = new uint256[](2);
        ids[0] = TOKEN_ID_1;
        ids[1] = TOKEN_ID_2;

        uint256[] memory balances = harness.balanceOfBatch(accounts, ids);
        assertEq(balances[0], 100);
        assertEq(balances[1], 200);
    }

    function test_BalanceOfBatch_DifferentAccountsSameTokenId() public {
        harness.mint(alice, TOKEN_ID_1, 100);
        harness.mint(bob, TOKEN_ID_1, 200);

        address[] memory accounts = new address[](2);
        accounts[0] = alice;
        accounts[1] = bob;

        uint256[] memory ids = new uint256[](2);
        ids[0] = TOKEN_ID_1;
        ids[1] = TOKEN_ID_1;

        uint256[] memory balances = harness.balanceOfBatch(accounts, ids);
        assertEq(balances[0], 100);
        assertEq(balances[1], 200);
    }

    function test_BalanceOfBatch_WithZeroAddress() public {
        harness.mint(alice, TOKEN_ID_1, 100);
        harness.mint(bob, TOKEN_ID_3, 300);

        address[] memory accounts = new address[](3);
        accounts[0] = alice;
        accounts[1] = address(0);
        accounts[2] = bob;

        uint256[] memory ids = new uint256[](3);
        ids[0] = TOKEN_ID_1;
        ids[1] = TOKEN_ID_2;
        ids[2] = TOKEN_ID_3;

        uint256[] memory balances = harness.balanceOfBatch(accounts, ids);
        assertEq(balances[0], 100);
        assertEq(balances[1], 0);
        assertEq(balances[2], 300);
    }

    // ============================================
    // Approval Tests
    // ============================================

    function test_SetApprovalForAll() public {
        vm.prank(alice);
        harness.setApprovalForAll(bob, true);

        assertTrue(harness.isApprovedForAll(alice, bob));
    }

    function test_SetApprovalForAll_Revoke() public {
        vm.prank(alice);
        harness.setApprovalForAll(bob, true);

        vm.prank(alice);
        harness.setApprovalForAll(bob, false);

        assertFalse(harness.isApprovedForAll(alice, bob));
    }

    function test_SetApprovalForAll_Self() public {
        vm.prank(alice);
        harness.setApprovalForAll(alice, true);

        assertTrue(harness.isApprovedForAll(alice, alice));
    }

    function testFuzz_SetApprovalForAll(address owner, address operator, bool approved) public {
        vm.assume(owner != address(0) && operator != address(0));

        vm.prank(owner);
        harness.setApprovalForAll(operator, approved);

        assertEq(harness.isApprovedForAll(owner, operator), approved);
    }

    // ============================================
    // Receiver Hook Tests
    // ============================================

    function test_SafeTransferFrom_ToContractWithAcceptance() public {
        ERC1155ReceiverMock receiver = new ERC1155ReceiverMock(
            RECEIVER_SINGLE_MAGIC_VALUE, RECEIVER_BATCH_MAGIC_VALUE, ERC1155ReceiverMock.RevertType.None
        );

        harness.mint(alice, TOKEN_ID_1, 100);

        vm.prank(alice);
        harness.safeTransferFrom(alice, address(receiver), TOKEN_ID_1, 50);

        assertEq(harness.balanceOf(alice, TOKEN_ID_1), 50);
        assertEq(harness.balanceOf(address(receiver), TOKEN_ID_1), 50);
    }

    function test_RevertWhen_SafeTransferFrom_ToContractWithWrongReturnValue() public {
        ERC1155ReceiverMock receiver = new ERC1155ReceiverMock(
            0x00c0ffee, // Wrong return value
            RECEIVER_BATCH_MAGIC_VALUE,
            ERC1155ReceiverMock.RevertType.None
        );

        harness.mint(alice, TOKEN_ID_1, 100);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(LibERC1155.ERC1155InvalidReceiver.selector, address(receiver)));
        harness.safeTransferFrom(alice, address(receiver), TOKEN_ID_1, 50);
    }

    function test_RevertWhen_SafeTransferFrom_ToContractWithRevertMessage() public {
        ERC1155ReceiverMock receiver = new ERC1155ReceiverMock(
            RECEIVER_SINGLE_MAGIC_VALUE, RECEIVER_BATCH_MAGIC_VALUE, ERC1155ReceiverMock.RevertType.RevertWithMessage
        );

        harness.mint(alice, TOKEN_ID_1, 100);

        vm.prank(alice);
        vm.expectRevert("ERC1155ReceiverMock: reverting on receive");
        harness.safeTransferFrom(alice, address(receiver), TOKEN_ID_1, 50);
    }

    function test_RevertWhen_SafeTransferFrom_ToContractWithRevertNoMessage() public {
        ERC1155ReceiverMock receiver = new ERC1155ReceiverMock(
            RECEIVER_SINGLE_MAGIC_VALUE, RECEIVER_BATCH_MAGIC_VALUE, ERC1155ReceiverMock.RevertType.RevertWithoutMessage
        );

        harness.mint(alice, TOKEN_ID_1, 100);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(LibERC1155.ERC1155InvalidReceiver.selector, address(receiver)));
        harness.safeTransferFrom(alice, address(receiver), TOKEN_ID_1, 50);
    }

    function test_SafeBatchTransferFrom_ToContractWithAcceptance() public {
        ERC1155ReceiverMock receiver = new ERC1155ReceiverMock(
            RECEIVER_SINGLE_MAGIC_VALUE, RECEIVER_BATCH_MAGIC_VALUE, ERC1155ReceiverMock.RevertType.None
        );

        uint256[] memory ids = new uint256[](2);
        ids[0] = TOKEN_ID_1;
        ids[1] = TOKEN_ID_2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100;
        amounts[1] = 200;

        harness.mintBatch(alice, ids, amounts);

        uint256[] memory transferAmounts = new uint256[](2);
        transferAmounts[0] = 50;
        transferAmounts[1] = 100;

        vm.prank(alice);
        harness.safeBatchTransferFrom(alice, address(receiver), ids, transferAmounts);

        assertEq(harness.balanceOf(alice, TOKEN_ID_1), 50);
        assertEq(harness.balanceOf(alice, TOKEN_ID_2), 100);
        assertEq(harness.balanceOf(address(receiver), TOKEN_ID_1), 50);
        assertEq(harness.balanceOf(address(receiver), TOKEN_ID_2), 100);
    }

    function test_RevertWhen_SafeBatchTransferFrom_ToContractWithRevertNoMessage() public {
        ERC1155ReceiverMock receiver = new ERC1155ReceiverMock(
            RECEIVER_SINGLE_MAGIC_VALUE, RECEIVER_BATCH_MAGIC_VALUE, ERC1155ReceiverMock.RevertType.RevertWithoutMessage
        );

        uint256[] memory ids = new uint256[](1);
        ids[0] = TOKEN_ID_1;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 50;

        harness.mint(alice, TOKEN_ID_1, 100);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(LibERC1155.ERC1155InvalidReceiver.selector, address(receiver)));
        harness.safeBatchTransferFrom(alice, address(receiver), ids, amounts);
    }

    function test_RevertWhen_SafeBatchTransferFrom_ToContractWithWrongReturnValue() public {
        ERC1155ReceiverMock receiver = new ERC1155ReceiverMock(
            RECEIVER_SINGLE_MAGIC_VALUE,
            RECEIVER_SINGLE_MAGIC_VALUE, // Wrong return value (correct for single, wrong for batch)
            ERC1155ReceiverMock.RevertType.None
        );

        uint256[] memory ids = new uint256[](1);
        ids[0] = TOKEN_ID_1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 50;

        harness.mint(alice, TOKEN_ID_1, 100);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(LibERC1155.ERC1155InvalidReceiver.selector, address(receiver)));
        harness.safeBatchTransferFrom(alice, address(receiver), ids, amounts);
    }

    function test_RevertWhen_SafeBatchTransferFrom_ToContractWithRevertMessage() public {
        ERC1155ReceiverMock receiver = new ERC1155ReceiverMock(
            RECEIVER_SINGLE_MAGIC_VALUE, RECEIVER_BATCH_MAGIC_VALUE, ERC1155ReceiverMock.RevertType.RevertWithMessage
        );

        uint256[] memory ids = new uint256[](1);
        ids[0] = TOKEN_ID_1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 50;

        harness.mint(alice, TOKEN_ID_1, 100);

        vm.prank(alice);
        vm.expectRevert("ERC1155ReceiverMock: reverting on batch receive");
        harness.safeBatchTransferFrom(alice, address(receiver), ids, amounts);
    }

    function test_RevertWhen_SafeTransferFrom_ToContractWithPanic() public {
        ERC1155ReceiverMock receiver = new ERC1155ReceiverMock(
            RECEIVER_SINGLE_MAGIC_VALUE, RECEIVER_BATCH_MAGIC_VALUE, ERC1155ReceiverMock.RevertType.Panic
        );

        harness.mint(alice, TOKEN_ID_1, 100);

        vm.prank(alice);
        vm.expectRevert();
        harness.safeTransferFrom(alice, address(receiver), TOKEN_ID_1, 50);
    }

    function test_RevertWhen_SafeBatchTransferFrom_ToContractWithPanic() public {
        ERC1155ReceiverMock receiver = new ERC1155ReceiverMock(
            RECEIVER_SINGLE_MAGIC_VALUE, RECEIVER_BATCH_MAGIC_VALUE, ERC1155ReceiverMock.RevertType.Panic
        );

        uint256[] memory ids = new uint256[](1);
        ids[0] = TOKEN_ID_1;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 50;

        harness.mint(alice, TOKEN_ID_1, 100);

        vm.prank(alice);
        vm.expectRevert();
        harness.safeBatchTransferFrom(alice, address(receiver), ids, amounts);
    }

    function test_RevertWhen_SafeTransferFrom_ToContractWithCustomError() public {
        ERC1155ReceiverMock receiver = new ERC1155ReceiverMock(
            RECEIVER_SINGLE_MAGIC_VALUE,
            RECEIVER_BATCH_MAGIC_VALUE,
            ERC1155ReceiverMock.RevertType.RevertWithCustomError
        );

        harness.mint(alice, TOKEN_ID_1, 100);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ERC1155ReceiverMock.CustomError.selector, RECEIVER_SINGLE_MAGIC_VALUE));
        harness.safeTransferFrom(alice, address(receiver), TOKEN_ID_1, 50);
    }

    function test_RevertWhen_SafeBatchTransferFrom_ToContractWithCustomError() public {
        ERC1155ReceiverMock receiver = new ERC1155ReceiverMock(
            RECEIVER_SINGLE_MAGIC_VALUE,
            RECEIVER_BATCH_MAGIC_VALUE,
            ERC1155ReceiverMock.RevertType.RevertWithCustomError
        );

        uint256[] memory ids = new uint256[](1);
        ids[0] = TOKEN_ID_1;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 50;

        harness.mint(alice, TOKEN_ID_1, 100);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ERC1155ReceiverMock.CustomError.selector, RECEIVER_BATCH_MAGIC_VALUE));
        harness.safeBatchTransferFrom(alice, address(receiver), ids, amounts);
    }

    function test_SafeBatchTransferFrom_EmptyArrays() public {
        uint256[] memory ids = new uint256[](0);
        uint256[] memory amounts = new uint256[](0);

        vm.prank(alice);
        harness.safeBatchTransferFrom(alice, bob, ids, amounts);
        // Should not revert
    }

    function test_SafeBatchTransferFrom_WithZeroAmounts() public {
        uint256[] memory ids = new uint256[](3);
        ids[0] = TOKEN_ID_1;
        ids[1] = TOKEN_ID_2;
        ids[2] = TOKEN_ID_3;

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 100;
        amounts[1] = 200;
        amounts[2] = 300;

        harness.mintBatch(alice, ids, amounts);

        uint256[] memory transferAmounts = new uint256[](3);
        transferAmounts[0] = 30;
        transferAmounts[1] = 0; // Zero amount
        transferAmounts[2] = 50;

        vm.prank(alice);
        harness.safeBatchTransferFrom(alice, bob, ids, transferAmounts);

        assertEq(harness.balanceOf(alice, TOKEN_ID_1), 70);
        assertEq(harness.balanceOf(alice, TOKEN_ID_2), 200);
        assertEq(harness.balanceOf(alice, TOKEN_ID_3), 250);
        assertEq(harness.balanceOf(bob, TOKEN_ID_1), 30);
        assertEq(harness.balanceOf(bob, TOKEN_ID_2), 0);
        assertEq(harness.balanceOf(bob, TOKEN_ID_3), 50);
    }

    function test_SafeBatchTransferFrom_DuplicateTokenIds() public {
        harness.mint(alice, TOKEN_ID_1, 100);

        uint256[] memory ids = new uint256[](2);
        ids[0] = TOKEN_ID_1;
        ids[1] = TOKEN_ID_1; // Duplicate

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 10;
        amounts[1] = 20;

        vm.prank(alice);
        harness.safeBatchTransferFrom(alice, bob, ids, amounts);

        assertEq(harness.balanceOf(alice, TOKEN_ID_1), 70);
        assertEq(harness.balanceOf(bob, TOKEN_ID_1), 30);
    }

    // ============================================
    // Integration Tests
    // ============================================

    function test_MintTransferBurn_Flow() public {
        // Mint to alice
        harness.mint(alice, TOKEN_ID_1, 1000);
        harness.mint(alice, TOKEN_ID_2, 500);

        // Alice transfers some to bob
        vm.prank(alice);
        harness.safeTransferFrom(alice, bob, TOKEN_ID_1, 300);

        // Bob transfers some to charlie
        vm.prank(bob);
        harness.safeTransferFrom(bob, charlie, TOKEN_ID_1, 100);

        // Burn from alice
        harness.burn(alice, TOKEN_ID_1, 200);

        // Verify final balances
        assertEq(harness.balanceOf(alice, TOKEN_ID_1), 500);
        assertEq(harness.balanceOf(alice, TOKEN_ID_2), 500);
        assertEq(harness.balanceOf(bob, TOKEN_ID_1), 200);
        assertEq(harness.balanceOf(charlie, TOKEN_ID_1), 100);
    }

    function test_MintBatchTransferBatchBurnBatch_Flow() public {
        uint256[] memory ids = new uint256[](3);
        ids[0] = TOKEN_ID_1;
        ids[1] = TOKEN_ID_2;
        ids[2] = TOKEN_ID_3;

        uint256[] memory mintAmounts = new uint256[](3);
        mintAmounts[0] = 1000;
        mintAmounts[1] = 2000;
        mintAmounts[2] = 3000;

        // Mint batch to alice
        harness.mintBatch(alice, ids, mintAmounts);

        // Alice transfers batch to bob
        uint256[] memory transferAmounts = new uint256[](3);
        transferAmounts[0] = 300;
        transferAmounts[1] = 400;
        transferAmounts[2] = 500;

        vm.prank(alice);
        harness.safeBatchTransferFrom(alice, bob, ids, transferAmounts);

        // Burn batch from alice
        uint256[] memory burnAmounts = new uint256[](3);
        burnAmounts[0] = 200;
        burnAmounts[1] = 300;
        burnAmounts[2] = 400;

        harness.burnBatch(alice, ids, burnAmounts);

        // Verify final balances
        assertEq(harness.balanceOf(alice, TOKEN_ID_1), 500);
        assertEq(harness.balanceOf(alice, TOKEN_ID_2), 1300);
        assertEq(harness.balanceOf(alice, TOKEN_ID_3), 2100);
        assertEq(harness.balanceOf(bob, TOKEN_ID_1), 300);
        assertEq(harness.balanceOf(bob, TOKEN_ID_2), 400);
        assertEq(harness.balanceOf(bob, TOKEN_ID_3), 500);
    }

    function test_ApprovalAndTransfer_Flow() public {
        harness.mint(alice, TOKEN_ID_1, 1000);

        // Alice approves bob
        vm.prank(alice);
        harness.setApprovalForAll(bob, true);

        // Bob transfers on behalf of alice
        vm.prank(bob);
        harness.safeTransferFrom(alice, charlie, TOKEN_ID_1, 300);

        assertEq(harness.balanceOf(alice, TOKEN_ID_1), 700);
        assertEq(harness.balanceOf(charlie, TOKEN_ID_1), 300);

        // Alice revokes approval
        vm.prank(alice);
        harness.setApprovalForAll(bob, false);

        // Bob can no longer transfer
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(LibERC1155.ERC1155MissingApprovalForAll.selector, bob, alice));
        harness.safeTransferFrom(alice, charlie, TOKEN_ID_1, 100);
    }
}
