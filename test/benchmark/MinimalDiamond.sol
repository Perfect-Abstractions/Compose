// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import "../../src/diamond/DiamondCutMod.sol" as DiamondCut;

/**
 *  Adapted from: https://github.com/mudgen/diamond-1-hardhat/blob/main/contracts/Diamond.sol
 */

contract MinimalDiamond {
    error FunctionNotFound(bytes4 selector);

    struct DiamondArgs {
        address init;
        bytes initCalldata;
    }

    function initialize(DiamondCut.FacetCut[] calldata _diamondCut, DiamondArgs calldata _args) public payable {
        DiamondCut.diamondCut(_diamondCut, _args.init, _args.initCalldata);
    }

    fallback() external payable {
        DiamondCut.DiamondStorage storage s = DiamondCut.getStorage();
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
