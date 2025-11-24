// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {Diamond} from "@compose/Diamond.sol";

// Adapted from: https://github.com/mudgen/diamond-1-hardhat/blob/main/contracts/Diamond.sol

contract MinimalDiamond is Diamond {
    constructor(Diamond.FacetCut[] memory _diamondCut, address _init, bytes memory _calldata)
        payable
        Diamond(_diamondCut, _init, _calldata)
    {}
}
