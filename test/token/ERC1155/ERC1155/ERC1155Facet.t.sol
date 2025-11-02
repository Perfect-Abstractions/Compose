// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {Test} from "forge-std/Test.sol";
import {ERC1155FacetHarness} from "./harnesses/ERC1155FacetHarness.sol";
import {ERC1155Facet} from "../../../../src/token/ERC1155/ERC1155Facet.sol";
import {ERC1155ReceiverMock} from "./mocks/ERC1155ReceiverMock.sol";

contract ERC1155FacetTest is Test {
    ERC1155FacetHarness public facet;

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

        facet = new ERC1155FacetHarness();
        facet.initialize(DEFAULT_URI);
    }

    // ============================================
    // URI Tests
    // ============================================

    function test_Uri_DefaultUri() public view {
        assertEq(facet.uri(TOKEN_ID_1), DEFAULT_URI);
    }

    function test_Uri_SetBaseURI() public {
        facet.setBaseURI(BASE_URI);
        facet.setTokenURI(TOKEN_ID_1, TOKEN_URI);
        assertEq(facet.uri(TOKEN_ID_1), string.concat(BASE_URI, TOKEN_URI));
    }

    function test_Uri_SetTokenURI() public {
        vm.expectEmit(true, true, true, true);
        emit URI(TOKEN_URI, TOKEN_ID_1);
        facet.setTokenURI(TOKEN_ID_1, TOKEN_URI);
    }

    // ============================================
    // BalanceOf Tests
    // ============================================

    function test_BalanceOf_AfterMint() public {
        facet.mint(alice, TOKEN_ID_1, 100);
        assertEq(facet.balanceOf(alice, TOKEN_ID_1), 100);
    }

    function test_BalanceOf_MultipleTokens() public {
        facet.mint(alice, TOKEN_ID_1, 100);
        facet.mint(alice, TOKEN_ID_2, 200);

        assertEq(facet.balanceOf(alice, TOKEN_ID_1), 100);
        assertEq(facet.balanceOf(alice, TOKEN_ID_2), 200);
    }

    function test_BalanceOf_MultipleAccounts() public {
        facet.mint(alice, TOKEN_ID_1, 100);
        facet.mint(bob, TOKEN_ID_1, 200);

        assertEq(facet.balanceOf(alice, TOKEN_ID_1), 100);
        assertEq(facet.balanceOf(bob, TOKEN_ID_1), 200);
    }

    // ============================================
    // BalanceOfBatch Tests
    // ============================================

    function test_BalanceOfBatch() public {
        facet.mint(alice, TOKEN_ID_1, 100);
        facet.mint(bob, TOKEN_ID_2, 200);
        facet.mint(charlie, TOKEN_ID_3, 300);

        address[] memory accounts = new address[](3);
        accounts[0] = alice;
        accounts[1] = bob;
        accounts[2] = charlie;

        uint256[] memory ids = new uint256[](3);
        ids[0] = TOKEN_ID_1;
        ids[1] = TOKEN_ID_2;
        ids[2] = TOKEN_ID_3;

        uint256[] memory balances = facet.balanceOfBatch(accounts, ids);

        assertEq(balances[0], 100);
        assertEq(balances[1], 200);
        assertEq(balances[2], 300);
    }

    function test_RevertWhen_BalanceOfBatchArrayLengthMismatch() public {
        address[] memory accounts = new address[](2);
        accounts[0] = alice;
        accounts[1] = bob;

        uint256[] memory ids = new uint256[](1);
        ids[0] = TOKEN_ID_1;

        vm.expectRevert(abi.encodeWithSelector(ERC1155Facet.ERC1155InvalidArrayLength.selector, 1, 2));
        facet.balanceOfBatch(accounts, ids);
    }

    // ============================================
    // SetApprovalForAll Tests
    // ============================================

    function test_SetApprovalForAll() public {
        vm.expectEmit(true, true, true, true);
        emit ApprovalForAll(alice, bob, true);

        vm.prank(alice);
        facet.setApprovalForAll(bob, true);

        assertTrue(facet.isApprovedForAll(alice, bob));
    }

    function test_SetApprovalForAll_Revoke() public {
        vm.prank(alice);
        facet.setApprovalForAll(bob, true);

        vm.expectEmit(true, true, true, true);
        emit ApprovalForAll(alice, bob, false);

        vm.prank(alice);
        facet.setApprovalForAll(bob, false);

        assertFalse(facet.isApprovedForAll(alice, bob));
    }

    function test_SetApprovalForAll_MultipleOperators() public {
        vm.startPrank(alice);
        facet.setApprovalForAll(bob, true);
        facet.setApprovalForAll(charlie, true);
        vm.stopPrank();

        assertTrue(facet.isApprovedForAll(alice, bob));
        assertTrue(facet.isApprovedForAll(alice, charlie));
    }

    function test_RevertWhen_SetApprovalForAllZeroAddress() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ERC1155Facet.ERC1155InvalidOperator.selector, address(0)));
        facet.setApprovalForAll(address(0), true);
    }

    function testFuzz_SetApprovalForAll(address owner, address operator, bool approved) public {
        vm.assume(owner != address(0) && operator != address(0));

        vm.prank(owner);
        facet.setApprovalForAll(operator, approved);

        assertEq(facet.isApprovedForAll(owner, operator), approved);
    }

    // ============================================
    // SafeTransferFrom Tests
    // ============================================

    function test_SafeTransferFrom_ByOwner() public {
        facet.mint(alice, TOKEN_ID_1, 100);

        vm.expectEmit(true, true, true, true);
        emit TransferSingle(alice, alice, bob, TOKEN_ID_1, 30);

        vm.prank(alice);
        facet.safeTransferFrom(alice, bob, TOKEN_ID_1, 30, "");

        assertEq(facet.balanceOf(alice, TOKEN_ID_1), 70);
        assertEq(facet.balanceOf(bob, TOKEN_ID_1), 30);
    }

    function test_SafeTransferFrom_ByApprovedOperator() public {
        facet.mint(alice, TOKEN_ID_1, 100);

        vm.prank(alice);
        facet.setApprovalForAll(bob, true);

        vm.expectEmit(true, true, true, true);
        emit TransferSingle(bob, alice, charlie, TOKEN_ID_1, 30);

        vm.prank(bob);
        facet.safeTransferFrom(alice, charlie, TOKEN_ID_1, 30, "");

        assertEq(facet.balanceOf(alice, TOKEN_ID_1), 70);
        assertEq(facet.balanceOf(charlie, TOKEN_ID_1), 30);
    }

    function test_SafeTransferFrom_ToSelf() public {
        uint256 amount = 100;

        facet.mint(alice, TOKEN_ID_1, amount);

        vm.prank(alice);
        facet.safeTransferFrom(alice, alice, TOKEN_ID_1, 50, "");

        assertEq(facet.balanceOf(alice, TOKEN_ID_1), amount);
    }

    function test_SafeTransferFrom_ZeroAmount() public {
        facet.mint(alice, TOKEN_ID_1, 100);

        vm.prank(alice);
        facet.safeTransferFrom(alice, bob, TOKEN_ID_1, 0, "");

        assertEq(facet.balanceOf(alice, TOKEN_ID_1), 100);
        assertEq(facet.balanceOf(bob, TOKEN_ID_1), 0);
    }

    function test_SafeTransferFrom_AllBalance() public {
        uint256 amount = 100;

        facet.mint(alice, TOKEN_ID_1, amount);

        vm.prank(alice);
        facet.safeTransferFrom(alice, bob, TOKEN_ID_1, amount, "");

        assertEq(facet.balanceOf(alice, TOKEN_ID_1), 0);
        assertEq(facet.balanceOf(bob, TOKEN_ID_1), amount);
    }

    function testFuzz_SafeTransferFrom(address from, address to, uint256 id, uint256 amount) public {
        vm.assume(from != address(0) && to != address(0));
        vm.assume(from != to);
        vm.assume(from.code.length == 0 && to.code.length == 0);
        vm.assume(amount < type(uint256).max / 2);

        facet.mint(from, id, amount);

        vm.prank(from);
        facet.safeTransferFrom(from, to, id, amount, "");

        assertEq(facet.balanceOf(from, id), 0);
        assertEq(facet.balanceOf(to, id), amount);
    }

    function test_RevertWhen_SafeTransferFromToZeroAddress() public {
        facet.mint(alice, TOKEN_ID_1, 100);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ERC1155Facet.ERC1155InvalidReceiver.selector, address(0)));
        facet.safeTransferFrom(alice, address(0), TOKEN_ID_1, 30, "");
    }

    function test_RevertWhen_SafeTransferFromFromZeroAddress() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ERC1155Facet.ERC1155InvalidSender.selector, address(0)));
        facet.safeTransferFrom(address(0), bob, TOKEN_ID_1, 30, "");
    }

    function test_RevertWhen_SafeTransferFromWithoutApproval() public {
        facet.mint(alice, TOKEN_ID_1, 100);

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(ERC1155Facet.ERC1155MissingApprovalForAll.selector, bob, alice));
        facet.safeTransferFrom(alice, charlie, TOKEN_ID_1, 30, "");
    }

    function test_RevertWhen_SafeTransferFromInsufficientBalance() public {
        facet.mint(alice, TOKEN_ID_1, 100);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(ERC1155Facet.ERC1155InsufficientBalance.selector, alice, 100, 150, TOKEN_ID_1)
        );
        facet.safeTransferFrom(alice, bob, TOKEN_ID_1, 150, "");
    }

    function test_RevertWhen_SafeTransferFromZeroBalance() public {
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(ERC1155Facet.ERC1155InsufficientBalance.selector, alice, 0, 1, TOKEN_ID_1)
        );
        facet.safeTransferFrom(alice, bob, TOKEN_ID_1, 1, "");
    }

    function test_RevertWhen_MintOverflowsRecipient() public {
        uint256 nearMaxBalance = type(uint256).max - 100;

        // Mint near-max tokens to alice
        facet.mint(alice, TOKEN_ID_1, nearMaxBalance);

        // Try to mint more, which would overflow
        vm.expectRevert(); // Arithmetic overflow
        facet.mint(alice, TOKEN_ID_1, 200);
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

        facet.mintBatch(alice, ids, amounts);

        uint256[] memory transferAmounts = new uint256[](2);
        transferAmounts[0] = 30;
        transferAmounts[1] = 50;

        vm.expectEmit(true, true, true, true);
        emit TransferBatch(alice, alice, bob, ids, transferAmounts);

        vm.prank(alice);
        facet.safeBatchTransferFrom(alice, bob, ids, transferAmounts, "");

        assertEq(facet.balanceOf(alice, TOKEN_ID_1), 70);
        assertEq(facet.balanceOf(alice, TOKEN_ID_2), 150);
        assertEq(facet.balanceOf(bob, TOKEN_ID_1), 30);
        assertEq(facet.balanceOf(bob, TOKEN_ID_2), 50);
    }

    function test_SafeBatchTransferFrom_ByApprovedOperator() public {
        uint256[] memory ids = new uint256[](2);
        ids[0] = TOKEN_ID_1;
        ids[1] = TOKEN_ID_2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100;
        amounts[1] = 200;

        facet.mintBatch(alice, ids, amounts);

        vm.prank(alice);
        facet.setApprovalForAll(bob, true);

        uint256[] memory transferAmounts = new uint256[](2);
        transferAmounts[0] = 30;
        transferAmounts[1] = 50;

        vm.prank(bob);
        facet.safeBatchTransferFrom(alice, charlie, ids, transferAmounts, "");

        assertEq(facet.balanceOf(alice, TOKEN_ID_1), 70);
        assertEq(facet.balanceOf(alice, TOKEN_ID_2), 150);
        assertEq(facet.balanceOf(charlie, TOKEN_ID_1), 30);
        assertEq(facet.balanceOf(charlie, TOKEN_ID_2), 50);
    }

    function test_RevertWhen_SafeBatchTransferFromToZeroAddress() public {
        uint256[] memory ids = new uint256[](1);
        ids[0] = TOKEN_ID_1;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 30;

        facet.mint(alice, TOKEN_ID_1, 100);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ERC1155Facet.ERC1155InvalidReceiver.selector, address(0)));
        facet.safeBatchTransferFrom(alice, address(0), ids, amounts, "");
    }

    function test_RevertWhen_SafeBatchTransferFromFromZeroAddress() public {
        uint256[] memory ids = new uint256[](1);
        ids[0] = TOKEN_ID_1;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 30;

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ERC1155Facet.ERC1155InvalidSender.selector, address(0)));
        facet.safeBatchTransferFrom(address(0), bob, ids, amounts, "");
    }

    function test_RevertWhen_SafeBatchTransferFromArrayLengthMismatch() public {
        uint256[] memory ids = new uint256[](2);
        ids[0] = TOKEN_ID_1;
        ids[1] = TOKEN_ID_2;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 30;

        facet.mint(alice, TOKEN_ID_1, 100);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ERC1155Facet.ERC1155InvalidArrayLength.selector, 2, 1));
        facet.safeBatchTransferFrom(alice, bob, ids, amounts, "");
    }

    function test_RevertWhen_SafeBatchTransferFromWithoutApproval() public {
        uint256[] memory ids = new uint256[](1);
        ids[0] = TOKEN_ID_1;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 30;

        facet.mint(alice, TOKEN_ID_1, 100);

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(ERC1155Facet.ERC1155MissingApprovalForAll.selector, bob, alice));
        facet.safeBatchTransferFrom(alice, charlie, ids, amounts, "");
    }

    function test_RevertWhen_SafeBatchTransferFromInsufficientBalance() public {
        uint256[] memory ids = new uint256[](2);
        ids[0] = TOKEN_ID_1;
        ids[1] = TOKEN_ID_2;

        uint256[] memory mintAmounts = new uint256[](2);
        mintAmounts[0] = 100;
        mintAmounts[1] = 50;

        facet.mintBatch(alice, ids, mintAmounts);

        uint256[] memory transferAmounts = new uint256[](2);
        transferAmounts[0] = 30;
        transferAmounts[1] = 100; // More than balance

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(ERC1155Facet.ERC1155InsufficientBalance.selector, alice, 50, 100, TOKEN_ID_2)
        );
        facet.safeBatchTransferFrom(alice, bob, ids, transferAmounts, "");
    }

    // ============================================
    // Mint Tests (via Harness)
    // ============================================

    function test_Mint() public {
        uint256 amount = 100;

        vm.expectEmit(true, true, true, true);
        emit TransferSingle(address(this), address(0), alice, TOKEN_ID_1, amount);
        facet.mint(alice, TOKEN_ID_1, amount);

        assertEq(facet.balanceOf(alice, TOKEN_ID_1), amount);
    }

    function test_Mint_Multiple() public {
        facet.mint(alice, TOKEN_ID_1, 100);
        facet.mint(bob, TOKEN_ID_1, 200);
        facet.mint(alice, TOKEN_ID_2, 50);

        assertEq(facet.balanceOf(alice, TOKEN_ID_1), 100);
        assertEq(facet.balanceOf(bob, TOKEN_ID_1), 200);
        assertEq(facet.balanceOf(alice, TOKEN_ID_2), 50);
    }

    function test_RevertWhen_MintToZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(ERC1155Facet.ERC1155InvalidReceiver.selector, address(0)));
        facet.mint(address(0), TOKEN_ID_1, 100);
    }

    // ============================================
    // MintBatch Tests (via Harness)
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
        facet.mintBatch(alice, ids, amounts);

        assertEq(facet.balanceOf(alice, TOKEN_ID_1), 100);
        assertEq(facet.balanceOf(alice, TOKEN_ID_2), 200);
        assertEq(facet.balanceOf(alice, TOKEN_ID_3), 300);
    }

    function test_RevertWhen_MintBatchToZeroAddress() public {
        uint256[] memory ids = new uint256[](1);
        ids[0] = TOKEN_ID_1;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 100;

        vm.expectRevert(abi.encodeWithSelector(ERC1155Facet.ERC1155InvalidReceiver.selector, address(0)));
        facet.mintBatch(address(0), ids, amounts);
    }

    function test_RevertWhen_MintBatchArrayLengthMismatch() public {
        uint256[] memory ids = new uint256[](2);
        ids[0] = TOKEN_ID_1;
        ids[1] = TOKEN_ID_2;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 100;

        vm.expectRevert(abi.encodeWithSelector(ERC1155Facet.ERC1155InvalidArrayLength.selector, 2, 1));
        facet.mintBatch(alice, ids, amounts);
    }

    // ============================================
    // Burn Tests (via Harness)
    // ============================================

    function test_Burn() public {
        facet.mint(alice, TOKEN_ID_1, 100);

        vm.expectEmit(true, true, true, true);
        emit TransferSingle(address(this), alice, address(0), TOKEN_ID_1, 30);
        facet.burn(alice, TOKEN_ID_1, 30);

        assertEq(facet.balanceOf(alice, TOKEN_ID_1), 70);
    }

    function test_Burn_AllBalance() public {
        facet.mint(alice, TOKEN_ID_1, 100);

        facet.burn(alice, TOKEN_ID_1, 100);

        assertEq(facet.balanceOf(alice, TOKEN_ID_1), 0);
    }

    function test_RevertWhen_BurnFromZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(ERC1155Facet.ERC1155InvalidSender.selector, address(0)));
        facet.burn(address(0), TOKEN_ID_1, 100);
    }

    function test_RevertWhen_BurnInsufficientBalance() public {
        facet.mint(alice, TOKEN_ID_1, 100);

        vm.expectRevert(
            abi.encodeWithSelector(ERC1155Facet.ERC1155InsufficientBalance.selector, alice, 100, 150, TOKEN_ID_1)
        );
        facet.burn(alice, TOKEN_ID_1, 150);
    }

    function test_RevertWhen_BurnZeroBalance() public {
        vm.expectRevert(
            abi.encodeWithSelector(ERC1155Facet.ERC1155InsufficientBalance.selector, alice, 0, 1, TOKEN_ID_1)
        );
        facet.burn(alice, TOKEN_ID_1, 1);
    }

    // ============================================
    // BurnBatch Tests (via Harness)
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

        facet.mintBatch(alice, ids, mintAmounts);

        uint256[] memory burnAmounts = new uint256[](3);
        burnAmounts[0] = 30;
        burnAmounts[1] = 50;
        burnAmounts[2] = 100;

        vm.expectEmit(true, true, true, true);
        emit TransferBatch(address(this), alice, address(0), ids, burnAmounts);
        facet.burnBatch(alice, ids, burnAmounts);

        assertEq(facet.balanceOf(alice, TOKEN_ID_1), 70);
        assertEq(facet.balanceOf(alice, TOKEN_ID_2), 150);
        assertEq(facet.balanceOf(alice, TOKEN_ID_3), 200);
    }

    function test_RevertWhen_BurnBatchFromZeroAddress() public {
        uint256[] memory ids = new uint256[](1);
        ids[0] = TOKEN_ID_1;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 100;

        vm.expectRevert(abi.encodeWithSelector(ERC1155Facet.ERC1155InvalidSender.selector, address(0)));
        facet.burnBatch(address(0), ids, amounts);
    }

    function test_RevertWhen_BurnBatchArrayLengthMismatch() public {
        uint256[] memory ids = new uint256[](2);
        ids[0] = TOKEN_ID_1;
        ids[1] = TOKEN_ID_2;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 100;

        facet.mint(alice, TOKEN_ID_1, 100);

        vm.expectRevert(abi.encodeWithSelector(ERC1155Facet.ERC1155InvalidArrayLength.selector, 2, 1));
        facet.burnBatch(alice, ids, amounts);
    }

    function test_RevertWhen_BurnBatchInsufficientBalance() public {
        uint256[] memory ids = new uint256[](2);
        ids[0] = TOKEN_ID_1;
        ids[1] = TOKEN_ID_2;

        uint256[] memory mintAmounts = new uint256[](2);
        mintAmounts[0] = 100;
        mintAmounts[1] = 50;

        facet.mintBatch(alice, ids, mintAmounts);

        uint256[] memory burnAmounts = new uint256[](2);
        burnAmounts[0] = 50;
        burnAmounts[1] = 100; // More than balance

        vm.expectRevert(
            abi.encodeWithSelector(ERC1155Facet.ERC1155InsufficientBalance.selector, alice, 50, 100, TOKEN_ID_2)
        );
        facet.burnBatch(alice, ids, burnAmounts);
    }

    // ============================================
    // Receiver Hook Tests
    // ============================================

    function test_SafeTransferFrom_ToContractWithAcceptance() public {
        ERC1155ReceiverMock receiver = new ERC1155ReceiverMock(
            RECEIVER_SINGLE_MAGIC_VALUE, RECEIVER_BATCH_MAGIC_VALUE, ERC1155ReceiverMock.RevertType.None
        );

        facet.mint(alice, TOKEN_ID_1, 100);

        vm.prank(alice);
        facet.safeTransferFrom(alice, address(receiver), TOKEN_ID_1, 50, "");

        assertEq(facet.balanceOf(alice, TOKEN_ID_1), 50);
        assertEq(facet.balanceOf(address(receiver), TOKEN_ID_1), 50);
    }

    function test_RevertWhen_SafeTransferFrom_ToContractWithWrongReturnValue() public {
        ERC1155ReceiverMock receiver = new ERC1155ReceiverMock(
            0x00c0ffee, // Wrong return value
            RECEIVER_BATCH_MAGIC_VALUE,
            ERC1155ReceiverMock.RevertType.None
        );

        facet.mint(alice, TOKEN_ID_1, 100);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ERC1155Facet.ERC1155InvalidReceiver.selector, address(receiver)));
        facet.safeTransferFrom(alice, address(receiver), TOKEN_ID_1, 50, "");
    }

    function test_RevertWhen_SafeTransferFrom_ToContractWithRevertMessage() public {
        ERC1155ReceiverMock receiver = new ERC1155ReceiverMock(
            RECEIVER_SINGLE_MAGIC_VALUE, RECEIVER_BATCH_MAGIC_VALUE, ERC1155ReceiverMock.RevertType.RevertWithMessage
        );

        facet.mint(alice, TOKEN_ID_1, 100);

        vm.prank(alice);
        vm.expectRevert("ERC1155ReceiverMock: reverting on receive");
        facet.safeTransferFrom(alice, address(receiver), TOKEN_ID_1, 50, "");
    }

    function test_RevertWhen_SafeTransferFrom_ToContractWithRevertNoMessage() public {
        ERC1155ReceiverMock receiver = new ERC1155ReceiverMock(
            RECEIVER_SINGLE_MAGIC_VALUE, RECEIVER_BATCH_MAGIC_VALUE, ERC1155ReceiverMock.RevertType.RevertWithoutMessage
        );

        facet.mint(alice, TOKEN_ID_1, 100);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ERC1155Facet.ERC1155InvalidReceiver.selector, address(receiver)));
        facet.safeTransferFrom(alice, address(receiver), TOKEN_ID_1, 50, "");
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

        facet.mintBatch(alice, ids, amounts);

        uint256[] memory transferAmounts = new uint256[](2);
        transferAmounts[0] = 50;
        transferAmounts[1] = 100;

        vm.prank(alice);
        facet.safeBatchTransferFrom(alice, address(receiver), ids, transferAmounts, "");

        assertEq(facet.balanceOf(alice, TOKEN_ID_1), 50);
        assertEq(facet.balanceOf(alice, TOKEN_ID_2), 100);
        assertEq(facet.balanceOf(address(receiver), TOKEN_ID_1), 50);
        assertEq(facet.balanceOf(address(receiver), TOKEN_ID_2), 100);
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

        facet.mint(alice, TOKEN_ID_1, 100);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ERC1155Facet.ERC1155InvalidReceiver.selector, address(receiver)));
        facet.safeBatchTransferFrom(alice, address(receiver), ids, amounts, "");
    }

    function test_RevertWhen_SafeBatchTransferFrom_ToContractWithRevertMessage() public {
        ERC1155ReceiverMock receiver = new ERC1155ReceiverMock(
            RECEIVER_SINGLE_MAGIC_VALUE, RECEIVER_BATCH_MAGIC_VALUE, ERC1155ReceiverMock.RevertType.RevertWithMessage
        );

        uint256[] memory ids = new uint256[](1);
        ids[0] = TOKEN_ID_1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 50;

        facet.mint(alice, TOKEN_ID_1, 100);

        vm.prank(alice);
        vm.expectRevert("ERC1155ReceiverMock: reverting on batch receive");
        facet.safeBatchTransferFrom(alice, address(receiver), ids, amounts, "");
    }

    // ============================================
    // Integration Tests
    // ============================================

    function test_MintTransferBurn_Flow() public {
        // Mint to alice
        facet.mint(alice, TOKEN_ID_1, 1000);
        facet.mint(alice, TOKEN_ID_2, 500);

        // Alice transfers some to bob
        vm.prank(alice);
        facet.safeTransferFrom(alice, bob, TOKEN_ID_1, 300, "");

        // Bob transfers some to charlie
        vm.prank(bob);
        facet.safeTransferFrom(bob, charlie, TOKEN_ID_1, 100, "");

        // Burn from alice
        facet.burn(alice, TOKEN_ID_1, 200);

        // Verify final balances
        assertEq(facet.balanceOf(alice, TOKEN_ID_1), 500);
        assertEq(facet.balanceOf(alice, TOKEN_ID_2), 500);
        assertEq(facet.balanceOf(bob, TOKEN_ID_1), 200);
        assertEq(facet.balanceOf(charlie, TOKEN_ID_1), 100);
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
        facet.mintBatch(alice, ids, mintAmounts);

        // Alice transfers batch to bob
        uint256[] memory transferAmounts = new uint256[](3);
        transferAmounts[0] = 300;
        transferAmounts[1] = 400;
        transferAmounts[2] = 500;

        vm.prank(alice);
        facet.safeBatchTransferFrom(alice, bob, ids, transferAmounts, "");

        // Burn batch from alice
        uint256[] memory burnAmounts = new uint256[](3);
        burnAmounts[0] = 200;
        burnAmounts[1] = 300;
        burnAmounts[2] = 400;

        facet.burnBatch(alice, ids, burnAmounts);

        // Verify final balances
        assertEq(facet.balanceOf(alice, TOKEN_ID_1), 500);
        assertEq(facet.balanceOf(alice, TOKEN_ID_2), 1300);
        assertEq(facet.balanceOf(alice, TOKEN_ID_3), 2100);
        assertEq(facet.balanceOf(bob, TOKEN_ID_1), 300);
        assertEq(facet.balanceOf(bob, TOKEN_ID_2), 400);
        assertEq(facet.balanceOf(bob, TOKEN_ID_3), 500);
    }

    function test_ApprovalAndTransfer_Flow() public {
        facet.mint(alice, TOKEN_ID_1, 1000);

        // Alice approves bob
        vm.prank(alice);
        facet.setApprovalForAll(bob, true);

        // Bob transfers on behalf of alice
        vm.prank(bob);
        facet.safeTransferFrom(alice, charlie, TOKEN_ID_1, 300, "");

        assertEq(facet.balanceOf(alice, TOKEN_ID_1), 700);
        assertEq(facet.balanceOf(charlie, TOKEN_ID_1), 300);

        // Alice revokes approval
        vm.prank(alice);
        facet.setApprovalForAll(bob, false);

        // Bob can no longer transfer
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(ERC1155Facet.ERC1155MissingApprovalForAll.selector, bob, alice));
        facet.safeTransferFrom(alice, charlie, TOKEN_ID_1, 100, "");
    }
}
