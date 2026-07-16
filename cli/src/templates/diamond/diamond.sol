// SPDX-License-Identifier: MIT
pragma solidity {{SOLIDITY_PRAGMA}};

/* Compose
 * https://compose.diamonds
 */

{{IMPORTS}}

contract {{CONTRACT_NAME}} {
    constructor(address[] memory _facets) {
{{CONSTRUCTOR_BLOCKS}}
    }

    fallback() external payable {
        DiamondMod.diamondFallback();
    }

    receive() external payable {}
}
