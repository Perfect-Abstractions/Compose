// // SPDX-License-Identifier: MIT
// pragma solidity >=0.8.30;
//
// /* Compose
//  * https://compose.diamonds
//  */
//
// import {Test} from "forge-std/Test.sol";
// import "../../../../src/token/ERC20/ERC20Bridgeable/ERC20BridgeableMod.sol" as ERC20BridgeableMod;
// import {ERC20BridgeableHarness} from "./harnesses/ERC20BridgeableHarness.sol";
//
// contract LibERC20BridgeableTest is Test {
//     ERC20BridgeableHarness public token;
//
//     address public alice;
//     address public bob;
//
//     uint256 constant INITIAL_SUPPLY = 1000000e18;
//
//     function setUp() public {
//         alice = makeAddr("alice");
//         bob = makeAddr("bob");
//
//         token = new ERC20BridgeableHarness();
//         token.setRole(alice, "trusted-bridge", true);
//         vm.prank(alice);
//         token.crosschainMint(alice, INITIAL_SUPPLY);
//     }
//
//     /**
//      * ======================================
//      * CrossChainMint Tests
//      * ======================================
//      */
//
//     function test_CrossChainMintRevertsInvalidCaller(address to, uint256 amount, address invalidCaller) public {
//         vm.assume(to != address(0));
//         vm.assume(amount > 0 && amount < INITIAL_SUPPLY);
//         vm.assume(invalidCaller != alice);
//         vm.prank(invalidCaller);
//         vm.expectRevert(
//             abi.encodeWithSelector(
//                 ERC20BridgeableMod.AccessControlUnauthorizedAccount.selector, invalidCaller, bytes32("trusted-bridge")
//             )
//         );
//         token.crosschainMint(to, amount);
//     }
//
//     function test_CrossChainMintRevertsInvalidReceiver(uint256 amount) public {
//         address to = address(0);
//         vm.assume(amount > 0 && amount < INITIAL_SUPPLY);
//         vm.expectRevert(abi.encodeWithSelector(ERC20BridgeableMod.ERC20InvalidReciever.selector, to));
//         vm.prank(alice);
//         token.crosschainMint(to, amount);
//     }
//
//     function test_CrossChainMint() public {
//         vm.prank(alice);
//         token.crosschainMint(bob, 500e18);
//         assertEq(token.balanceOf(bob), 500e18);
//     }
//
//     /**
//      * ======================================
//      * CrossChainBurn Tests
//      * ======================================
//      */
//
//     function test_CrossChainBurnRevertsInvalidCaller(address from, uint256 amount, address invalidCaller) public {
//         vm.assume(from != address(0));
//         vm.assume(amount > 0 && amount < INITIAL_SUPPLY);
//         vm.assume(invalidCaller != alice);
//         vm.prank(alice);
//         token.crosschainMint(from, amount);
//         vm.prank(invalidCaller);
//         vm.expectRevert(
//             abi.encodeWithSelector(
//                 ERC20BridgeableMod.AccessControlUnauthorizedAccount.selector, invalidCaller, bytes32("trusted-bridge")
//             )
//         );
//         token.crosschainBurn(from, amount);
//     }
//
//     function test_CrossChainBurnRevertsInvalidFrom(uint256 amount) public {
//         address from = address(0);
//         vm.assume(amount > 0 && amount < INITIAL_SUPPLY);
//         vm.prank(alice);
//         vm.expectRevert(abi.encodeWithSelector(ERC20BridgeableMod.ERC20InvalidReciever.selector, from));
//         token.crosschainBurn(from, amount);
//     }
//
//     function test_CrossChainBurn() public {
//         vm.prank(alice);
//         token.crosschainMint(bob, 500e18);
//         assertEq(token.balanceOf(bob), 500e18);
//
//         vm.prank(alice);
//         token.crosschainBurn(bob, 200e18);
//         assertEq(token.balanceOf(bob), 300e18);
//     }
//
//     /**
//      * ======================================
//      * checkTokenBridge Tests
//      * ======================================
//      */
//
//     function test_CheckTokenBridgeSucceedsValidCaller() public {
//         vm.prank(alice);
//         token.checkTokenBridge(alice);
//     }
//
//     function test_CheckTokenBridgeRevertsInvalidCaller(address invalidCaller) public {
//         vm.assume(invalidCaller != alice);
//         vm.assume(invalidCaller != address(0));
//         vm.prank(invalidCaller);
//         vm.expectRevert(abi.encodeWithSelector(ERC20BridgeableMod.ERC20InvalidBridgeAccount.selector, invalidCaller));
//         token.checkTokenBridge(invalidCaller);
//     }
//
//     function test_CheckTokenBridgeRevertsZeroCaller() public {
//         address zeroAddress = address(0);
//         vm.prank(zeroAddress);
//         vm.expectRevert(abi.encodeWithSelector(ERC20BridgeableMod.ERC20InvalidBridgeAccount.selector, zeroAddress));
//         token.checkTokenBridge(zeroAddress);
//     }
// }
