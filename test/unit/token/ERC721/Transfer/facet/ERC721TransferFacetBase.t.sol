// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

/* Compose
 * https://compose.diamonds
 */

import {Base_Test} from "test/Base.t.sol";
import {ERC721TransferFacet} from "src/token/ERC721/Transfer/ERC721TransferFacet.sol";

contract MockERC721Receiver {}

contract ERC721TransferFacet_Base_Test is Base_Test {
    ERC721TransferFacet internal facet;

    MockERC721Receiver internal receiver;

    function setUp() public virtual override {
        Base_Test.setUp();
        facet = new ERC721TransferFacet();
        vm.label(address(facet), "ERC721TransferFacet");

        receiver = new MockERC721Receiver();
        vm.label(address(receiver), "MockERC721Receiver");
    }
}
