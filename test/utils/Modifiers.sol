// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {Defaults} from "./Defaults.sol";
import {Users} from "./Types.sol";
import {Utils} from "./Utils.sol";

abstract contract Modifiers is Utils {
    /*//////////////////////////////////////////////////////////////
                               VARIABLES
    //////////////////////////////////////////////////////////////*/

    Defaults private defaults;
    Users private users;

    function setVariables(Defaults _defaults, Users memory _users) public {
        defaults = _defaults;
        users = _users;
    }

    /*//////////////////////////////////////////////////////////////
                                 ERC-20
    //////////////////////////////////////////////////////////////*/

    modifier whenAccountNotZeroAddress() {
        _;
    }

    modifier whenReceiverNotZeroAddress() {
        _;
    }

    modifier whenSpenderNotZeroAddress() {
        _;
    }

    modifier whenSenderNotZeroAddress() {
        _;
    }

    modifier givenWhenTotalSupplyNotOverflow() {
        _;
    }

    modifier givenWhenAccountBalanceGEBurnAmount() {
        _;
    }

    modifier givenWhenSenderBalanceGETransferAmount() {
        _;
    }

    modifier givenWhenSpenderAllowanceGETransferAmount() {
        _;
    }

    /*//////////////////////////////////////////////////////////////
                                ERC-721
    //////////////////////////////////////////////////////////////*/

    modifier whenOwnerNotZeroAddress() {
        _;
    }

    modifier whenTokenExists() {
        _;
    }

    modifier whenToNotZeroAddress() {
        _;
    }

    modifier whenFromIsOwner() {
        _;
    }

    modifier whenCallerIsAuthorized() {
        _;
    }

    modifier whenOperatorNotZeroAddress() {
        _;
    }

    modifier whenRecipientNotZeroAddress() {
        _;
    }

    modifier givenWhenTokenDoesNotExist() {
        _;
    }
}
