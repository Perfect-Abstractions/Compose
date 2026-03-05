// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

contract AccessControlRenounceFacet {
    /**
     * @notice Emitted when a role is revoked from an account.
     * @param _role The role that was revoked.
     * @param _account The account from which the role was revoked.
     * @param _sender The account that revoked the role.
     */
    event RoleRevoked(bytes32 indexed _role, address indexed _account, address indexed _sender);

    /**
     * @notice Thrown when the sender is not the account to renounce the role from.
     * @param _sender The sender that is not the account to renounce the role from.
     * @param _account The account to renounce the role from.
     */
    error AccessControlUnauthorizedSender(address _sender, address _account);

    /**
     * @notice Storage slot identifier.
     */
    bytes32 constant STORAGE_POSITION = keccak256("compose.accesscontrol");

    /**
     * @notice Storage struct for the AccessControl.
     * @custom:storage-location erc8042:compose.accesscontrol
     */
    struct AccessControlStorage {
        mapping(address account => mapping(bytes32 role => bool hasRole)) hasRole;
        mapping(bytes32 role => bytes32 adminRole) adminRole;
    }

    /**
     * @notice Returns the storage for the AccessControl.
     * @return s The storage for the AccessControl.
     */
    function getStorage() internal pure returns (AccessControlStorage storage s) {
        bytes32 position = STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }

    /**
     * @notice Renounces a role from the caller.
     * @param _role The role to renounce.
     * @param _account The account to renounce the role from.
     * @dev Emits a {RoleRevoked} event.
     * @custom:error AccessControlUnauthorizedSender If the caller is not the account to renounce the role from.
     */
    function renounceRole(bytes32 _role, address _account) external {
        AccessControlStorage storage s = getStorage();

        /**
         * Check If the caller is not the account to renounce the role from.
         */
        if (msg.sender != _account) {
            revert AccessControlUnauthorizedSender(msg.sender, _account);
        }
        bool _hasRole = s.hasRole[_account][_role];
        if (_hasRole) {
            s.hasRole[_account][_role] = false;
            emit RoleRevoked(_role, _account, msg.sender);
        }
    }

    /**
     * @notice Exports the selectors that are exposed by the facet.
     * @return Selectors that are exported by the facet.
     */
    function exportSelectors() external pure returns (bytes memory) {
        return bytes.concat(this.renounceRole.selector);
    }
}
