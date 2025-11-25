// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {Diamond} from "@compose/Diamond.sol";

contract MinimalDiamond is Diamond {
    fallback() external payable override {
        address facet = getDiamondStorage().facetAndPosition[msg.sig].facet;
        if (facet == address(0)) {
            revert FunctionDoesNotExist(msg.sig);
        }
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), facet, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }
}
