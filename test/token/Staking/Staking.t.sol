// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {LibStakingHarness} from "./harnesses/LibStakingHarness.sol";
import {ERC20FacetHarness} from "../ERC20//ERC20/harnesses/ERC20FacetHarness.sol";
import {ERC721FacetHarness} from "../ERC721/ERC721/harnesses/ERC721FacetHarness.sol";
import {ERC1155FacetHarness} from "../ERC1155/ERC1155/harnesses/ERC1155FacetHarness.sol";
import "../../../src/token/Staking/StakingMod.sol" as StakingMod;

// import "forge-std/console.sol";

contract StakingTest is Test {
    ERC20FacetHarness erc20Token;
    ERC20FacetHarness rewardToken;
    ERC721FacetHarness erc721Token;
    ERC1155FacetHarness erc1155Token;
    LibStakingHarness staking;

    address public alice;
    address public bob;

    string constant ASSET_NAME = "Test Token";
    string constant ASSET_SYMBOL = "TEST";
    uint8 constant ASSET_DECIMALS = 18;

    string constant TOKEN_NAME = "Test Token";
    string constant TOKEN_SYMBOL = "TEST";
    string constant BASE_URI = "https://example.com/api/nft/";

    string constant DEFAULT_URI = "https://token.uri/{id}.json";

    uint256 constant TOKEN_ID_1 = 1;
    uint256 constant TOKEN_ID_2 = 2;

    uint256 constant BASE_APR = 500; // 5%
    uint256 constant REWARD_DECAY_RATE = 50; // 0.5%
    uint256 constant COMPOUND_FREQUENCY = 1 days;
    uint256 constant COOLDOWN_PERIOD = 7 days;
    uint256 constant MIN_STAKE_AMOUNT = 1 ether;
    uint256 constant MAX_STAKE_AMOUNT = 1000 ether;

    event StakingParametersUpdated(
        uint256 baseAPR,
        uint256 rewardDecayRate,
        uint256 compoundFrequency,
        address rewardToken,
        uint256 cooldownPeriod,
        uint256 minStakeAmount,
        uint256 maxStakeAmount
    );

    event SupportedTokenAdded(address indexed tokenAddress, bool isERC20, bool isERC721, bool isERC1155);

    function setUp() public {
        alice = makeAddr("alice");
        bob = makeAddr("bob");

        /**
         * Deploy and initialize the reward ERC-20 token
         */
        rewardToken = new ERC20FacetHarness();
        rewardToken.initialize("Reward Token", "RWD", 18);

        /**
         * Deploy and initialize the ERC-20 token for staking tests
         */
        erc20Token = new ERC20FacetHarness();
        erc20Token.initialize(ASSET_NAME, ASSET_SYMBOL, ASSET_DECIMALS);

        /**
         * Deploy and initialize the ERC-721 token for staking tests
         */
        erc721Token = new ERC721FacetHarness();
        erc721Token.initialize(TOKEN_NAME, TOKEN_SYMBOL, BASE_URI);

        /**
         * Deploy and initialize the ERC-1155 token for staking tests
         */
        erc1155Token = new ERC1155FacetHarness();
        erc1155Token.initialize(DEFAULT_URI);

        /**
         * Deploy and initialize the staking harness
         */
        staking = new LibStakingHarness();

        /**
         * Register supported tokens
         */
        staking.addSupportedToken(address(erc20Token), true, false, false);
        staking.addSupportedToken(address(erc721Token), false, true, false);
        staking.addSupportedToken(address(erc1155Token), false, false, true);
        staking.addSupportedToken(address(rewardToken), true, false, false);

        /**
         * Mint tokens to Alice and Bob for testing
         */
        erc20Token.mint(alice, 1_000 ether);
        erc20Token.mint(bob, 1_000 ether);
        erc1155Token.mint(bob, TOKEN_ID_2, 100);
        erc1155Token.mint(alice, TOKEN_ID_1, 100);
        erc721Token.mint(bob, TOKEN_ID_2);
        erc721Token.mint(alice, TOKEN_ID_1);
        rewardToken.mint(address(staking), 10_000 ether);

        /**
         * Initialize staking parameters
         */
        staking.initialize(
            BASE_APR,
            REWARD_DECAY_RATE,
            COMPOUND_FREQUENCY,
            address(rewardToken),
            COOLDOWN_PERIOD,
            MIN_STAKE_AMOUNT,
            MAX_STAKE_AMOUNT
        );
    }

    function test_ParametersAreSetCorrectly() public {
        (
            uint256 baseAPR,
            uint256 rewardDecayRate,
            uint256 compoundFrequency,
            address rewardTokenAddress,
            uint256 cooldownPeriod,
            uint256 minStakeAmount,
            uint256 maxStakeAmount
        ) = staking.getStakingParameters();

        assertEq(baseAPR, BASE_APR);
        assertEq(rewardDecayRate, REWARD_DECAY_RATE);
        assertEq(compoundFrequency, COMPOUND_FREQUENCY);
        assertEq(rewardTokenAddress, address(rewardToken));
        assertEq(cooldownPeriod, COOLDOWN_PERIOD);
        assertEq(minStakeAmount, MIN_STAKE_AMOUNT);
        assertEq(maxStakeAmount, MAX_STAKE_AMOUNT);
    }

    function test_ParametersAreSetCorrectly_EventEmitted() public {
        vm.expectEmit(true, true, true, true);
        emit StakingParametersUpdated(
            BASE_APR,
            REWARD_DECAY_RATE,
            COMPOUND_FREQUENCY,
            address(rewardToken),
            COOLDOWN_PERIOD,
            MIN_STAKE_AMOUNT,
            MAX_STAKE_AMOUNT
        );

        staking.initialize(
            BASE_APR,
            REWARD_DECAY_RATE,
            COMPOUND_FREQUENCY,
            address(rewardToken),
            COOLDOWN_PERIOD,
            MIN_STAKE_AMOUNT,
            MAX_STAKE_AMOUNT
        );
    }

    function test_ParametersAreSetCorrectly_RevertOnUnsupportedToken() public {
        address unsupportedToken = makeAddr("unsupportedToken");

        vm.expectRevert(abi.encodeWithSelector(StakingMod.StakingUnsupportedToken.selector, unsupportedToken));
        staking.initialize(
            BASE_APR,
            REWARD_DECAY_RATE,
            COMPOUND_FREQUENCY,
            unsupportedToken,
            COOLDOWN_PERIOD,
            MIN_STAKE_AMOUNT,
            MAX_STAKE_AMOUNT
        );
    }

    function test_ParametersAreSetCorrectly_RevertOnZeroStakeAmount() public {
        uint256 newMinStakeAmount = 0;
        vm.expectRevert(abi.encodeWithSelector(StakingMod.StakingZeroStakeAmount.selector, newMinStakeAmount));
        staking.initialize(
            BASE_APR,
            REWARD_DECAY_RATE,
            COMPOUND_FREQUENCY,
            address(rewardToken),
            COOLDOWN_PERIOD,
            newMinStakeAmount,
            MAX_STAKE_AMOUNT
        );

        uint256 newMaxStakeAmount = 0;
        vm.expectRevert(abi.encodeWithSelector(StakingMod.StakingZeroStakeAmount.selector, newMaxStakeAmount));
        staking.initialize(
            BASE_APR,
            REWARD_DECAY_RATE,
            COMPOUND_FREQUENCY,
            address(rewardToken),
            COOLDOWN_PERIOD,
            MIN_STAKE_AMOUNT,
            newMaxStakeAmount
        );
    }

    function test_ParametersAreSetCorrectly_EmitEventsSupportedToken() public {
        vm.expectEmit(true, true, true, true);
        emit SupportedTokenAdded(address(erc20Token), true, false, false);
        staking.addSupportedToken(address(erc20Token), true, false, false);

        vm.expectEmit(true, true, true, true);
        emit SupportedTokenAdded(address(erc721Token), false, true, false);
        staking.addSupportedToken(address(erc721Token), false, true, false);

        vm.expectEmit(true, true, true, true);
        emit SupportedTokenAdded(address(erc1155Token), false, false, true);
        staking.addSupportedToken(address(erc1155Token), false, false, true);

        vm.expectEmit(true, true, true, true);
        emit SupportedTokenAdded(address(rewardToken), true, false, false);
        staking.addSupportedToken(address(rewardToken), true, false, false);
    }

    function test_VerifySupportedTokens() public {
        // Supported tokens
        bool isERC20Supported = staking.isTokenSupported(address(erc20Token));
        bool isERC721Supported = staking.isTokenSupported(address(erc721Token));
        bool isERC1155Supported = staking.isTokenSupported(address(erc1155Token));
        bool isRewardTokenSupported = staking.isTokenSupported(address(rewardToken));

        assertTrue(isERC20Supported);
        assertTrue(isERC721Supported);
        assertTrue(isERC1155Supported);
        assertTrue(isRewardTokenSupported);

        // Unsupported token
        address unsupportedToken = makeAddr("unsupportedToken");
        bool isUnsupportedTokenSupported = staking.isTokenSupported(unsupportedToken);
        assertFalse(isUnsupportedTokenSupported);
    }

    function test_StakeERC20UpdatesState() public {
        uint256 stakeAmount = 100 ether;
        vm.startPrank(alice);

        erc20Token.approve(address(staking), stakeAmount);

        // Stake ERC-20 tokens
        staking.stakeERC20(address(erc20Token), stakeAmount);

        (uint256 amount,,,) = staking.getStakedTokenInfo(address(erc20Token), 0);

        assertEq(amount, stakeAmount);
        vm.stopPrank();
    }

    function test_StakeERC721UpdatesState() public {
        vm.startPrank(alice);

        // Stake ERC-721 token
        staking.stakeERC721(address(erc721Token), TOKEN_ID_1);

        (uint256 amount,,,) = staking.getStakedTokenInfo(address(erc721Token), TOKEN_ID_1);
        console.log("Staked amount:", amount);

        assertEq(amount, 1);
        vm.stopPrank();
    }

    function test_StakeERC1155UpdatesState() public {
        uint256 stakeAmount = 10;
        vm.startPrank(bob);

        erc1155Token.setApprovalForAll(address(staking), true);

        // Stake ERC-1155 tokens
        staking.stakeERC1155(address(erc1155Token), TOKEN_ID_2, stakeAmount);

        (uint256 amount,,,) = staking.getStakedTokenInfo(address(erc1155Token), TOKEN_ID_2);
        console.log("Staked amount:", amount);

        assertEq(amount, stakeAmount);
        vm.stopPrank();
    }

    function test_StakeTokens_RevertWithUnsupportedToken() public {
        address unsupportedToken = makeAddr("unsupportedToken");

        vm.expectRevert(abi.encodeWithSelector(StakingMod.StakingUnsupportedToken.selector, unsupportedToken));
        staking.stakeERC20(unsupportedToken, 100 ether);
    }

    function test_FixedPoint_IntegerPower() public {
        uint256 result = staking.rPow(2e18, 3); // 2^3 = 8
        assertEq(result, 8e18);

        result = staking.rPow(5e18, 0); // 5^0 = 1
        assertEq(result, 1e18);

        result = staking.rPow(1e18, 10); // 1^10 = 1
        assertEq(result, 1e18);

        result = staking.rPow(3e18, 4); // 3^4 = 81
        assertEq(result, 81e18);
    }

    function test_FixedPoint_Multiply() public {
        uint256 result = staking.rMul(2e18, 3e18); // 2 * 3 = 6
        assertEq(result, 6e18);

        result = staking.rMul(5e18, 0e18); // 5 * 0 = 0
        assertEq(result, 0);

        result = staking.rMul(1e18, 10e18); // 1 * 10 = 10
        assertEq(result, 10e18);

        result = staking.rMul(3e18, 4e18); // 3 * 4 = 12
        assertEq(result, 12e18);
    }
}
