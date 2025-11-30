// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {Test} from "forge-std/Test.sol";
import {ERC20BridgeableFacet} from "../../../../src/token/ERC20/ERC20Bridgeable/ERC20BridgeableFacet.sol";
import {ERC20BridgeableHarness} from "./harnesses/ERC20BridgeableHarness.sol";

contract ERC20BridgeableFacetTest is Test {
    ERC20BridgeableHarness public token;

    address public alice;
    address public bob;

    uint256 constant INITIAL_SUPPLY = 1000000e18;

    function setUp() public {
        alice = makeAddr("alice");
        bob = makeAddr("bob");

        token = new ERC20BridgeableHarness();
        token.setRole(alice, "trusted-bridge", true);
        vm.prank(alice);
        token.crosschainMint(alice, INITIAL_SUPPLY);
    }

    /**
     * ======================================
     * CrossChainMint Tests
     * ======================================
     */

    function test_CrossChainMintRevertsInvalidCaller(address to, uint256 amount, address invalidCaller) public {
        vm.assume(to != address(0));
        vm.assume(amount > 0 && amount < INITIAL_SUPPLY);
        vm.assume(invalidCaller != alice);
        vm.prank(invalidCaller);
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC20BridgeableFacet.AccessControlUnauthorizedAccount.selector, invalidCaller, bytes32("trusted-bridge")
            )
        );
        token.crosschainMint(to, amount);
    }

    function test_CrossChainMintRevertsInvalidReceiver(uint256 amount) public {
        address to = address(0);
        vm.assume(amount > 0 && amount < INITIAL_SUPPLY);
        vm.expectRevert(abi.encodeWithSelector(ERC20BridgeableFacet.ERC20InvalidReciever.selector, to));
        vm.prank(alice);
        token.crosschainMint(to, amount);
    }

    function test_CrossChainMint() public {
        vm.prank(alice);
        token.crosschainMint(bob, 500e18);
        assertEq(token.balanceOf(bob), 500e18);
    }

    /**
     * ======================================
     * CrossChainBurn Tests
     * ======================================
     */

    function test_CrossChainBurnRevertsInvalidCaller(address from, uint256 amount, address invalidCaller) public {
        vm.assume(from != address(0));
        vm.assume(amount > 0 && amount < INITIAL_SUPPLY);
        vm.assume(invalidCaller != alice);
        vm.prank(alice);
        token.crosschainMint(from, amount);
        vm.prank(invalidCaller);
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC20BridgeableFacet.AccessControlUnauthorizedAccount.selector, invalidCaller, bytes32("trusted-bridge")
            )
        );
        token.crosschainBurn(from, amount);
    }

    function test_CrossChainBurnRevertsInvalidFrom(uint256 amount) public {
        address from = address(0);
        vm.assume(amount > 0 && amount < INITIAL_SUPPLY);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ERC20BridgeableFacet.ERC20InvalidReciever.selector, from));
        token.crosschainBurn(from, amount);
    }

    function test_CrossChainBurn() public {
        vm.prank(alice);
        token.crosschainMint(bob, 500e18);
        assertEq(token.balanceOf(bob), 500e18);
        vm.prank(alice);
        token.crosschainBurn(bob, 500e18);
        assertEq(token.balanceOf(bob), 0);
    }

    /**
     * ======================================
     * checkTokenBridge Tests
     * ======================================
     */

    function test_CheckTokenBridgeSucceeds(address _caller) public {
        vm.prank(alice);
        token.checkTokenBridge(alice);
    }

    function test_CheckTokenBridgeReverts(address invalidCaller) public {
        vm.assume(invalidCaller != alice);
        vm.prank(invalidCaller);
        vm.expectRevert(abi.encodeWithSelector(ERC20BridgeableFacet.ERC20InvalidBridgeAccount.selector, invalidCaller));
        token.checkTokenBridge(invalidCaller);
    }

    function test_CheckTokenBridgeRevertsZeroAddress() public {
        address invalidCaller = address(0);
        vm.prank(invalidCaller);
        vm.expectRevert(abi.encodeWithSelector(ERC20BridgeableFacet.ERC20InvalidBridgeAccount.selector, invalidCaller));
        token.checkTokenBridge(invalidCaller);
    }

    function test_CheckTokenBridgeSucceedsAfterRevokingRole() public {
        token.setRole(alice, "trusted-bridge", false);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ERC20BridgeableFacet.ERC20InvalidBridgeAccount.selector, alice));
        token.checkTokenBridge(alice);
    }
}
