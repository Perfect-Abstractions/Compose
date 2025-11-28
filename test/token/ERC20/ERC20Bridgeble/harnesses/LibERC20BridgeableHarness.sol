// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {LibERC20Bridgeable} from "../../../../../src/token/ERC20/ERC20Bridgeable/LibERC20Bridgeable.sol";

contract LibERC20BridgeableHarness {
    
    function crosschainMint(address _to, uint256 _amount) external {
        LibERC20Bridgeable.crosschainMint(_to, _amount);
    }

    function balanceOf(address _account) external view returns (uint256) {
        LibERC20Bridgeable.ERC20Storage storage s = LibERC20Bridgeable.getERC20Storage();
        return s.balanceOf[_account];
    }

    function crosschainBurn(address _from, uint256 _amount) external {
        LibERC20Bridgeable.crosschainBurn(_from, _amount);
    }

    function checkTokenBridge(address _caller) external view {
        LibERC20Bridgeable.checkTokenBridge(_caller);
    }

    function setRole(address account, bytes32 role, bool value) external {
    LibERC20Bridgeable.AccessControlStorage storage acs = LibERC20Bridgeable.getAccessControlStorage();
    acs.hasRole[account][role] = value;
}

}