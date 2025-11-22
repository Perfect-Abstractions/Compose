// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {ERC6909Facet} from "../../../../../src/token/ERC6909/ERC6909/ERC6909Facet.sol";

/// @title ERC6909FacetHarness
/// @notice Test harness for ERC6909Facet that adds initialization and minting for testing
contract ERC6909FacetHarness is ERC6909Facet {
    function mint(address _to, uint256 _id, uint256 _amount) external {
        ERC6909Storage storage s = getStorage();

        s.balanceOf[_to][_id] += _amount;

        emit Transfer(msg.sender, address(0), _to, _id, _amount);
    }
}
