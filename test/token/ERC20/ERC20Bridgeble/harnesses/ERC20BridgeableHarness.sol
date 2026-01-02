// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import "../../../../../src/token/ERC20/ERC20Bridgeable/ERC20BridgeableMod.sol" as ERC20BridgeableMod;

contract ERC20BridgeableHarness {
    /**
     * @notice Mints tokens to a specified address on behalf of the "trusted-bridge" role.
     * @param _to The address receiving the minted tokens. [NATPSEC: Only trusted bridge callers]
     * @param _amount The amount of tokens to mint. [NATPSEC: Only trusted bridge callers]
     */
    function crosschainMint(address _to, uint256 _amount) external {
        ERC20BridgeableMod.crosschainMint(_to, _amount);
    }

    /**
     * @notice Returns the token balance of a specified account.
     * @param _account The account for which to query the balance. [NATPSEC: Read-only]
     * @return The current balance of the account.
     */
    function balanceOf(address _account) external view returns (uint256) {
        ERC20BridgeableMod.ERC20Storage storage s = ERC20BridgeableMod.getERC20Storage();
        return s.balanceOf[_account];
    }

    /**
     * @notice Burns tokens from a specified address on behalf of the "trusted-bridge" role.
     * @param _from The address whose tokens will be burned. [NATPSEC: Only trusted bridge callers]
     * @param _amount The amount of tokens to burn. [NATPSEC: Only trusted bridge callers]
     */
    function crosschainBurn(address _from, uint256 _amount) external {
        ERC20BridgeableMod.crosschainBurn(_from, _amount);
    }

    /**
     * @notice Validates whether the caller has the token bridge role.
     * @param _caller The address to check for the "trusted-bridge" role. [NATPSEC: Internal access control]
     */
    function checkTokenBridge(address _caller) external view {
        ERC20BridgeableMod.checkTokenBridge(_caller);
    }

    /**
     * @notice Grants or revokes a role for a given account, for harness/testing only.
     * @param account The account to grant or revoke the role for. [NATPSEC: Test utility only]
     * @param role The bytes32 identifier of the role. [NATPSEC: Test utility only]
     * @param value True to grant the role, false to revoke. [NATPSEC: Test utility only]
     */
    function setRole(address account, bytes32 role, bool value) external {
        ERC20BridgeableMod.AccessControlStorage storage acs = ERC20BridgeableMod.getAccessControlStorage();
        acs.hasRole[account][role] = value;
    }
}
