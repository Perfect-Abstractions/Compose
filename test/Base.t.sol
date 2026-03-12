// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

/* Compose
 * https://compose.diamonds
 */

import {StdCheats} from "forge-std/StdCheats.sol";
import {StdAssertions} from "forge-std/StdAssertions.sol";

import {Constants} from "./utils/Constants.sol";
import {Defaults} from "./utils/Defaults.sol";
import {Modifiers} from "./utils/Modifiers.sol";
import {Users} from "./utils/Types.sol";

abstract contract Base_Test is Constants, Modifiers, StdAssertions, StdCheats {
    /*//////////////////////////////////////////////////////////////
                               VARIABLES
    //////////////////////////////////////////////////////////////*/

    Users internal users;

    /*//////////////////////////////////////////////////////////////
                             TEST CONTRACTS
    //////////////////////////////////////////////////////////////*/

    Defaults internal defaults;

    /*//////////////////////////////////////////////////////////////
                            SET-UP FUNCTION
    //////////////////////////////////////////////////////////////*/

    function setUp() public virtual {
        defaults = new Defaults();

        createTestUsers();
        defaults.setUsers(users);

        setVariables(defaults, users);

        setMsgSender(users.alice);
    }

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function createUser(string memory name) internal returns (address payable user) {
        user = payable(makeAddr(name)); // label implicitly created via Foundry
        vm.deal({account: user, newBalance: 100 ether});
    }

    function createTestUsers() internal {
        users.alice = createUser("Alice");
        users.bob = createUser("Bob");
        users.charlee = createUser("Charlee");

        users.admin = createUser("Admin");
        users.receiver = createUser("Receiver");
        users.sender = createUser("Sender");
    }
}
