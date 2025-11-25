// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/*
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⣀⣤⡤⣶⣾⠟⠋⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠛⠛⠓⠶⠤⣤⣀⡀
⠀⠀⠀⠀⠀⠀⠀⢠⣴⠶⠛⠿⢿⣶⣿⡋⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠉⠙⠓⠲⢦⣤⣀⣀
⠀⠀⠀⠀⢀⣴⡾⠋⠀⠀⢀⣴⠟⠁⠈⠛⣦⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠉⠉⠛⠲⢶⣄
⠀⠀⣠⣶⡿⠋⠀⠀⠀⣠⠟⠁⠀⠀⠀⣀⣨⣿⣶⣤⣀⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠙⣷⣦⡀
⣰⣾⡿⠋⠀⠀⣀⣤⣾⣥⠶⠒⠚⠋⠉⠉⠁⠀⠘⣧⠈⠉⠛⠒⠶⣤⣤⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⢻⣝⠷⣤⡀
⣿⡿⠒⠛⠋⢉⡽⠋⣿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠹⣧⠀⠀⠀⠀⠀⠀⠉⠉⠛⠒⢶⣤⣤⣤⣤⣀⣀⣀⣀⡀⠀⠀⠀⠀⠀⠀⠀⢀⣠⣤⠶⠛⠙⣟⠚⠻⢶⣄
⢻⣷⡀⢀⣴⠏⠀⠀⣿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢹⡆⠀⠀⠀⣀⣤⣤⠴⠖⠚⠋⠉⠛⢦⣄⡀⠀⠉⠉⠉⠉⠉⠉⠉⠉⣹⡿⠿⣥⡀⠀⠀⠀⠹⣆⠀⠀⠹⣧⡀
⠈⢿⡹⣿⡁⠀⠀⠀⣿⠀⠀⠀⠀⠀⠀⠀⠀⢀⣀⣤⡴⣿⣶⠛⠉⠉⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠻⢦⣄⠀⠀⠀⠀⠀⢀⡾⠋⠀⠀⠈⠙⠳⣦⡀⠀⢻⡄⠀⠀⠹⣷⡀
⠀⠈⣷⣬⣿⣦⣄⠀⣿⠀⣀⣠⣤⡴⠖⠚⠋⠉⠁⠀⠀⡏⠈⢷⣄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠉⠻⣦⡀⢀⣴⠋⠀⠀⠀⠀⠀⠀⠀⠀⠉⠳⢦⣷⡀⠀⠀⠹⣿⡄
⠀⠀⠈⠻⣆⠉⠙⣿⡙⠻⢯⣀⠀⠀⠀⠀⠀⠀⠀⠀⢸⠃⠀⠀⠙⢷⡄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣤⡿⡿⣧⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢠⡟⢿⢦⣄⠀⠹⣿⣆
⠀⠀⠀⠀⠈⢷⣄⠀⠙⢷⣄⣉⡻⣶⣄⣀⠀⠀⠀⢀⣿⠀⠀⠀⠀⠀⠻⣦⡀⠀⠀⠀⠀⠀⠀⢀⣠⡴⠞⠉⠀⢸⡇⠀⠙⠳⣦⡀⠀⠀⠀⠀⠀⠀⠀⣾⠀⠈⣧⠈⠙⢦⣽⣼
⠀⠀⠀⠀⠀⠀⠙⢧⡄⠀⠻⣯⡉⠉⠉⠛⢿⣍⡉⠉⠙⠷⣤⣀⠀⠀⠀⠈⠻⣦⠀⠀⣀⣤⠶⠋⠁⠀⠀⠀⠀⢸⠃⠀⠀⠀⠀⠙⠷⣤⡀⠀⠀⠀⣼⠃⠀⠀⠘⣦⠀⢀⣬⡿
⠀⠀⠀⠀⠀⠀⠀⠀⠻⣦⡀⢹⣷⣄⠀⠀⠀⠈⠙⢶⡶⠶⠶⠯⣭⣛⣓⡲⠶⠾⠷⠿⣭⣀⣀⠀⠀⠀⠀⠀⣀⣾⠀⠀⠀⠀⠀⠀⠀⠈⠛⢶⣄⣰⠏⠀⠀⢀⣠⡿⢟⡿⠋
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠻⣄⢻⣟⢷⡄⠀⠀⠀⠈⢷⠀⠀⠀⠀⠀⠈⠉⠓⢶⣦⠴⠶⠾⠭⣭⣍⣉⣉⠉⠉⠉⠙⠳⢶⣤⣄⣤⡴⠶⠖⠛⠋⣙⣿⠷⠿⠿⣧⣶⠟⠁
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠘⢷⣽⣆⠻⣦⡀⠀⠀⠘⣇⠀⠀⠀⠀⠀⠀⠀⣼⣷⠀⠀⠀⠀⠀⠀⠈⠉⢛⣶⠶⠛⠉⠉⠁⠀⠉⠙⣳⣶⠞⠋⠉⠀⣀⡶⠾⠋⠁
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠙⢿⣎⠌⢳⣄⠀⠀⢹⣆⠀⠀⠀⠀⠀⣼⠃⣿⠀⠀⠀⠀⠀⠀⠀⣠⠟⠁⠀⠀⠀⠀⠀⣠⣴⡿⠛⠁⢀⣤⠶⠛⠉
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠻⣦⡀⠙⣧⡀⠀⢻⡄⠀⠀⠀⣸⠇⠀⣿⠀⠀⠀⠀⠀⢠⡾⠃⠀⠀⠀⢀⣤⠾⣫⡿⢋⣀⡴⠞⠉
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠳⣆⠈⠻⣆⠈⣷⠀⠀⣰⡏⠀⠀⢻⠀⠀⠀⢀⣴⠏⠀⠀⣀⣴⠞⠋⣠⣾⣿⠾⠛⠁
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠘⢷⣄⠘⢷⡼⣇⢀⡟⠀⠀⠀⢸⠀⠀⣠⠟⠁⣠⡴⠞⠉⢀⣠⡾⠟⠋
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠙⣦⡀⠹⣿⡾⠁⠀⠀⠀⢸⣀⣾⣣⠶⠛⠁⣀⣤⠾⠋⠁
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠻⣄⠈⢿⡀⠀⠀⢀⣼⠟⠋⢀⣠⠴⠛⠉
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠘⠷⣜⣧⠀⣠⠟⣁⣴⠞⠋⠁
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠙⢿⣾⠿⠛⠉
*/

/// @title Diamond
/// @notice Implements ERC-2535 Diamond proxy pattern, allowing dynamic addition, replacement, and removal of facets
/// @author Compose <https://github.com/Perfect-Abstractions/Compose>
abstract contract Diamond {
    /// @notice Error indicating no selectors were provided for the facet.
    error NoSelectorsProvidedForFacet(address _facet);
    /// @notice Error indicating no bytecode was found at the provided address.
    error NoBytecodeAtAddress(address _contractAddress, string _message);
    /// @notice Error indicating the facet address to be removed must be the zero address.
    error RemoveFacetAddressMustBeZeroAddress(address _facet);
    /// @notice Error indicating the function to be added to the diamond already exists.
    error CannotAddFunctionToDiamondThatAlreadyExists(bytes4 _selector);
    /// @notice Error indicating the function to be replaced is immutable.
    error CannotReplaceImmutableFunction(bytes4 _selector);
    /// @notice Error indicating the function to be replaced is from the same facet.
    error CannotReplaceFunctionWithTheSameFunctionFromTheSameFacet(bytes4 _selector);
    /// @notice Error indicating the function to be replaced does not exist.
    error CannotReplaceFunctionThatDoesNotExists(bytes4 _selector);
    /// @notice Error indicating the function to be removed does not exist.
    error CannotRemoveFunctionThatDoesNotExist(bytes4 _selector);
    /// @notice Error indicating the function to be removed is immutable.
    error CannotRemoveImmutableFunction(bytes4 _selector);
    /// @notice Error indicating the initialization function reverted.
    error InitializationFunctionReverted(address _initializationContractAddress, bytes _calldata);
    /// @notice Error indicating the function does not exist.
    error FunctionDoesNotExist(bytes4 _selector);
    /// @notice Error indicating the initialization function is invalid.
    error InvalidInitialization();

    /// @notice Emitted when a facet is added, removed, or replaced.
    event DiamondCut(FacetCut[] _diamondCut, address _init, bytes _calldata);
    /// @notice Emitted when the contract is initialized.
    event Initialized(uint64 _version);

    //*//////////////////////////////////////////////////////////////////////////
    //                            INITIALIZABLE LOGIC
    //////////////////////////////////////////////////////////////////////////*//

    /// @notice Initializable storage.
    /// @custom:storage-location erc8042:compose.initializable
    struct InitializableStorage {
        /// @dev Indicates that the contract has been initialized.
        uint64 initialized;
        /// @dev Indicates that the contract is in the process of being initialized.
        bool initializing;
    }

    /// @notice Initializable storage position.
    bytes32 constant INITIALIZABLE_STORAGE_POSITION = keccak256("compose.initializable");

    /// @notice Returns the initializable storage.
    function getInitializableStorage() internal pure virtual returns (InitializableStorage storage s) {
        bytes32 position = INITIALIZABLE_STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }

    /// @notice Checks if the contract is not in the process of being initialized.
    /// @param _s The initializable storage.
    /// @return isTopLevelCall_ True if the contract is not in the process of being initialized.
    function beforeInitializer(InitializableStorage storage _s) internal virtual returns (bool isTopLevelCall_) {
        // Cache values to avoid duplicated sloads
        isTopLevelCall_ = !_s.initializing;
        uint64 initialized = _s.initialized;

        // Allowed calls:
        // - initialSetup: the contract is not in the initializing state and no previous version was
        //                 initialized
        // - construction: the contract is initialized at version 1 (no reinitialization) and the
        //                 current contract is just being deployed
        bool initialSetup = initialized == 0 && isTopLevelCall_;
        bool construction = initialized == 1 && address(this).code.length == 0;

        if (!initialSetup && !construction) {
            revert InvalidInitialization();
        }
        _s.initialized = 1;
        if (isTopLevelCall_) {
            _s.initializing = true;
        }
    }

    /// @notice Sets the initializable storage.
    /// @param _s The initializable storage.
    /// @param _isTopLevelCall True if the contract is not in the process of being initialized.
    function afterInitializer(InitializableStorage storage _s, bool _isTopLevelCall) internal virtual {
        if (_isTopLevelCall) {
            _s.initializing = false;
            emit Initialized(1);
        }
    }

    //*//////////////////////////////////////////////////////////////////////////
    //                               DIAMOND LOGIC
    //////////////////////////////////////////////////////////////////////////*//

    /// @notice Data stored for each function selector
    struct FacetAndPosition {
        /// @dev Facet address of function selector
        address facet;
        /// @dev Position of selector in the 'bytes4[] selectors' array
        uint16 position;
    }

    /// @notice Diamond storage.
    /// @custom:storage-location erc8042:compose.diamond
    struct DiamondStorage {
        /// @dev FacetAndPosition mapping stores the facet address and position of the function selector.
        mapping(bytes4 functionSelector => FacetAndPosition) facetAndPosition;
        /// @dev Array of all function selectors that can be called in the diamond.
        bytes4[] selectors;
    }

    /// @notice Diamond storage position.
    bytes32 private constant DIAMOND_STORAGE_POSITION = keccak256("compose.diamond");

    /// @notice Returns the diamond storage.
    function getStorage() internal pure virtual returns (DiamondStorage storage s) {
        bytes32 position = DIAMOND_STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }

    /// @notice Checks if the provided address has code.
    /// @param _address The address to check.
    /// @param _error The error message to throw if the address has no code.
    function checkBytecodeAtAddress(address _address, string memory _error) internal view virtual {
        if (_address.code.length == 0) {
            revert NoBytecodeAtAddress(_address, _error);
        }
    }

    /// @notice Adds functions to the diamond.
    /// @param _s Diamond storage to add functions to.
    /// @param _facet The address of the facet to add functions from.
    /// @param _functionSelectors The selectors of the functions to add.
    function addFunctions(DiamondStorage storage _s, address _facet, bytes4[] calldata _functionSelectors)
        internal
        virtual
    {
        checkBytecodeAtAddress(_facet, "LibDiamond: Add facet has no code");
        // The position to store the next selector in the selectors array
        uint16 selectorPosition = uint16(_s.selectors.length);
        uint256 functionSelectorsLength = _functionSelectors.length;
        for (uint256 selectorIndex; selectorIndex < functionSelectorsLength; ++selectorIndex) {
            bytes4 selector = _functionSelectors[selectorIndex];
            address oldFacet = _s.facetAndPosition[selector].facet;
            if (oldFacet != address(0)) {
                revert CannotAddFunctionToDiamondThatAlreadyExists(selector);
            }
            _s.facetAndPosition[selector] = FacetAndPosition(_facet, selectorPosition);
            _s.selectors.push(selector);
            ++selectorPosition;
        }
    }

    /// @notice Replaces functions in the diamond.
    /// @param _s Diamond storage to replace functions in.
    /// @param _facet The address of the facet to replace functions from.
    /// @param _functionSelectors The selectors of the functions to replace.
    function replaceFunctions(DiamondStorage storage _s, address _facet, bytes4[] calldata _functionSelectors)
        internal
        virtual
    {
        checkBytecodeAtAddress(_facet, "LibDiamond: Replace facet has no code");
        uint256 functionSelectorsLength = _functionSelectors.length;
        for (uint256 selectorIndex; selectorIndex < functionSelectorsLength; ++selectorIndex) {
            bytes4 selector = _functionSelectors[selectorIndex];
            address oldFacet = _s.facetAndPosition[selector].facet;
            // can't replace immutable functions -- functions defined directly in the diamond in this case
            if (oldFacet == address(this)) {
                revert CannotReplaceImmutableFunction(selector);
            }
            if (oldFacet == _facet) {
                revert CannotReplaceFunctionWithTheSameFunctionFromTheSameFacet(selector);
            }
            if (oldFacet == address(0)) {
                revert CannotReplaceFunctionThatDoesNotExists(selector);
            }
            // replace old facet address
            _s.facetAndPosition[selector].facet = _facet;
        }
    }

    /// @notice Removes functions from the diamond.
    /// @param _s Diamond storage to remove functions from.
    /// @param _facet The address of the facet to remove functions from.
    /// @param _functionSelectors The selectors of the functions to remove.
    function removeFunctions(DiamondStorage storage _s, address _facet, bytes4[] calldata _functionSelectors)
        internal
        virtual
    {
        if (_facet != address(0)) {
            revert RemoveFacetAddressMustBeZeroAddress(_facet);
        }
        uint256 selectorCount = _s.selectors.length;
        uint256 functionSelectorsLength = _functionSelectors.length;
        for (uint256 selectorIndex; selectorIndex < functionSelectorsLength; ++selectorIndex) {
            bytes4 selector = _functionSelectors[selectorIndex];
            FacetAndPosition memory oldFacetAndPosition = _s.facetAndPosition[selector];
            if (oldFacetAndPosition.facet == address(0)) {
                revert CannotRemoveFunctionThatDoesNotExist(selector);
            }
            // can't remove immutable functions -- functions defined directly in the diamond
            if (oldFacetAndPosition.facet == address(this)) {
                revert CannotRemoveImmutableFunction(selector);
            }
            // replace selector with last selector
            --selectorCount;
            if (oldFacetAndPosition.position != selectorCount) {
                bytes4 lastSelector = _s.selectors[selectorCount];
                _s.selectors[oldFacetAndPosition.position] = lastSelector;
                _s.facetAndPosition[lastSelector].position = oldFacetAndPosition.position;
            }
            // delete last selector
            _s.selectors.pop();
            delete _s.facetAndPosition[selector];
        }
    }

    /// @notice Enum for facet cut actions
    /// @dev Add=0, Replace=1, Remove=2
    enum FacetCutAction {
        Add,
        Replace,
        Remove
    }

    /// @notice Change in diamond
    /// @dev facetAddress, the address of the facet containing the function selectors
    ///      action, the type of action to perform on the functions (Add/Replace/Remove)
    ///      functionSelectors, the selectors of the functions to add/replace/remove
    struct FacetCut {
        address facetAddress;
        FacetCutAction action;
        bytes4[] functionSelectors;
    }

    /// @notice Add/replace/remove any number of functions and optionally execute
    ///         a function with delegatecall
    /// @param _diamondCut Contains the facet addresses and function selectors
    /// @param _init The address of the contract or facet to execute _calldata
    /// @param _calldata A function call, including function selector and arguments
    ///                  _calldata is executed with delegatecall on _init
    function diamondCut(FacetCut[] calldata _diamondCut, address _init, bytes calldata _calldata) internal virtual {
        DiamondStorage storage s = getStorage();
        uint256 diamondCutLength = _diamondCut.length;
        for (uint256 facetIndex; facetIndex < diamondCutLength; ++facetIndex) {
            bytes4[] calldata functionSelectors = _diamondCut[facetIndex].functionSelectors;
            address facetAddress = _diamondCut[facetIndex].facetAddress;
            if (functionSelectors.length == 0) {
                revert NoSelectorsProvidedForFacet(facetAddress);
            }
            FacetCutAction action = _diamondCut[facetIndex].action;
            if (action == FacetCutAction.Add) {
                addFunctions(s, facetAddress, functionSelectors);
            } else if (action == FacetCutAction.Replace) {
                replaceFunctions(s, facetAddress, functionSelectors);
            } else {
                removeFunctions(s, facetAddress, functionSelectors);
            }
        }

        emit DiamondCut(_diamondCut, _init, _calldata);

        // Initialize the diamond cut
        if (_init == address(0)) {
            return;
        }
        checkBytecodeAtAddress(_init, "LibDiamond: _init address no code");
        (bool success, bytes memory error) = _init.delegatecall(_calldata);
        if (!success) {
            if (error.length > 0) {
                // bubble up error
                assembly ("memory-safe") {
                    revert(add(error, 0x20), mload(error))
                }
            } else {
                revert InitializationFunctionReverted(_init, _calldata);
            }
        }
    }

    //*//////////////////////////////////////////////////////////////////////////
    //                                INITIALIZER
    //////////////////////////////////////////////////////////////////////////*//

    /// @notice Initializes the Diamond proxy with the provided facets and initialization parameters
    /// @param _diamondCut The diamond cut to apply.
    /// @param _init The address of the initialization contract.
    /// @param _calldata The calldata to pass to the initialization contract.
    function initialize(FacetCut[] calldata _diamondCut, address _init, bytes calldata _calldata) external payable {
        InitializableStorage storage s = getInitializableStorage();
        bool isTopLevelCall = beforeInitializer(s);
        diamondCut(_diamondCut, _init, _calldata);
        afterInitializer(s, isTopLevelCall);
    }

    /// @notice Retrieves the implementation address for the current function call
    /// @dev A Facet is one of many implementations in a Diamond Proxy
    /// @return facet_ The implementation address for the current function call
    function facet() internal view virtual returns (address facet_) {
        facet_ = getStorage().facetAndPosition[msg.sig].facet;
        if (facet_ == address(0)) revert FunctionDoesNotExist(msg.sig);
    }

    /// @notice Internal function to perform a delegatecall to an implementation
    /// @param _implementation Address of the implementation to delegate to
    function delegate(address _implementation) internal virtual {
        assembly {
            // Copy calldata to memory
            calldatacopy(0, 0, calldatasize())

            // Delegate call to implementation
            let result := delegatecall(gas(), _implementation, 0, calldatasize(), 0, 0)

            // Copy returned data
            returndatacopy(0, 0, returndatasize())

            // Revert or return based on the result
            switch result
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    //*//////////////////////////////////////////////////////////////////////////
    //                                  FALLBACK
    //////////////////////////////////////////////////////////////////////////*//

    /// @notice Fallback function that delegates calls to the appropriate facet based on function selector
    /// @dev Reads the facet address from diamond storage and performs a delegatecall; reverts if selector is not found
    fallback() external payable virtual {
        delegate(facet());
    }

    receive() external payable virtual {}
}
