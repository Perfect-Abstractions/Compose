// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

/* Compose
 * https://compose.diamonds
 */

import {DiamondInspectFacet} from "src/diamond/DiamondInspectFacet.sol";
import {DiamondUpgradeFacet} from "src/diamond/DiamondUpgradeFacet.sol";
import {Base_Test} from "test/Base.t.sol";
import {DiamondProxyHarness} from "test/utils/harnesses/diamond/DiamondProxyHarness.sol";
import {FacetA, FacetAReplacement, FacetB, FacetC} from "test/utils/mocks/diamond/DiamondFacetMocks.sol";

interface IDiamondInspect {
    struct Facet {
        address facet;
        bytes4[] functionSelectors;
    }

    function facetAddress(bytes4 _selector) external view returns (address);

    function facetFunctionSelectors(address _facet) external view returns (bytes4[] memory);

    function facetAddresses() external view returns (address[] memory);

    function facets() external view returns (Facet[] memory);
}

interface IDiamondUpgrade {
    struct FacetReplacement {
        address oldFacet;
        address newFacet;
    }

    function upgradeDiamond(
        address[] calldata _adds,
        FacetReplacement[] calldata _replacements,
        address[] calldata _removes,
        address _delegate,
        bytes calldata _delegateCalldata,
        bytes32 _tag,
        bytes calldata _metadata
    ) external;
}

/**
 * @dev BTT spec: test/trees/Diamond.tree
 */
abstract contract Diamond_Base_Test is Base_Test {
    DiamondProxyHarness internal proxy;
    DiamondUpgradeFacet internal upgradeFacet;
    DiamondInspectFacet internal inspectFacet;
    DiamondInspectFacet internal isolatedInspectFacet;

    IDiamondUpgrade internal upgrade;
    IDiamondInspect internal inspect;

    FacetA internal facetA;
    FacetAReplacement internal facetAReplacement;
    FacetB internal facetB;
    FacetC internal facetC;

    function setUp() public virtual override {
        Base_Test.setUp();

        upgradeFacet = new DiamondUpgradeFacet();
        inspectFacet = new DiamondInspectFacet();
        isolatedInspectFacet = new DiamondInspectFacet();
        facetA = new FacetA();
        facetAReplacement = new FacetAReplacement();
        facetB = new FacetB();
        facetC = new FacetC();

        address[] memory baselineFacets = new address[](2);
        baselineFacets[0] = address(upgradeFacet);
        baselineFacets[1] = address(inspectFacet);
        proxy = new DiamondProxyHarness(baselineFacets, users.alice);

        upgrade = IDiamondUpgrade(address(proxy));
        inspect = IDiamondInspect(address(proxy));
    }

    function _addFacet(address _facet) internal {
        upgrade.upgradeDiamond(
            _singleAddress(_facet),
            _emptyReplacements(),
            _emptyAddresses(),
            address(0),
            bytes(""),
            bytes32(0),
            bytes("")
        );
    }

    function _addFacets(address _a, address _b, address _c) internal {
        address[] memory adds = new address[](3);
        adds[0] = _a;
        adds[1] = _b;
        adds[2] = _c;
        upgrade.upgradeDiamond(
            adds, _emptyReplacements(), _emptyAddresses(), address(0), bytes(""), bytes32(0), bytes("")
        );
    }

    function _replaceFacet(address _oldFacet, address _newFacet) internal {
        IDiamondUpgrade.FacetReplacement[] memory replacements = new IDiamondUpgrade.FacetReplacement[](1);
        replacements[0] = IDiamondUpgrade.FacetReplacement({oldFacet: _oldFacet, newFacet: _newFacet});
        upgrade.upgradeDiamond(
            _emptyAddresses(), replacements, _emptyAddresses(), address(0), bytes(""), bytes32(0), bytes("")
        );
    }

    function _removeFacet(address _facet) internal {
        upgrade.upgradeDiamond(
            _emptyAddresses(),
            _emptyReplacements(),
            _singleAddress(_facet),
            address(0),
            bytes(""),
            bytes32(0),
            bytes("")
        );
    }

    function _emptyAddresses() internal pure returns (address[] memory values) {
        values = new address[](0);
    }

    function _emptyReplacements() internal pure returns (IDiamondUpgrade.FacetReplacement[] memory values) {
        values = new IDiamondUpgrade.FacetReplacement[](0);
    }

    function _singleAddress(address _value) internal pure returns (address[] memory values) {
        values = new address[](1);
        values[0] = _value;
    }

    function _assertSelectors(bytes4[] memory _actual, bytes memory _expectedPacked, string memory _message)
        internal
        pure
    {
        uint256 expectedLength = _expectedPacked.length / 4;
        assertEq(_actual.length, expectedLength, string.concat(_message, " length"));
        for (uint256 i; i < expectedLength; i++) {
            bytes4 expected;
            assembly ("memory-safe") {
                expected := mload(add(add(_expectedPacked, 0x20), mul(i, 4)))
            }
            assertEq(_actual[i], expected, string.concat(_message, " selector"));
        }
    }

    function _upgradeSelectors() internal pure returns (bytes memory) {
        return bytes.concat(DiamondUpgradeFacet.upgradeDiamond.selector);
    }

    function _inspectSelectors() internal pure returns (bytes memory) {
        return bytes.concat(
            DiamondInspectFacet.facetAddress.selector,
            DiamondInspectFacet.facetFunctionSelectors.selector,
            DiamondInspectFacet.facetAddresses.selector,
            DiamondInspectFacet.facets.selector
        );
    }
}
