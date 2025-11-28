// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {ERC20BridgeableFacet} from "../../../../../src/token/ERC20/ERC20Bridgeable/ERC20BridgeableFacet.sol";

contract ERC20BridgeableHarness is ERC20BridgeableFacet {
    /**
     * @notice Sets or unsets a specific role for an account.
     * @param account The address of the account to modify.
     * @param role The bytes32 identifier of the role.
     * @param value Set to true to grant the role, or false to revoke.
     */
    function setRole(address account, bytes32 role, bool value) external {
        ERC20BridgeableFacet.AccessControlStorage storage acs = ERC20BridgeableFacet.getAccessControlStorage();
        acs.hasRole[account][role] = value;
    }

    /**
     * @notice Gets the balance of a specified account.
     * @param _account The address of the account to query.
     * @return The balance of the specified account.
     */
    function balanceOf(address _account) external view returns (uint256) {
        ERC20BridgeableFacet.ERC20Storage storage s = ERC20BridgeableFacet.getERC20Storage();
        return s.balanceOf[_account];
    }
}
