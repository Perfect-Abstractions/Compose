// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {
    ERC721EnumerableTransferFacet_Base_Test
} from "test/unit/token/ERC721/Enumerable/ERC721EnumerableTransferFacetBase.t.sol";
import {ERC721StorageUtils} from "test/utils/storage/ERC721StorageUtils.sol";
import {
    ERC721EnumerableTransferFacet,
    IERC721Receiver
} from "src/token/ERC721/Enumerable/Transfer/ERC721EnumerableTransferFacet.sol";

contract ERC721Enumerable_ReceiverMock is IERC721Receiver {
    enum RevertType {
        None,
        RevertWithMessage,
        RevertWithoutMessage,
        ReturnWrongSelector
    }

    RevertType public revertType;

    event Received(address operator, address from, uint256 tokenId, bytes data);

    constructor(RevertType _revertType) {
        revertType = _revertType;
    }

    function onERC721Received(address _operator, address _from, uint256 _tokenId, bytes calldata _data)
        external
        override
        returns (bytes4)
    {
        if (revertType == RevertType.RevertWithMessage) {
            revert("ERC721EnumerableReceiver: revert");
        } else if (revertType == RevertType.RevertWithoutMessage) {
            revert();
        } else if (revertType == RevertType.ReturnWrongSelector) {
            emit Received(_operator, _from, _tokenId, _data);
            return bytes4(0xDEADBEEF);
        }
        emit Received(_operator, _from, _tokenId, _data);
        return this.onERC721Received.selector;
    }
}

/**
 *  @dev BTT spec: test/trees/ERC721.tree
 */
contract Transfer_ERC721EnumerableTransferFacet_Fuzz_Unit_Test is ERC721EnumerableTransferFacet_Base_Test {
    using ERC721StorageUtils for address;

    function _seedOwnerToken(address owner, uint256 tokenId) internal {
        /* push into ownerTokens and allTokens arrays */
        uint256 ownerIndex = address(facet).balanceOf(owner);
        address(facet).setOwnerTokenByIndex(owner, ownerIndex, tokenId);
        address(facet).setOwnerTokensIndex(tokenId, ownerIndex);
        address(facet).setBalanceOf(owner, ownerIndex + 1);

        uint256 globalIndex = address(facet).allTokensLength();
        address(facet).pushAllToken(tokenId);
        address(facet).setAllTokensIndex(tokenId, globalIndex);
        address(facet).setOwnerOf(tokenId, owner);
    }

    function _seedTwoOwnerTokens(address owner, uint256 firstTokenId, uint256 secondTokenId) internal {
        uint256 ownerIndex = address(facet).balanceOf(owner);

        /* first token */
        address(facet).setOwnerTokenByIndex(owner, ownerIndex, firstTokenId);
        address(facet).setOwnerTokensIndex(firstTokenId, ownerIndex);
        address(facet).setBalanceOf(owner, ownerIndex + 1);

        /* second token */
        address(facet).setOwnerTokenByIndex(owner, ownerIndex + 1, secondTokenId);
        address(facet).setOwnerTokensIndex(secondTokenId, ownerIndex + 1);
        address(facet).setBalanceOf(owner, ownerIndex + 2);

        uint256 globalIndex = address(facet).allTokensLength();
        address(facet).pushAllToken(firstTokenId);
        address(facet).setAllTokensIndex(firstTokenId, globalIndex);

        address(facet).pushAllToken(secondTokenId);
        address(facet).setAllTokensIndex(secondTokenId, globalIndex + 1);

        address(facet).setOwnerOf(firstTokenId, owner);
        address(facet).setOwnerOf(secondTokenId, owner);
    }

    function testFuzz_ShouldUpdateEnumerationOnTransfer_WhenCallerIsOwner(address owner, address to, uint256 tokenId)
        external
    {
        vm.assume(owner != address(0));
        vm.assume(to != address(0));
        vm.assume(to != owner);
        tokenId = bound(tokenId, 1, type(uint128).max);

        _seedOwnerToken(owner, tokenId);

        vm.stopPrank();
        vm.prank(owner);
        facet.transferFrom(owner, to, tokenId);

        assertEq(address(facet).ownerOf(tokenId), to, "new owner");
        assertEq(address(facet).balanceOf(owner), 0, "old owner balance");
        assertEq(address(facet).balanceOf(to), 1, "new owner balance");
    }

    function testFuzz_ShouldUpdateEnumerationOnTransfer_WhenMovingMiddleToken(address owner, address to) external {
        vm.assume(owner != address(0));
        vm.assume(to != address(0));
        vm.assume(to != owner);

        uint256 firstTokenId = 1;
        uint256 secondTokenId = 2;

        _seedTwoOwnerTokens(owner, firstTokenId, secondTokenId);

        vm.stopPrank();
        vm.prank(owner);
        facet.transferFrom(owner, to, firstTokenId);

        /* original owner should now only own the second token at index 0 */
        assertEq(address(facet).balanceOf(owner), 1, "old owner balance");
        assertEq(address(facet).ownerTokenByIndex(owner, 0), secondTokenId, "remaining token");
        /* new owner should own the first token */
        assertEq(address(facet).balanceOf(to), 1, "new owner balance");
        assertEq(address(facet).ownerOf(firstTokenId), to, "transferred token owner");
    }

    function testFuzz_ShouldRevert_TransferFrom_WhenCallerNotOwnerOrApproved(
        address owner,
        address caller,
        address to,
        uint256 tokenId
    ) external {
        vm.assume(owner != address(0));
        vm.assume(caller != address(0));
        vm.assume(caller != owner);
        vm.assume(to != address(0));
        vm.assume(to != owner);
        tokenId = bound(tokenId, 1, type(uint128).max);

        _seedOwnerToken(owner, tokenId);

        vm.stopPrank();
        vm.prank(caller);

        vm.expectRevert(
            abi.encodeWithSelector(ERC721EnumerableTransferFacet.ERC721InsufficientApproval.selector, caller, tokenId)
        );
        facet.transferFrom(owner, to, tokenId);
    }

    function testFuzz_ShouldRevert_TransferFrom_WhenTokenDoesNotExist(address from, address to, uint256 tokenId)
        external
    {
        vm.assume(from != address(0));
        vm.assume(to != address(0));
        tokenId = bound(tokenId, 1, type(uint128).max);

        vm.expectRevert(abi.encodeWithSelector(ERC721EnumerableTransferFacet.ERC721NonexistentToken.selector, tokenId));
        facet.transferFrom(from, to, tokenId);
    }

    function testFuzz_ShouldRevert_TransferFrom_WhenToIsZeroAddress(address owner, uint256 tokenId) external {
        vm.assume(owner != address(0));
        tokenId = bound(tokenId, 1, type(uint128).max);

        _seedOwnerToken(owner, tokenId);

        vm.stopPrank();
        vm.prank(owner);

        vm.expectRevert(
            abi.encodeWithSelector(ERC721EnumerableTransferFacet.ERC721InvalidReceiver.selector, address(0))
        );
        facet.transferFrom(owner, address(0), tokenId);
    }

    function testFuzz_ShouldCallOnERC721Received_SafeTransferFrom_WhenReceiverContractAccepts(
        address owner,
        uint256 tokenId,
        bytes calldata data
    ) external {
        vm.assume(owner != address(0));
        tokenId = bound(tokenId, 1, type(uint128).max);

        _seedOwnerToken(owner, tokenId);
        ERC721Enumerable_ReceiverMock receiver =
            new ERC721Enumerable_ReceiverMock(ERC721Enumerable_ReceiverMock.RevertType.None);

        vm.stopPrank();
        vm.prank(owner);

        vm.expectEmit(true, true, true, true);
        emit ERC721Enumerable_ReceiverMock.Received(owner, owner, tokenId, data);
        facet.safeTransferFrom(owner, address(receiver), tokenId, data);

        assertEq(address(facet).ownerOf(tokenId), address(receiver), "new owner");
    }

    function testFuzz_ShouldRevert_SafeTransferFrom_WhenReceiverIsNonCompliantContract(address owner, uint256 tokenId)
        external
    {
        vm.assume(owner != address(0));
        tokenId = bound(tokenId, 1, type(uint128).max);

        _seedOwnerToken(owner, tokenId);
        ERC721Enumerable_ReceiverMock receiver =
            new ERC721Enumerable_ReceiverMock(ERC721Enumerable_ReceiverMock.RevertType.RevertWithoutMessage);

        vm.stopPrank();
        vm.prank(owner);

        vm.expectRevert(
            abi.encodeWithSelector(ERC721EnumerableTransferFacet.ERC721InvalidReceiver.selector, address(receiver))
        );
        facet.safeTransferFrom(owner, address(receiver), tokenId);
    }

    function testFuzz_ShouldRevert_SafeTransferFrom_WhenReceiverRevertsWithMessage(address owner, uint256 tokenId)
        external
    {
        vm.assume(owner != address(0));
        tokenId = bound(tokenId, 1, type(uint128).max);

        _seedOwnerToken(owner, tokenId);
        ERC721Enumerable_ReceiverMock receiver =
            new ERC721Enumerable_ReceiverMock(ERC721Enumerable_ReceiverMock.RevertType.RevertWithMessage);

        vm.stopPrank();
        vm.prank(owner);

        vm.expectRevert("ERC721EnumerableReceiver: revert");
        facet.safeTransferFrom(owner, address(receiver), tokenId);
    }

    function testFuzz_ShouldRevert_SafeTransferFrom_WhenReceiverReturnsWrongSelector(address owner, uint256 tokenId)
        external
    {
        vm.assume(owner != address(0));
        tokenId = bound(tokenId, 1, type(uint128).max);

        _seedOwnerToken(owner, tokenId);
        ERC721Enumerable_ReceiverMock receiver =
            new ERC721Enumerable_ReceiverMock(ERC721Enumerable_ReceiverMock.RevertType.ReturnWrongSelector);

        vm.stopPrank();
        vm.prank(owner);

        vm.expectRevert(
            abi.encodeWithSelector(ERC721EnumerableTransferFacet.ERC721InvalidReceiver.selector, address(receiver))
        );
        facet.safeTransferFrom(owner, address(receiver), tokenId);
    }

    function testFuzz_ShouldUpdateEnumerationOnTransfer_WhenCallerIsApproved(
        address owner,
        address approved,
        address to,
        uint256 tokenId
    ) external {
        vm.assume(owner != address(0));
        vm.assume(approved != address(0));
        vm.assume(approved != owner);
        vm.assume(to != address(0));
        vm.assume(to != owner);
        vm.assume(to != approved);
        tokenId = bound(tokenId, 1, type(uint128).max);

        _seedOwnerToken(owner, tokenId);
        address(facet).setApproved(tokenId, approved);

        vm.stopPrank();
        vm.prank(approved);
        facet.transferFrom(owner, to, tokenId);

        assertEq(address(facet).ownerOf(tokenId), to, "new owner");
        assertEq(address(facet).balanceOf(owner), 0, "old owner balance");
        assertEq(address(facet).balanceOf(to), 1, "new owner balance");
    }

    function testFuzz_ShouldUpdateEnumerationOnTransfer_WhenCallerIsOperator(
        address owner,
        address operator,
        address to,
        uint256 tokenId
    ) external {
        vm.assume(owner != address(0));
        vm.assume(operator != address(0));
        vm.assume(operator != owner);
        vm.assume(to != address(0));
        vm.assume(to != owner);
        vm.assume(to != operator);
        tokenId = bound(tokenId, 1, type(uint128).max);

        _seedOwnerToken(owner, tokenId);
        address(facet).setApprovedForAll(owner, operator, true);

        vm.stopPrank();
        vm.prank(operator);
        facet.transferFrom(owner, to, tokenId);

        assertEq(address(facet).ownerOf(tokenId), to, "new owner");
        assertEq(address(facet).balanceOf(owner), 0, "old owner balance");
        assertEq(address(facet).balanceOf(to), 1, "new owner balance");
    }
}

