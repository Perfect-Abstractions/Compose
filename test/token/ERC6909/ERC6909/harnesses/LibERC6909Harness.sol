// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {LibERC6909} from "../../../../../src/token/ERC6909/ERC6909/LibERC6909.sol";

/// @title LibERC6909Harness
/// @notice Test harness that exposes LibERC6909's internal functions as external
/// @dev Required for testing since LibERC6909 only has internal functions
contract LibERC6909Harness {
    function mint(address _to, uint256 _id, uint256 _amount) external {
        LibERC6909.mint(_to, _id, _amount);
    }

    function burn(address _from, uint256 _id, uint256 _amount) external {
        LibERC6909.burn(_from, _id, _amount);
    }

    function transfer(address _by, address _from, address _to, uint256 _id, uint256 _amount) external {
        LibERC6909.transfer(_by, _from, _to, _id, _amount);
    }

    function approve(address _owner, address _spender, uint256 _id, uint256 _amount) external {
        LibERC6909.approve(_owner, _spender, _id, _amount);
    }

    function setOperator(address _owner, address _spender, bool _approved) external {
        LibERC6909.setOperator(_owner, _spender, _approved);
    }

    function balanceOf(address _owner, uint256 _id) external view returns (uint256) {
        LibERC6909.getStorage().balanceOf[_owner][_id];
    }

    function allowance(address _owner, address _spender, uint256 _id) external view returns (uint256) {
        LibERC6909.getStorage().allowance[_owner][_spender][_id];
    }

    function isOperator(address _owner, address _spender) external view returns (bool) {
        LibERC6909.getStorage().isOperator[_owner][_spender];
    }
}
