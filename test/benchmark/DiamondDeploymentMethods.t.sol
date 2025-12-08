// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {Test} from "forge-std/Test.sol";
import {LibDiamond} from "../../src/diamond/LibDiamond.sol";

/*//////////////////////////////////////////////////////////////
                    DIAMOND IMPLEMENTATIONS
//////////////////////////////////////////////////////////////*/

// Constructor approach - uses FacetCut[] memory in constructor
contract ConstructorDiamond {
    error FunctionNotFound(bytes4 selector);
    error NoSelectorsProvidedForFacet(address _facet);
    error NoBytecodeAtAddress(address _contractAddress, string _message);
    error InitializationFunctionReverted(address _initializationContractAddress, bytes _calldata);
    error IncorrectFacetCutAction(uint8 _action);

    event DiamondCut(LibDiamond.FacetCut[] _diamondCut, address _init, bytes _calldata);

    constructor(LibDiamond.FacetCut[] memory _facets, address _init, bytes memory _initCalldata) payable {
        _diamondCutMemory(_facets, _init, _initCalldata);
    }

    function _diamondCutMemory(LibDiamond.FacetCut[] memory _diamondCut, address _init, bytes memory _calldata)
        internal
    {
        for (uint256 facetIndex; facetIndex < _diamondCut.length; facetIndex++) {
            bytes4[] memory functionSelectors = _diamondCut[facetIndex].functionSelectors;
            address facetAddress = _diamondCut[facetIndex].facetAddress;
            if (functionSelectors.length == 0) {
                revert NoSelectorsProvidedForFacet(facetAddress);
            }
            LibDiamond.FacetCutAction action = _diamondCut[facetIndex].action;
            if (action == LibDiamond.FacetCutAction.Add) {
                _addFunctionsMemory(facetAddress, functionSelectors);
            } else if (action == LibDiamond.FacetCutAction.Replace) {
                _replaceFunctionsMemory(facetAddress, functionSelectors);
            } else if (action == LibDiamond.FacetCutAction.Remove) {
                _removeFunctionsMemory(facetAddress, functionSelectors);
            } else {
                revert IncorrectFacetCutAction(uint8(action));
            }
        }
        emit DiamondCut(_diamondCut, _init, _calldata);

        if (_init == address(0)) {
            return;
        }
        if (_init.code.length == 0) {
            revert NoBytecodeAtAddress(_init, "ConstructorDiamond: _init address no code");
        }
        (bool success, bytes memory error) = _init.delegatecall(_calldata);
        if (!success) {
            if (error.length > 0) {
                assembly ("memory-safe") {
                    revert(add(error, 0x20), mload(error))
                }
            } else {
                revert InitializationFunctionReverted(_init, _calldata);
            }
        }
    }

    function _addFunctionsMemory(address _facet, bytes4[] memory _functionSelectors) internal {
        LibDiamond.DiamondStorage storage s = LibDiamond.getStorage();
        if (_facet.code.length == 0) {
            revert NoBytecodeAtAddress(_facet, "ConstructorDiamond: Add facet has no code");
        }
        uint16 selectorPosition = uint16(s.selectors.length);
        for (uint256 selectorIndex; selectorIndex < _functionSelectors.length; selectorIndex++) {
            bytes4 selector = _functionSelectors[selectorIndex];
            address oldFacet = s.facetAndPosition[selector].facet;
            if (oldFacet != address(0)) {
                revert LibDiamond.CannotAddFunctionToDiamondThatAlreadyExists(selector);
            }
            s.facetAndPosition[selector] = LibDiamond.FacetAndPosition(_facet, selectorPosition);
            s.selectors.push(selector);
            selectorPosition++;
        }
    }

    function _replaceFunctionsMemory(address _facet, bytes4[] memory _functionSelectors) internal {
        LibDiamond.DiamondStorage storage s = LibDiamond.getStorage();
        if (_facet.code.length == 0) {
            revert NoBytecodeAtAddress(_facet, "ConstructorDiamond: Replace facet has no code");
        }
        for (uint256 selectorIndex; selectorIndex < _functionSelectors.length; selectorIndex++) {
            bytes4 selector = _functionSelectors[selectorIndex];
            address oldFacet = s.facetAndPosition[selector].facet;
            if (oldFacet == address(this)) {
                revert LibDiamond.CannotReplaceImmutableFunction(selector);
            }
            if (oldFacet == _facet) {
                revert LibDiamond.CannotReplaceFunctionWithTheSameFunctionFromTheSameFacet(selector);
            }
            if (oldFacet == address(0)) {
                revert LibDiamond.CannotReplaceFunctionThatDoesNotExists(selector);
            }
            s.facetAndPosition[selector].facet = _facet;
        }
    }

    function _removeFunctionsMemory(address _facet, bytes4[] memory _functionSelectors) internal {
        LibDiamond.DiamondStorage storage s = LibDiamond.getStorage();
        uint256 selectorCount = s.selectors.length;
        if (_facet != address(0)) {
            revert LibDiamond.RemoveFacetAddressMustBeZeroAddress(_facet);
        }
        for (uint256 selectorIndex; selectorIndex < _functionSelectors.length; selectorIndex++) {
            bytes4 selector = _functionSelectors[selectorIndex];
            LibDiamond.FacetAndPosition memory oldFacetAndPosition = s.facetAndPosition[selector];
            if (oldFacetAndPosition.facet == address(0)) {
                revert LibDiamond.CannotRemoveFunctionThatDoesNotExist(selector);
            }
            if (oldFacetAndPosition.facet == address(this)) {
                revert LibDiamond.CannotRemoveImmutableFunction(selector);
            }
            selectorCount--;
            if (oldFacetAndPosition.position != selectorCount) {
                bytes4 lastSelector = s.selectors[selectorCount];
                s.selectors[oldFacetAndPosition.position] = lastSelector;
                s.facetAndPosition[lastSelector].position = oldFacetAndPosition.position;
            }
            s.selectors.pop();
            delete s.facetAndPosition[selector];
        }
    }

    fallback() external payable {
        LibDiamond.DiamondStorage storage s = LibDiamond.getStorage();
        address facet = s.facetAndPosition[msg.sig].facet;
        if (facet == address(0)) revert FunctionNotFound(msg.sig);

        assembly {
            calldatacopy(0, 0, calldatasize())
            let ok := delegatecall(gas(), facet, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch ok
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    receive() external payable {}
}

// Initialize approach - uses FacetCut[] calldata in external function
contract InitializeDiamond {
    error FunctionNotFound(bytes4 selector);
    error AlreadyInitialized();

    bool private _initialized;

    constructor() payable {}

    function initialize(LibDiamond.FacetCut[] calldata _facets, address _init, bytes calldata _initCalldata)
        external
        payable
    {
        if (_initialized) revert AlreadyInitialized();
        _initialized = true;
        LibDiamond.diamondCut(_facets, _init, _initCalldata);
    }

    fallback() external payable {
        LibDiamond.DiamondStorage storage s = LibDiamond.getStorage();
        address facet = s.facetAndPosition[msg.sig].facet;
        if (facet == address(0)) revert FunctionNotFound(msg.sig);

        assembly {
            calldatacopy(0, 0, calldatasize())
            let ok := delegatecall(gas(), facet, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch ok
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    receive() external payable {}
}

// Mock facet with 12 functions for testing
contract MockFacet {
    function function01() external pure returns (uint256) {
        return 1;
    }

    function function02() external pure returns (uint256) {
        return 2;
    }

    function function03() external pure returns (uint256) {
        return 3;
    }

    function function04() external pure returns (uint256) {
        return 4;
    }

    function function05() external pure returns (uint256) {
        return 5;
    }

    function function06() external pure returns (uint256) {
        return 6;
    }

    function function07() external pure returns (uint256) {
        return 7;
    }

    function function08() external pure returns (uint256) {
        return 8;
    }

    function function09() external pure returns (uint256) {
        return 9;
    }

    function function10() external pure returns (uint256) {
        return 10;
    }

    function function11() external pure returns (uint256) {
        return 11;
    }

    function function12() external pure returns (uint256) {
        return 12;
    }
}

/*//////////////////////////////////////////////////////////////
                        TEST CONTRACT
//////////////////////////////////////////////////////////////*/

// Gas benchmark comparing constructor vs initialize approaches for diamond deployment
// Tests scenarios: 10, 50, and 100 facets with 12 selectors each
contract DiamondDeploymentGasBenchmarkTest is Test {
    uint256 constant SELECTORS_PER_FACET = 12;

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _deployFacets(uint256 count) internal returns (address[] memory facets) {
        facets = new address[](count);
        for (uint256 i = 0; i < count; i++) {
            facets[i] = address(new MockFacet());
        }
    }

    function _generateSelectorsForFacet(uint256 facetIndex) internal pure returns (bytes4[] memory selectors) {
        selectors = new bytes4[](SELECTORS_PER_FACET);
        for (uint256 i = 0; i < SELECTORS_PER_FACET; i++) {
            selectors[i] = bytes4(keccak256(abi.encodePacked("facet", facetIndex, "func", i)));
        }
    }

    function _buildFacetCuts(address[] memory facets) internal pure returns (LibDiamond.FacetCut[] memory cuts) {
        cuts = new LibDiamond.FacetCut[](facets.length);
        for (uint256 i = 0; i < facets.length; i++) {
            bytes4[] memory selectors = _generateSelectorsForFacet(i);
            cuts[i] = LibDiamond.FacetCut({
                facetAddress: facets[i], action: LibDiamond.FacetCutAction.Add, functionSelectors: selectors
            });
        }
    }

    /*//////////////////////////////////////////////////////////////
                             GAS BENCHMARKS
    //////////////////////////////////////////////////////////////*/

    function testGas_Constructor_010Facets() external {
        address[] memory facets = _deployFacets(10);
        LibDiamond.FacetCut[] memory cuts = _buildFacetCuts(facets);

        uint256 startGas = gasleft();
        ConstructorDiamond diamond = new ConstructorDiamond(cuts, address(0), "");
        uint256 gasUsed = startGas - gasleft();

        emit log_named_uint("Constructor (10 facets, 120 selectors) - Total Gas", gasUsed);

        assertTrue(address(diamond) != address(0));
    }

    function testGas_Constructor_050Facets() external {
        address[] memory facets = _deployFacets(50);
        LibDiamond.FacetCut[] memory cuts = _buildFacetCuts(facets);

        uint256 startGas = gasleft();
        ConstructorDiamond diamond = new ConstructorDiamond(cuts, address(0), "");
        uint256 gasUsed = startGas - gasleft();

        emit log_named_uint("Constructor (50 facets, 600 selectors) - Total Gas", gasUsed);

        assertTrue(address(diamond) != address(0));
    }

    function testGas_Constructor_100Facets() external {
        address[] memory facets = _deployFacets(100);
        LibDiamond.FacetCut[] memory cuts = _buildFacetCuts(facets);

        uint256 startGas = gasleft();
        ConstructorDiamond diamond = new ConstructorDiamond(cuts, address(0), "");
        uint256 gasUsed = startGas - gasleft();

        emit log_named_uint("Constructor (100 facets, 1200 selectors) - Total Gas", gasUsed);

        assertTrue(address(diamond) != address(0));
    }

    function testGas_Initialize_010Facets() external {
        address[] memory facets = _deployFacets(10);
        LibDiamond.FacetCut[] memory cuts = _buildFacetCuts(facets);

        uint256 startGas = gasleft();
        InitializeDiamond diamond = new InitializeDiamond();
        uint256 deployGas = startGas - gasleft();

        startGas = gasleft();
        diamond.initialize(cuts, address(0), "");
        uint256 initGas = startGas - gasleft();

        uint256 totalGas = deployGas + initGas;

        emit log_named_uint("Initialize (10 facets, 120 selectors) - Deploy Gas", deployGas);
        emit log_named_uint("Initialize (10 facets, 120 selectors) - Init Gas", initGas);
        emit log_named_uint("Initialize (10 facets, 120 selectors) - Total Gas", totalGas);

        assertTrue(address(diamond) != address(0));
    }

    function testGas_Initialize_050Facets() external {
        address[] memory facets = _deployFacets(50);
        LibDiamond.FacetCut[] memory cuts = _buildFacetCuts(facets);

        uint256 startGas = gasleft();
        InitializeDiamond diamond = new InitializeDiamond();
        uint256 deployGas = startGas - gasleft();

        startGas = gasleft();
        diamond.initialize(cuts, address(0), "");
        uint256 initGas = startGas - gasleft();

        uint256 totalGas = deployGas + initGas;

        emit log_named_uint("Initialize (50 facets, 600 selectors) - Deploy Gas", deployGas);
        emit log_named_uint("Initialize (50 facets, 600 selectors) - Init Gas", initGas);
        emit log_named_uint("Initialize (50 facets, 600 selectors) - Total Gas", totalGas);

        assertTrue(address(diamond) != address(0));
    }

    function testGas_Initialize_100Facets() external {
        address[] memory facets = _deployFacets(100);
        LibDiamond.FacetCut[] memory cuts = _buildFacetCuts(facets);

        uint256 startGas = gasleft();
        InitializeDiamond diamond = new InitializeDiamond();
        uint256 deployGas = startGas - gasleft();

        startGas = gasleft();
        diamond.initialize(cuts, address(0), "");
        uint256 initGas = startGas - gasleft();

        uint256 totalGas = deployGas + initGas;

        emit log_named_uint("Initialize (100 facets, 1200 selectors) - Deploy Gas", deployGas);
        emit log_named_uint("Initialize (100 facets, 1200 selectors) - Init Gas", initGas);
        emit log_named_uint("Initialize (100 facets, 1200 selectors) - Total Gas", totalGas);

        assertTrue(address(diamond) != address(0));
    }
}
