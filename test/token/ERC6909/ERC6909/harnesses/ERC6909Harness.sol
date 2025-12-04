// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import "../../../../../src/token/ERC6909/ERC6909/ERC6909Mod.sol" as ERC6909Mod;

/**
 * @notice Test harness that exposes LibERC6909's internal functions as external
 * @dev Required for testing since LibERC6909 only has internal functions
 */
contract ERC6909Harness {
    function mint(address _to, uint256 _id, uint256 _amount) external {
        ERC6909Mod.mint(_to, _id, _amount);
    }

    function burn(address _from, uint256 _id, uint256 _amount) external {
        ERC6909Mod.burn(_from, _id, _amount);
    }

    function transfer(address _by, address _from, address _to, uint256 _id, uint256 _amount) external {
        ERC6909Mod.transfer(_by, _from, _to, _id, _amount);
    }

    function approve(address _owner, address _spender, uint256 _id, uint256 _amount) external {
        ERC6909Mod.approve(_owner, _spender, _id, _amount);
    }

    function setOperator(address _owner, address _spender, bool _approved) external {
        ERC6909Mod.setOperator(_owner, _spender, _approved);
    }

    function balanceOf(address _owner, uint256 _id) external view returns (uint256) {
        return ERC6909Mod.getStorage().balanceOf[_owner][_id];
    }

    function allowance(address _owner, address _spender, uint256 _id) external view returns (uint256) {
        return ERC6909Mod.getStorage().allowance[_owner][_spender][_id];
    }

    function isOperator(address _owner, address _spender) external view returns (bool) {
        return ERC6909Mod.getStorage().isOperator[_owner][_spender];
    }
}
