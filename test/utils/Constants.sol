// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

abstract contract Constants {
    /*//////////////////////////////////////////////////////////////
                                GENERIC
    //////////////////////////////////////////////////////////////*/

    uint256 internal constant MAX_UINT256 = type(uint256).max;

    address internal constant ADDRESS_ZERO = address(0);

    /*//////////////////////////////////////////////////////////////
                              INTERFACE ID
    //////////////////////////////////////////////////////////////*/

    bytes4 internal constant IERC165_INTERFACE_ID = 0x01ffc9a7;
    bytes4 internal constant IERC20_INTERFACE_ID = 0x36372b07;
    bytes4 internal constant IERC721_INTERFACE_ID = 0x80ac58cd;
    bytes4 internal constant IERC1155_INTERFACE_ID = 0xd9b67a26;
    bytes4 internal constant INVALID_INTERFACE_ID = 0xffffffff;
    bytes4 internal constant CUSTOM_INTERFACE_ID = 0x12345678;
    bytes4 internal constant ZERO_INTERFACE_ID = 0x00000000;

    /*//////////////////////////////////////////////////////////////
                                 ROLES
    //////////////////////////////////////////////////////////////*/

    bytes32 internal constant DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 internal constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 internal constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 internal constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 internal constant MODERATOR_ROLE = keccak256("MODERATOR_ROLE");
    bytes32 internal constant USER_ROLE = keccak256("USER_ROLE");
    bytes32 internal constant TRUSTED_BRIDGE_ROLE = keccak256("TRUSTED_BRIDGE_ROLE");

    /*//////////////////////////////////////////////////////////////
                                 TOKEN
    //////////////////////////////////////////////////////////////*/

    string public constant TOKEN_NAME = "Test Token";
    string public constant TOKEN_SYMBOL = "TEST";
    uint8 public constant TOKEN_DECIMALS = 18;
    uint256 internal constant INITIAL_SUPPLY = 1_000_000e18;

    uint256 internal constant TOKEN_ID_1 = 1;
    uint256 internal constant TOKEN_ID_2 = 2;
    uint256 internal constant TOKEN_ID_3 = 3;

    /*//////////////////////////////////////////////////////////////
                                  URI
    //////////////////////////////////////////////////////////////*/

    string internal constant BASE_URI = "https://example.com/api/nft/";
    string internal constant DEFAULT_URI = "https://token.uri/{id}.json";
    string internal constant TOKEN_URI = "token1.json";

    /*//////////////////////////////////////////////////////////////
                     ERC-1155 RECEIVER MAGIC VALUES
    //////////////////////////////////////////////////////////////*/

    bytes4 internal constant RECEIVER_SINGLE_MAGIC_VALUE = 0xf23a6e61; // onERC1155Received
    bytes4 internal constant RECEIVER_BATCH_MAGIC_VALUE = 0xbc197c81; // onERC1155BatchReceived

    /*//////////////////////////////////////////////////////////////
                                  FEE
    //////////////////////////////////////////////////////////////*/

    uint256 internal constant FEE_DENOMINATOR = 10_000;
}
