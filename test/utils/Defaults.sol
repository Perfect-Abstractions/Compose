// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {Constants} from "./Constants.sol";
import {Users} from "./Types.sol";

contract Defaults is Constants {
    /*//////////////////////////////////////////////////////////////
                               VARIABLES
    //////////////////////////////////////////////////////////////*/

    Users private users;

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function setUsers(Users memory users_) public {
        users = users_;
    }
}
