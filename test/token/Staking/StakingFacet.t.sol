// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {Test} from "forge-std/Test.sol";
import {StakingFacetHarness} from "./harnesses/StakingFacetHarness.sol";
import {StakingFacet} from "../../../src/token/Staking/StakingFacet.sol";
import {ERC20FacetHarness} from "../ERC20//ERC20/harnesses/ERC20FacetHarness.sol";
import {ERC721FacetHarness} from "../ERC721/ERC721/harnesses/ERC721FacetHarness.sol";
import {ERC1155FacetHarness} from "../ERC1155/ERC1155/harnesses/ERC1155FacetHarness.sol";
import {IERC721Receiver} from "../../../src/interfaces/IERC721Receiver.sol";
import {IERC1155Receiver} from "../../../src/interfaces/IERC1155Receiver.sol";

contract StakingFacetTest is Test {
    StakingFacetHarness public facet;
    ERC20FacetHarness erc20Token;
    ERC20FacetHarness rewardToken;
    ERC721FacetHarness erc721Token;
    ERC1155FacetHarness erc1155Token;

    address public alice;
    address public bob;
    address public owner;

    string constant ASSET_NAME = "Test Token";
    string constant ASSET_SYMBOL = "TEST";
    uint8 constant ASSET_DECIMALS = 18;

    string constant TOKEN_NAME = "Test Token";
    string constant TOKEN_SYMBOL = "TEST";
    string constant BASE_URI = "https://example.com/api/nft/";

    string constant DEFAULT_URI = "https://token.uri/{id}.json";

    uint256 constant TOKEN_ID_1 = 1;
    uint256 constant TOKEN_ID_2 = 2;

    uint256 constant BASE_APR = 10; // 10%
    uint256 constant REWARD_DECAY_RATE = 0; // no decay
    uint256 constant COMPOUND_FREQUENCY = 365 days;
    uint256 constant COOLDOWN_PERIOD = 1 days;
    uint256 constant MIN_STAKE_AMOUNT = 0 ether;
    uint256 constant MAX_STAKE_AMOUNT = 1_000_000 ether;

    function setUp() public {
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        owner = makeAddr("owner");

        vm.startPrank(owner);

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
        facet = new StakingFacetHarness();

        /**
         * Initialize staking parameters
         */
        facet.initialize(
            BASE_APR,
            REWARD_DECAY_RATE,
            COMPOUND_FREQUENCY,
            address(rewardToken),
            COOLDOWN_PERIOD,
            MIN_STAKE_AMOUNT,
            MAX_STAKE_AMOUNT
        );

        /**
         * Register supported tokens
         */
        facet.addSupportedToken(address(erc20Token), true, false, false);
        facet.addSupportedToken(address(erc721Token), false, true, false);
        facet.addSupportedToken(address(erc1155Token), false, false, true);

        /**
         * Mint tokens to Alice and Bob for testing
         */
        erc20Token.mint(alice, 1000 ether);
        erc20Token.mint(bob, 1000 ether);
        erc721Token.mint(alice, TOKEN_ID_1);
        erc721Token.mint(bob, TOKEN_ID_2);
        erc1155Token.mint(alice, TOKEN_ID_1, 10);
        erc1155Token.mint(bob, TOKEN_ID_2, 10);
        rewardToken.mint(address(facet), 1_000_000 ether);

        vm.stopPrank();
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
        ) = facet.getStakingParameters();

        assertEq(baseAPR, BASE_APR);
        assertEq(rewardDecayRate, REWARD_DECAY_RATE);
        assertEq(compoundFrequency, COMPOUND_FREQUENCY);
        assertEq(rewardTokenAddress, address(rewardToken));
        assertEq(cooldownPeriod, COOLDOWN_PERIOD);
        assertEq(minStakeAmount, MIN_STAKE_AMOUNT);
        assertEq(maxStakeAmount, MAX_STAKE_AMOUNT);
    }

    function test_StakeERC20Token() public {
        vm.startPrank(alice);

        // Approve the staking contract to spend Alice's tokens
        erc20Token.approve(address(facet), 500 ether);

        // Stake tokens
        facet.stakeToken(address(erc20Token), 0, 500 ether);

        // Verify staking state
        (uint256 amount, uint256 stakedAt, uint256 lastClaimedAt, uint256 accumulatedRewards) =
            facet.getStakedTokenInfo(
                address(erc20Token),
                0 // Token ID is 0 for ERC-20 staking
            );

        assertEq(amount, 500 ether);
        assertGt(stakedAt, 0);
        assertGt(lastClaimedAt, 0);
        assertEq(accumulatedRewards, 0);

        vm.stopPrank();
    }

    function test_StakeERC721Token() public {
        vm.startPrank(bob);

        // Approve the staking contract to transfer Bob's NFT
        erc721Token.approve(address(facet), TOKEN_ID_2);

        // Stake NFT
        facet.stakeToken(address(erc721Token), TOKEN_ID_2, 1);

        // Verify staking state
        (uint256 amount, uint256 stakedAt, uint256 lastClaimedAt, uint256 accumulatedRewards) =
            facet.getStakedTokenInfo(address(erc721Token), TOKEN_ID_2);

        assertEq(amount, 1);
        assertGt(stakedAt, 0);
        assertGt(lastClaimedAt, 0);
        assertEq(accumulatedRewards, 0);

        vm.stopPrank();
    }

    function test_StakeERC1155Token() public {
        vm.startPrank(alice);

        // Approve the staking contract to transfer Alice's ERC-1155 tokens
        erc1155Token.setApprovalForAll(address(facet), true);

        // Stake ERC-1155 tokens
        facet.stakeToken(address(erc1155Token), TOKEN_ID_1, 5);

        // Verify staking state
        (uint256 amount, uint256 stakedAt, uint256 lastClaimedAt, uint256 accumulatedRewards) =
            facet.getStakedTokenInfo(address(erc1155Token), TOKEN_ID_1);

        assertEq(amount, 5);
        assertGt(stakedAt, 0);
        assertGt(lastClaimedAt, 0);
        assertEq(accumulatedRewards, 0);

        vm.stopPrank();
    }

    function test_StakeToken_RevertsForUnsupportedToken() public {
        address unsupportedToken = makeAddr("unsupportedToken");

        vm.startPrank(alice);

        vm.expectRevert(abi.encodeWithSelector(StakingFacet.StakingUnsupportedToken.selector, unsupportedToken));
        facet.stakeToken(unsupportedToken, 0, 100 ether);

        vm.stopPrank();
    }

    function test_RewardCalculation() public {
        vm.startPrank(alice);

        erc20Token.approve(address(facet), 1000 ether);
        facet.stakeToken(address(erc20Token), 0, 1000 ether);

        vm.warp(block.timestamp + 365 days);

        uint256 calculatedRewards = facet.calculateRewardsForToken(address(erc20Token), 0);

        assertGt(calculatedRewards, 0); //  1000 ether * 10% * 1 year = 100 ether
        vm.stopPrank();
    }

    function test_ClaimedRewards() public {
        vm.startPrank(alice);

        erc20Token.approve(address(facet), 1000 ether);
        facet.stakeToken(address(erc20Token), 0, 1000 ether);

        vm.warp(block.timestamp + 365 days);

        uint256 rewardsBalanceBefore = rewardToken.balanceOf(alice);
        facet.claimRewards(address(erc20Token), 0);
        uint256 rewardsBalanceAfter = rewardToken.balanceOf(alice);

        assertGt(rewardsBalanceAfter, rewardsBalanceBefore); // Alice should have received rewards
        vm.stopPrank();
    }

    function test_Unstake() public {
        vm.startPrank(alice);

        erc20Token.approve(address(facet), 1000 ether);
        facet.stakeToken(address(erc20Token), 0, 1000 ether);

        vm.warp(block.timestamp + COOLDOWN_PERIOD + 1);

        facet.unstakeToken(address(erc20Token), 0);

        (uint256 amount,,,) = facet.getStakedTokenInfo(address(erc20Token), 0);

        assertEq(amount, 0); // Alice should have unstaked all tokens

        vm.stopPrank();
    }

    function test_Unstake_RevertsBeforeCooldown() public {
        vm.startPrank(alice);

        erc20Token.approve(address(facet), 1000 ether);
        facet.stakeToken(address(erc20Token), 0, 1000 ether);

        vm.warp(block.timestamp + COOLDOWN_PERIOD - 1);

        (uint256 amount, uint256 stakedAt, uint256 lastClaimedAt, uint256 accumulatedRewards) =
            facet.getStakedTokenInfo(address(erc20Token), 0);

        vm.expectRevert(
            abi.encodeWithSelector(
                StakingFacet.StakingCooldownNotElapsed.selector, stakedAt, COOLDOWN_PERIOD, block.timestamp
            )
        );
        facet.unstakeToken(address(erc20Token), 0);

        vm.stopPrank();
    }
}
