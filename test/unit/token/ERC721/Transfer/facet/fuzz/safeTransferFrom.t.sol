// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC721TransferFacet_Base_Test} from "../ERC721TransferFacetBase.t.sol";
import {ERC721StorageUtils} from "test/utils/storage/ERC721StorageUtils.sol";

import {IERC721Receiver, ERC721TransferFacet} from "src/token/ERC721/Transfer/ERC721TransferFacet.sol";

/**
 * @dev BTT spec: test/trees/ERC721.tree
 */
contract SafeTransferFrom_ERC721TransferFacet_Fuzz_Unit_Test is ERC721TransferFacet_Base_Test {
    using ERC721StorageUtils for address;

    /*//////////////////////////////////////////////////////////////
                    SAFE TRANSFER FROM (WITHOUT DATA)
    //////////////////////////////////////////////////////////////*/

    function testFuzz_SafeTransferFrom_ShouldRevert_TokenDoesNotExist(address from, address to, uint256 tokenId)
        external
    {
        vm.assume(to != ADDRESS_ZERO);

        vm.expectRevert(abi.encodeWithSelector(ERC721TransferFacet.ERC721NonexistentToken.selector, tokenId));
        facet.safeTransferFrom(from, to, tokenId);
    }

    function testFuzz_SafeTransferFrom_ShouldRevert_FromNotOwner(address from, address to, uint256 tokenId)
        external
        whenTokenExists
    {
        vm.assume(to != ADDRESS_ZERO);
        vm.assume(from != ADDRESS_ZERO);
        vm.assume(from != users.alice);

        address(facet).mint(users.alice, tokenId);

        vm.expectRevert(
            abi.encodeWithSelector(ERC721TransferFacet.ERC721IncorrectOwner.selector, from, tokenId, users.alice)
        );
        facet.safeTransferFrom(from, to, tokenId);
    }

    function testFuzz_SafeTransferFrom_ShouldRevert_ToIsZeroAddress(uint256 tokenId)
        external
        whenTokenExists
        whenFromIsOwner
    {
        address(facet).mint(users.alice, tokenId);

        vm.expectRevert(abi.encodeWithSelector(ERC721TransferFacet.ERC721InvalidReceiver.selector, ADDRESS_ZERO));
        facet.safeTransferFrom(users.alice, ADDRESS_ZERO, tokenId);
    }

    function testFuzz_SafeTransferFrom_ShouldRevert_CallerNotAuthorized(address owner, address to, uint256 tokenId)
        external
        whenTokenExists
        whenFromIsOwner
        whenToNotZeroAddress
    {
        vm.assume(owner != ADDRESS_ZERO);
        vm.assume(owner != users.alice);
        vm.assume(to != ADDRESS_ZERO);

        address(facet).mint(owner, tokenId);

        vm.expectRevert(
            abi.encodeWithSelector(ERC721TransferFacet.ERC721InsufficientApproval.selector, users.alice, tokenId)
        );
        facet.safeTransferFrom(owner, to, tokenId);
    }

    function testFuzz_SafeTransferFrom_ShouldRevert_ReceiverDoesNotImplement(uint256 tokenId)
        external
        whenTokenExists
        whenFromIsOwner
        whenToNotZeroAddress
        whenCallerIsAuthorized
    {
        address(facet).mint(users.alice, tokenId);

        vm.expectRevert(abi.encodeWithSelector(ERC721TransferFacet.ERC721InvalidReceiver.selector, address(receiver)));
        facet.safeTransferFrom(users.alice, address(receiver), tokenId);
    }

    function testFuzz_SafeTransferFrom_ShouldRevert_ReceiverReturnsIncorrectValue(uint256 tokenId, bytes4 returnedSelector)
        external
        whenTokenExists
        whenFromIsOwner
        whenToNotZeroAddress
        whenCallerIsAuthorized
    {
        vm.assume(returnedSelector != IERC721Receiver.onERC721Received.selector);

        address(facet).mint(users.alice, tokenId);

        vm.mockCall(
            address(receiver),
            abi.encodeWithSelector(IERC721Receiver.onERC721Received.selector),
            abi.encode(returnedSelector)
        );

        vm.expectRevert(abi.encodeWithSelector(ERC721TransferFacet.ERC721InvalidReceiver.selector, address(receiver)));
        facet.safeTransferFrom(users.alice, address(receiver), tokenId);
    }

    function testFuzz_SafeTransferFrom_ToEOA(address to, uint256 tokenId)
        external
        whenTokenExists
        whenFromIsOwner
        whenToNotZeroAddress
        whenCallerIsAuthorized
    {
        vm.assume(to != ADDRESS_ZERO);
        vm.assume(to != users.alice);
        vm.assume(to.code.length == 0);

        address(facet).mint(users.alice, tokenId);

        uint256 senderBalanceBefore = address(facet).balanceOf(users.alice);
        uint256 receiverBalanceBefore = address(facet).balanceOf(to);

        vm.expectEmit(address(facet));
        emit ERC721TransferFacet.Transfer(users.alice, to, tokenId);
        facet.safeTransferFrom(users.alice, to, tokenId);

        assertEq(address(facet).ownerOf(tokenId), to, "ownerOf(tokenId)");
        assertEq(address(facet).balanceOf(users.alice), senderBalanceBefore - 1, "balanceOf(from)");
        assertEq(address(facet).balanceOf(to), receiverBalanceBefore + 1, "balanceOf(to)");
        assertEq(address(facet).getApproved(tokenId), ADDRESS_ZERO, "getApproved(tokenId)");
    }

    function testFuzz_SafeTransferFrom_ToContractWithCorrectSelector(uint256 tokenId)
        external
        whenTokenExists
        whenFromIsOwner
        whenToNotZeroAddress
        whenCallerIsAuthorized
    {
        address(facet).mint(users.alice, tokenId);

        uint256 senderBalanceBefore = address(facet).balanceOf(users.alice);

        vm.mockCall(
            address(receiver),
            abi.encodeWithSelector(IERC721Receiver.onERC721Received.selector),
            abi.encode(IERC721Receiver.onERC721Received.selector)
        );

        vm.expectEmit(address(facet));
        emit ERC721TransferFacet.Transfer(users.alice, address(receiver), tokenId);
        facet.safeTransferFrom(users.alice, address(receiver), tokenId);

        assertEq(address(facet).ownerOf(tokenId), address(receiver), "ownerOf(tokenId)");
        assertEq(address(facet).balanceOf(users.alice), senderBalanceBefore - 1, "balanceOf(from)");
        assertEq(address(facet).balanceOf(address(receiver)), 1, "balanceOf(to)");
        assertEq(address(facet).getApproved(tokenId), ADDRESS_ZERO, "getApproved(tokenId)");
    }

    /*//////////////////////////////////////////////////////////////
                    SAFE TRANSFER FROM (WITH DATA)
    //////////////////////////////////////////////////////////////*/

    function testFuzz_SafeTransferFromWithData_ShouldRevert_TokenDoesNotExist(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external {
        vm.assume(to != ADDRESS_ZERO);

        vm.expectRevert(abi.encodeWithSelector(ERC721TransferFacet.ERC721NonexistentToken.selector, tokenId));
        facet.safeTransferFrom(from, to, tokenId, data);
    }

    function testFuzz_SafeTransferFromWithData_ShouldRevert_FromNotOwner(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external whenTokenExists {
        vm.assume(to != ADDRESS_ZERO);
        vm.assume(from != ADDRESS_ZERO);
        vm.assume(from != users.alice);

        address(facet).mint(users.alice, tokenId);

        vm.expectRevert(
            abi.encodeWithSelector(ERC721TransferFacet.ERC721IncorrectOwner.selector, from, tokenId, users.alice)
        );
        facet.safeTransferFrom(from, to, tokenId, data);
    }

    function testFuzz_SafeTransferFromWithData_ShouldRevert_ToIsZeroAddress(uint256 tokenId, bytes calldata data)
        external
        whenTokenExists
        whenFromIsOwner
    {
        address(facet).mint(users.alice, tokenId);

        vm.expectRevert(abi.encodeWithSelector(ERC721TransferFacet.ERC721InvalidReceiver.selector, ADDRESS_ZERO));
        facet.safeTransferFrom(users.alice, ADDRESS_ZERO, tokenId, data);
    }

    function testFuzz_SafeTransferFromWithData_ShouldRevert_CallerNotAuthorized(
        address owner,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external whenTokenExists whenFromIsOwner whenToNotZeroAddress {
        vm.assume(owner != ADDRESS_ZERO);
        vm.assume(owner != users.alice);
        vm.assume(to != ADDRESS_ZERO);

        address(facet).mint(owner, tokenId);

        vm.expectRevert(
            abi.encodeWithSelector(ERC721TransferFacet.ERC721InsufficientApproval.selector, users.alice, tokenId)
        );
        facet.safeTransferFrom(owner, to, tokenId, data);
    }

    function testFuzz_SafeTransferFromWithData_ShouldRevert_ReceiverDoesNotImplement(
        uint256 tokenId,
        bytes calldata data
    ) external whenTokenExists whenFromIsOwner whenToNotZeroAddress whenCallerIsAuthorized {
        address(facet).mint(users.alice, tokenId);

        vm.expectRevert(abi.encodeWithSelector(ERC721TransferFacet.ERC721InvalidReceiver.selector, address(receiver)));
        facet.safeTransferFrom(users.alice, address(receiver), tokenId, data);
    }

    function testFuzz_SafeTransferFromWithData_ShouldRevert_ReceiverReturnsIncorrectValue(
        uint256 tokenId,
        bytes calldata data,
        bytes4 returnedSelector
    ) external whenTokenExists whenFromIsOwner whenToNotZeroAddress whenCallerIsAuthorized {
        vm.assume(returnedSelector != IERC721Receiver.onERC721Received.selector);

        address(facet).mint(users.alice, tokenId);

        vm.mockCall(
            address(receiver),
            abi.encodeWithSelector(IERC721Receiver.onERC721Received.selector),
            abi.encode(returnedSelector)
        );

        vm.expectRevert(abi.encodeWithSelector(ERC721TransferFacet.ERC721InvalidReceiver.selector, address(receiver)));
        facet.safeTransferFrom(users.alice, address(receiver), tokenId, data);
    }

    function testFuzz_SafeTransferFromWithData_ToEOA(address to, uint256 tokenId, bytes calldata data)
        external
        whenTokenExists
        whenFromIsOwner
        whenToNotZeroAddress
        whenCallerIsAuthorized
    {
        vm.assume(to != ADDRESS_ZERO);
        vm.assume(to != users.alice);
        vm.assume(to.code.length == 0);

        address(facet).mint(users.alice, tokenId);

        uint256 senderBalanceBefore = address(facet).balanceOf(users.alice);
        uint256 receiverBalanceBefore = address(facet).balanceOf(to);

        vm.expectEmit(address(facet));
        emit ERC721TransferFacet.Transfer(users.alice, to, tokenId);
        facet.safeTransferFrom(users.alice, to, tokenId, data);

        assertEq(address(facet).ownerOf(tokenId), to, "ownerOf(tokenId)");
        assertEq(address(facet).balanceOf(users.alice), senderBalanceBefore - 1, "balanceOf(from)");
        assertEq(address(facet).balanceOf(to), receiverBalanceBefore + 1, "balanceOf(to)");
        assertEq(address(facet).getApproved(tokenId), ADDRESS_ZERO, "getApproved(tokenId)");
    }

    function testFuzz_SafeTransferFromWithData_ToContractWithCorrectSelector(uint256 tokenId, bytes calldata data)
        external
        whenTokenExists
        whenFromIsOwner
        whenToNotZeroAddress
        whenCallerIsAuthorized
    {
        address(facet).mint(users.alice, tokenId);

        uint256 senderBalanceBefore = address(facet).balanceOf(users.alice);

        vm.mockCall(
            address(receiver),
            abi.encodeWithSelector(IERC721Receiver.onERC721Received.selector),
            abi.encode(IERC721Receiver.onERC721Received.selector)
        );

        vm.expectEmit(address(facet));
        emit ERC721TransferFacet.Transfer(users.alice, address(receiver), tokenId);
        facet.safeTransferFrom(users.alice, address(receiver), tokenId, data);

        assertEq(address(facet).ownerOf(tokenId), address(receiver), "ownerOf(tokenId)");
        assertEq(address(facet).balanceOf(users.alice), senderBalanceBefore - 1, "balanceOf(from)");
        assertEq(address(facet).balanceOf(address(receiver)), 1, "balanceOf(to)");
        assertEq(address(facet).getApproved(tokenId), ADDRESS_ZERO, "getApproved(tokenId)");
    }
}
