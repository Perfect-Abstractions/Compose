// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

/* Compose
 * https://compose.diamonds
 */

import {Vm} from "forge-std/Vm.sol";
import {DiamondUpgrade_Base_Test} from "test/unit/diamond/DiamondUpgradeBase.t.sol";
import {
    DIAMOND_TEST_STORAGE_POSITION,
    DelegateTarget,
    FacetA,
    FacetB,
    FacetC
} from "test/utils/mocks/diamond/DiamondFacetMocks.sol";
import {DiamondStorageUtils} from "test/utils/storage/DiamondStorageUtils.sol";

/**
 * @dev BTT spec: test/trees/Diamond.tree
 */
abstract contract UpgradeEffectsBehavior is DiamondUpgrade_Base_Test {
    bytes32 private constant FACET_ADDED_TOPIC = keccak256("FacetAdded(address)");
    bytes32 private constant FACET_REPLACED_TOPIC = keccak256("FacetReplaced(address,address)");
    bytes32 private constant FACET_REMOVED_TOPIC = keccak256("FacetRemoved(address)");
    bytes32 private constant DIAMOND_DELEGATE_CALL_TOPIC = keccak256("DiamondDelegateCall(address,bytes)");
    bytes32 private constant DIAMOND_METADATA_TOPIC = keccak256("DiamondMetadata(bytes32,bytes)");

    function _noBytecodeAtAddressError() internal pure virtual returns (bytes4);

    function _delegateCallRevertedError() internal pure virtual returns (bytes4);

    function testFuzz_ShouldDelegatecallAndEmit(uint256 _value) external {
        bytes memory callData = abi.encodeCall(DelegateTarget.initialize, (_value));
        vm.expectEmit(target);
        emit DiamondDelegateCall(address(delegateTarget), callData);

        _upgrade(
            _emptyAddresses(),
            _emptyReplacements(),
            _emptyAddresses(),
            address(delegateTarget),
            callData,
            bytes32(0),
            bytes("")
        );

        assertEq(uint256(vm.load(target, DIAMOND_TEST_STORAGE_POSITION)), _value, "target state");
        assertEq(uint256(vm.load(address(delegateTarget), DIAMOND_TEST_STORAGE_POSITION)), 0, "delegate state");
    }

    function test_RevertWhen_DelegateHasNoBytecode() external {
        address noCodeDelegate = makeAddr("no-code delegate");

        vm.expectRevert(abi.encodeWithSelector(_noBytecodeAtAddressError(), noCodeDelegate));
        _upgrade(
            _emptyAddresses(), _emptyReplacements(), _emptyAddresses(), noCodeDelegate, bytes(""), bytes32(0), bytes("")
        );
    }

    function testFuzz_RevertWhen_DelegateBubblesError(uint256 _value) external {
        bytes memory callData = abi.encodeCall(DelegateTarget.failWithData, (_value));

        vm.expectRevert(abi.encodeWithSelector(DelegateTarget.DelegateFailure.selector, _value));
        _upgrade(
            _emptyAddresses(),
            _emptyReplacements(),
            _emptyAddresses(),
            address(delegateTarget),
            callData,
            bytes32(0),
            bytes("")
        );
    }

    function test_RevertWhen_DelegateRevertsWithoutData() external {
        bytes memory callData = abi.encodeCall(DelegateTarget.failWithoutData, ());

        vm.expectRevert(abi.encodeWithSelector(_delegateCallRevertedError(), address(delegateTarget), callData));
        _upgrade(
            _emptyAddresses(),
            _emptyReplacements(),
            _emptyAddresses(),
            address(delegateTarget),
            callData,
            bytes32(0),
            bytes("")
        );
    }

    function testFuzz_ShouldNotDelegatecallOrEmit_WhenDelegateIsZero(bytes calldata _delegateCalldata) external {
        bytes32 tag = keccak256("zero-delegate");

        vm.recordLogs();
        _upgrade(
            _emptyAddresses(), _emptyReplacements(), _emptyAddresses(), address(0), _delegateCalldata, tag, bytes("")
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(logs.length, 1, "zero delegate log count");
        _assertMetadataLog(logs[0], tag, bytes(""));
        assertNotEq(logs[0].topics[0], DIAMOND_DELEGATE_CALL_TOPIC, "delegate event omitted");
    }

    function test_ShouldNotEmitMetadata_WhenTagAndMetadataAreEmpty() external {
        vm.recordLogs();
        _upgrade(
            _emptyAddresses(), _emptyReplacements(), _emptyAddresses(), address(0), bytes(""), bytes32(0), bytes("")
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(logs.length, 0, "zero tag empty metadata log count");
    }

    function testFuzz_ShouldEmitMetadata_WhenTagIsNonzeroAndMetadataIsEmpty(bytes32 _tag) external {
        vm.assume(_tag != bytes32(0));

        _upgradeAndAssertSingleMetadata(_tag, bytes(""));
    }

    function testFuzz_ShouldEmitMetadata_WhenTagIsZeroAndMetadataIsNonempty(bytes calldata _metadata) external {
        vm.assume(_metadata.length > 0);

        _upgradeAndAssertSingleMetadata(bytes32(0), _metadata);
    }

    function testFuzz_ShouldEmitMetadata_WhenTagAndMetadataAreNonempty(bytes32 _tag, bytes calldata _metadata)
        external
    {
        vm.assume(_tag != bytes32(0));
        vm.assume(_metadata.length > 0);

        _upgradeAndAssertSingleMetadata(_tag, _metadata);
    }

    function test_ShouldApplyUpgradeEffectsInStrictOrder() external {
        address[] memory seedFacets = new address[](2);
        seedFacets[0] = address(facetA);
        seedFacets[1] = address(facetB);
        _upgrade(seedFacets, _emptyReplacements(), _emptyAddresses(), address(0), bytes(""), bytes32(0), bytes(""));

        bytes memory callData = abi.encodeCall(DelegateTarget.initialize, (42));
        bytes32 tag = keccak256("v2");
        bytes memory metadata = abi.encode("issue-339");

        vm.recordLogs();
        _upgrade(
            _singleAddress(address(facetC)),
            _singleReplacement(address(facetA), address(facetAReplacement)),
            _singleAddress(address(facetB)),
            address(delegateTarget),
            callData,
            tag,
            metadata
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(logs.length, 5, "compound upgrade log count");
        _assertFacetAddedLog(logs[0], address(facetC));
        _assertFacetReplacedLog(logs[1], address(facetA), address(facetAReplacement));
        _assertFacetRemovedLog(logs[2], address(facetB));
        _assertDelegateCallLog(logs[3], address(delegateTarget), callData);
        _assertMetadataLog(logs[4], tag, metadata);
        _assertCompoundUpgradeState();
        assertEq(uint256(vm.load(target, DIAMOND_TEST_STORAGE_POSITION)), 42, "compound delegate state");
        assertEq(uint256(vm.load(address(delegateTarget), DIAMOND_TEST_STORAGE_POSITION)), 0, "delegate target state");
    }

    function _upgradeAndAssertSingleMetadata(bytes32 _tag, bytes memory _metadata) private {
        vm.recordLogs();
        _upgrade(_emptyAddresses(), _emptyReplacements(), _emptyAddresses(), address(0), bytes(""), _tag, _metadata);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(logs.length, 1, "metadata log count");
        _assertMetadataLog(logs[0], _tag, _metadata);
    }

    function _assertCompoundUpgradeState() private view {
        (bytes4 head, bytes4 tail, uint32 facetCount, uint32 selectorCount) = DiamondStorageUtils.facetList(target);
        assertEq(head, FacetA.a1.selector, "compound head");
        assertEq(tail, FacetC.c1.selector, "compound tail");
        assertEq(facetCount, 2, "compound facetCount");
        assertEq(selectorCount, 6, "compound selectorCount");

        _assertNode(FacetA.a1.selector, address(facetAReplacement), bytes4(0), FacetC.c1.selector);
        _assertNode(FacetC.c1.selector, address(facetC), FacetA.a1.selector, bytes4(0));
        _assertSelectorOwner(FacetA.a2.selector, address(facetAReplacement));
        _assertSelectorOwner(FacetA.a3.selector, address(facetAReplacement));
        _assertNode(FacetB.b1.selector, address(0), bytes4(0), bytes4(0));
        _assertNode(FacetB.b2.selector, address(0), bytes4(0), bytes4(0));
        _assertNode(FacetB.b3.selector, address(0), bytes4(0), bytes4(0));
        _assertSelectorOwner(FacetC.c2.selector, address(facetC));
        _assertSelectorOwner(FacetC.c3.selector, address(facetC));
    }

    function _assertFacetAddedLog(Vm.Log memory _log, address _facet) private view {
        assertEq(_log.emitter, target, "added emitter");
        assertEq(_log.topics.length, 2, "added topic count");
        assertEq(_log.topics[0], FACET_ADDED_TOPIC, "added topic");
        assertEq(address(uint160(uint256(_log.topics[1]))), _facet, "added facet");
        assertEq(_log.data.length, 0, "added data length");
    }

    function _assertFacetReplacedLog(Vm.Log memory _log, address _oldFacet, address _newFacet) private view {
        assertEq(_log.emitter, target, "replaced emitter");
        assertEq(_log.topics.length, 3, "replaced topic count");
        assertEq(_log.topics[0], FACET_REPLACED_TOPIC, "replaced topic");
        assertEq(address(uint160(uint256(_log.topics[1]))), _oldFacet, "replaced old facet");
        assertEq(address(uint160(uint256(_log.topics[2]))), _newFacet, "replaced new facet");
        assertEq(_log.data.length, 0, "replaced data length");
    }

    function _assertFacetRemovedLog(Vm.Log memory _log, address _facet) private view {
        assertEq(_log.emitter, target, "removed emitter");
        assertEq(_log.topics.length, 2, "removed topic count");
        assertEq(_log.topics[0], FACET_REMOVED_TOPIC, "removed topic");
        assertEq(address(uint160(uint256(_log.topics[1]))), _facet, "removed facet");
        assertEq(_log.data.length, 0, "removed data length");
    }

    function _assertDelegateCallLog(Vm.Log memory _log, address _delegate, bytes memory _callData) private view {
        assertEq(_log.emitter, target, "delegate emitter");
        assertEq(_log.topics.length, 2, "delegate topic count");
        assertEq(_log.topics[0], DIAMOND_DELEGATE_CALL_TOPIC, "delegate topic");
        assertEq(address(uint160(uint256(_log.topics[1]))), _delegate, "delegate address");
        assertEq(_log.data, abi.encode(_callData), "delegate calldata");
    }

    function _assertMetadataLog(Vm.Log memory _log, bytes32 _tag, bytes memory _metadata) private view {
        assertEq(_log.emitter, target, "metadata emitter");
        assertEq(_log.topics.length, 2, "metadata topic count");
        assertEq(_log.topics[0], DIAMOND_METADATA_TOPIC, "metadata topic");
        assertEq(_log.topics[1], _tag, "metadata tag");
        assertEq(_log.data, abi.encode(_metadata), "metadata data");
    }
}
