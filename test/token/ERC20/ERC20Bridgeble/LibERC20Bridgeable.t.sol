// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {Test} from "forge-std/Test.sol";
import {LibERC20Bridgeable} from "../../../src/token/ERC20/ERC20Bridgeable/LibERC20Bridgeable.sol";
import {LibERC20BridgeableHarness} from "./harnesses/LibERC20BridgeableHarness.sol";

contract LibERC20BridgeableTest is Test {
    LibERC20BridgeableHarness public harness;

    address public alice;
    address public bob;
    address public charlie;

    uint256 constant INITIAL_SUPPLY = 1000000e18;

    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);

    function setUp() public {
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");

        token = new ERC20FacetHarness();
        token.initialize(TOKEN_NAME, TOKEN_SYMBOL, TOKEN_DECIMALS);
        token.mint(alice, INITIAL_SUPPLY);
    }