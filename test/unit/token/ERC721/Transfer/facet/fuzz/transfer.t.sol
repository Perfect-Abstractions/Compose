// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC721TransferFacet_Base_Test} from "test/unit/token/ERC721/Transfer/ERC721TransferFacetBase.t.sol";
import {ERC721StorageUtils} from "test/utils/storage/ERC721StorageUtils.sol";
import {ERC721TransferFacet, IERC721Receiver} from "src/token/ERC721/Transfer/ERC721TransferFacet.sol";

contract ERC721_ReceiverMock is IERC721Receiver {
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
            revert("ERC721Receiver: revert");
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
contract Transfer_ERC721TransferFacet_Fuzz_Unit_Test is ERC721TransferFacet_Base_Test {
    using ERC721StorageUtils for address;

    function testFuzz_ShouldRevert_TransferFrom_WhenTokenDoesNotExist(address from, address to, uint256 tokenId)
        external
    {
        vm.assume(from != address(0));
        vm.assume(to != address(0));
        tokenId = bound(tokenId, 1, type(uint128).max);

        vm.expectRevert(abi.encodeWithSelector(ERC721TransferFacet.ERC721NonexistentToken.selector, tokenId));
        facet.transferFrom(from, to, tokenId);
    }

    function testFuzz_ShouldRevert_TransferFrom_WhenToIsZeroAddress(address owner, uint256 tokenId) external {
        vm.assume(owner != address(0));
        tokenId = bound(tokenId, 1, type(uint128).max);

        address(facet).mint(owner, tokenId);

        vm.stopPrank();
        vm.prank(owner);

        vm.expectRevert(abi.encodeWithSelector(ERC721TransferFacet.ERC721InvalidReceiver.selector, address(0)));
        facet.transferFrom(owner, address(0), tokenId);
    }

    function testFuzz_ShouldRevert_TransferFrom_WhenCallerIsNotOwnerOrApproved(
        address owner,
        address caller,
        address to,
        uint256 tokenId
    ) external {
        vm.assume(owner != address(0));
        vm.assume(caller != owner);
        vm.assume(caller != address(0));
        vm.assume(to != address(0));
        vm.assume(to != owner);
        tokenId = bound(tokenId, 1, type(uint128).max);

        address(facet).mint(owner, tokenId);

        vm.stopPrank();
        vm.prank(caller);

        vm.expectRevert(
            abi.encodeWithSelector(ERC721TransferFacet.ERC721InsufficientApproval.selector, caller, tokenId)
        );
        facet.transferFrom(owner, to, tokenId);
    }

    function testFuzz_ShouldRevert_TransferFrom_WhenFromIsNotOwner(
        address owner,
        address wrongFrom,
        address to,
        uint256 tokenId
    ) external {
        vm.assume(owner != address(0));
        vm.assume(wrongFrom != address(0));
        vm.assume(wrongFrom != owner);
        vm.assume(to != address(0));
        vm.assume(to != owner);
        vm.assume(to != wrongFrom);
        tokenId = bound(tokenId, 1, type(uint128).max);

        address(facet).mint(owner, tokenId);

        vm.stopPrank();
        vm.prank(owner);

        vm.expectRevert(
            abi.encodeWithSelector(ERC721TransferFacet.ERC721IncorrectOwner.selector, wrongFrom, tokenId, owner)
        );
        facet.transferFrom(wrongFrom, to, tokenId);
    }

    function testFuzz_ShouldTransfer_WhenCallerIsOwner(address owner, address to, uint256 tokenId) external {
        vm.assume(owner != address(0));
        vm.assume(to != address(0));
        vm.assume(to != owner);
        tokenId = bound(tokenId, 1, type(uint128).max);

        address(facet).mint(owner, tokenId);

        vm.stopPrank();
        vm.prank(owner);

        vm.expectEmit(address(facet));
        emit ERC721TransferFacet.Transfer(owner, to, tokenId);
        facet.transferFrom(owner, to, tokenId);

        assertEq(address(facet).ownerOf(tokenId), to, "new owner");
        assertEq(address(facet).balanceOf(owner), 0, "owner balance");
        assertEq(address(facet).balanceOf(to), 1, "receiver balance");
    }

    function testFuzz_ShouldTransfer_WhenCallerIsApproved(address owner, address approved, address to, uint256 tokenId)
        external
    {
        vm.assume(owner != address(0));
        vm.assume(approved != address(0));
        vm.assume(approved != owner);
        vm.assume(to != address(0));
        vm.assume(to != owner);
        tokenId = bound(tokenId, 1, type(uint128).max);

        address(facet).mint(owner, tokenId);
        address(facet).setApproved(tokenId, approved);

        vm.stopPrank();
        vm.prank(approved);

        vm.expectEmit(address(facet));
        emit ERC721TransferFacet.Transfer(owner, to, tokenId);
        facet.transferFrom(owner, to, tokenId);

        assertEq(address(facet).ownerOf(tokenId), to, "new owner");
        assertEq(address(facet).getApproved(tokenId), address(0), "approval cleared");
    }

    function testFuzz_ShouldTransfer_WhenCallerIsOperator(address owner, address operator, address to, uint256 tokenId)
        external
    {
        vm.assume(owner != address(0));
        vm.assume(operator != address(0));
        vm.assume(operator != owner);
        vm.assume(to != address(0));
        vm.assume(to != owner);
        tokenId = bound(tokenId, 1, type(uint128).max);

        address(facet).mint(owner, tokenId);
        address(facet).setApprovedForAll(owner, operator, true);

        vm.stopPrank();
        vm.prank(operator);

        vm.expectEmit(address(facet));
        emit ERC721TransferFacet.Transfer(owner, to, tokenId);
        facet.transferFrom(owner, to, tokenId);

        assertEq(address(facet).ownerOf(tokenId), to, "new owner");
    }

    function testFuzz_ShouldSafeTransfer_WhenReceiverIsEOA(address owner, address to, uint256 tokenId) external {
        vm.assume(owner != address(0));
        vm.assume(to != address(0));
        vm.assume(to != owner);
        vm.assume(to != address(facet));
        tokenId = bound(tokenId, 1, type(uint128).max);

        address(facet).mint(owner, tokenId);

        vm.stopPrank();
        vm.prank(owner);

        vm.expectEmit(address(facet));
        emit ERC721TransferFacet.Transfer(owner, to, tokenId);
        facet.safeTransferFrom(owner, to, tokenId);

        assertEq(address(facet).ownerOf(tokenId), to, "new owner");
    }

    function testFuzz_ShouldSafeTransferWithData_WhenReceiverIsEOA(
        address owner,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external {
        vm.assume(owner != address(0));
        vm.assume(to != address(0));
        vm.assume(to != owner);
        vm.assume(to != address(facet));
        tokenId = bound(tokenId, 1, type(uint128).max);

        address(facet).mint(owner, tokenId);

        vm.stopPrank();
        vm.prank(owner);

        vm.expectEmit(address(facet));
        emit ERC721TransferFacet.Transfer(owner, to, tokenId);
        facet.safeTransferFrom(owner, to, tokenId, data);

        assertEq(address(facet).ownerOf(tokenId), to, "new owner");
    }

    function testFuzz_ShouldRevert_SafeTransferFrom_WhenReceiverIsNonCompliantContract(address owner, uint256 tokenId)
        external
    {
        vm.assume(owner != address(0));
        tokenId = bound(tokenId, 1, type(uint128).max);

        address(facet).mint(owner, tokenId);
        ERC721_ReceiverMock receiver = new ERC721_ReceiverMock(ERC721_ReceiverMock.RevertType.RevertWithoutMessage);

        vm.stopPrank();
        vm.prank(owner);

        vm.expectRevert(abi.encodeWithSelector(ERC721TransferFacet.ERC721InvalidReceiver.selector, address(receiver)));
        facet.safeTransferFrom(owner, address(receiver), tokenId);
    }

    function testFuzz_ShouldRevert_SafeTransferFrom_WhenReceiverReturnsWrongSelector(address owner, uint256 tokenId)
        external
    {
        vm.assume(owner != address(0));
        tokenId = bound(tokenId, 1, type(uint128).max);

        address(facet).mint(owner, tokenId);
        ERC721_ReceiverMock receiver = new ERC721_ReceiverMock(ERC721_ReceiverMock.RevertType.ReturnWrongSelector);

        vm.stopPrank();
        vm.prank(owner);

        vm.expectRevert(abi.encodeWithSelector(ERC721TransferFacet.ERC721InvalidReceiver.selector, address(receiver)));
        facet.safeTransferFrom(owner, address(receiver), tokenId);
    }

    function testFuzz_ShouldRevert_SafeTransferFrom_WhenReceiverRevertsWithMessage(address owner, uint256 tokenId)
        external
    {
        vm.assume(owner != address(0));
        tokenId = bound(tokenId, 1, type(uint128).max);

        address(facet).mint(owner, tokenId);
        ERC721_ReceiverMock receiver = new ERC721_ReceiverMock(ERC721_ReceiverMock.RevertType.RevertWithMessage);

        vm.stopPrank();
        vm.prank(owner);

        vm.expectRevert("ERC721Receiver: revert");
        facet.safeTransferFrom(owner, address(receiver), tokenId);
    }

    function testFuzz_ShouldCallOnERC721Received_SafeTransferFrom_WhenReceiverAccepts_NoData(
        address owner,
        uint256 tokenId
    ) external {
        vm.assume(owner != address(0));
        tokenId = bound(tokenId, 1, type(uint128).max);

        address(facet).mint(owner, tokenId);
        ERC721_ReceiverMock receiver = new ERC721_ReceiverMock(ERC721_ReceiverMock.RevertType.None);

        vm.stopPrank();
        vm.prank(owner);

        bytes memory data = "";
        vm.expectEmit(true, true, true, true);
        emit ERC721_ReceiverMock.Received(owner, owner, tokenId, data);
        facet.safeTransferFrom(owner, address(receiver), tokenId);

        assertEq(address(facet).ownerOf(tokenId), address(receiver), "new owner");
    }

    function testFuzz_ShouldCallOnERC721Received_SafeTransferFrom_WhenReceiverAccepts(
        address owner,
        uint256 tokenId,
        bytes calldata data
    ) external {
        vm.assume(owner != address(0));
        tokenId = bound(tokenId, 1, type(uint128).max);

        address(facet).mint(owner, tokenId);
        ERC721_ReceiverMock receiver = new ERC721_ReceiverMock(ERC721_ReceiverMock.RevertType.None);

        vm.stopPrank();
        vm.prank(owner);

        vm.expectEmit(true, true, true, true);
        emit ERC721_ReceiverMock.Received(owner, owner, tokenId, data);
        facet.safeTransferFrom(owner, address(receiver), tokenId, data);

        assertEq(address(facet).ownerOf(tokenId), address(receiver), "new owner");
    }

    function testFuzz_ShouldRevert_SafeTransferFrom_WhenTokenDoesNotExist_NoData(
        address from,
        address to,
        uint256 tokenId
    ) external {
        vm.assume(from != address(0));
        vm.assume(to != address(0));
        tokenId = bound(tokenId, 1, type(uint128).max);

        vm.expectRevert(abi.encodeWithSelector(ERC721TransferFacet.ERC721NonexistentToken.selector, tokenId));
        facet.safeTransferFrom(from, to, tokenId);
    }

    function testFuzz_ShouldRevert_SafeTransferFrom_WhenTokenDoesNotExist_WithData(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external {
        vm.assume(from != address(0));
        vm.assume(to != address(0));
        tokenId = bound(tokenId, 1, type(uint128).max);

        vm.expectRevert(abi.encodeWithSelector(ERC721TransferFacet.ERC721NonexistentToken.selector, tokenId));
        facet.safeTransferFrom(from, to, tokenId, data);
    }

    function testFuzz_ShouldRevert_SafeTransferFrom_WhenToIsZeroAddress_NoData(address owner, uint256 tokenId)
        external
    {
        vm.assume(owner != address(0));
        tokenId = bound(tokenId, 1, type(uint128).max);

        address(facet).mint(owner, tokenId);

        vm.stopPrank();
        vm.prank(owner);

        vm.expectRevert(abi.encodeWithSelector(ERC721TransferFacet.ERC721InvalidReceiver.selector, address(0)));
        facet.safeTransferFrom(owner, address(0), tokenId);
    }

    function testFuzz_ShouldRevert_SafeTransferFrom_WhenToIsZeroAddress_WithData(
        address owner,
        uint256 tokenId,
        bytes calldata data
    ) external {
        vm.assume(owner != address(0));
        tokenId = bound(tokenId, 1, type(uint128).max);

        address(facet).mint(owner, tokenId);

        vm.stopPrank();
        vm.prank(owner);

        vm.expectRevert(abi.encodeWithSelector(ERC721TransferFacet.ERC721InvalidReceiver.selector, address(0)));
        facet.safeTransferFrom(owner, address(0), tokenId, data);
    }
}

