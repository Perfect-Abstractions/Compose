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
    uint256 constant MIN_STAKE_AMOUNT = 1 ether;
    uint256 constant MAX_STAKE_AMOUNT = 1_000_000 ether;

    event TokensStaked(address indexed staker, address indexed tokenAddress, uint256 indexed tokenId, uint256 amount);
    event TokensUnstaked(address indexed staker, address indexed tokenAddress, uint256 indexed tokenId, uint256 amount);
    event StakingParametersUpdated(
        uint256 baseAPR,
        uint256 rewardDecayRate,
        uint256 compoundFrequency,
        address rewardToken,
        uint256 cooldownPeriod,
        uint256 minStakeAmount,
        uint256 maxStakeAmount
    );

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

    function test_ParametersAreSetCorrectly_EmitEventStakingParametersUpdated() public {
        vm.startPrank(owner);

        facet.addSupportedToken(address(rewardToken), true, false, false);

        // Expect event
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

        // Re-initialize to trigger event
        facet.setStakingParameters(
            BASE_APR,
            REWARD_DECAY_RATE,
            COMPOUND_FREQUENCY,
            address(rewardToken),
            COOLDOWN_PERIOD,
            MIN_STAKE_AMOUNT,
            MAX_STAKE_AMOUNT
        );

        vm.stopPrank();
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

    function test_StakeToken_EmitTokensStakedEvent() public {
        vm.startPrank(alice);

        // Approve the staking contract to spend Alice's tokens
        erc20Token.approve(address(facet), 500 ether);

        // Expect event
        vm.expectEmit(true, true, true, true);
        emit TokensStaked(alice, address(erc20Token), 0, 500 ether);

        // Stake tokens
        facet.stakeToken(address(erc20Token), 0, 500 ether);

        vm.stopPrank();
    }

    function test_StakeToken_RevertsForUnsupportedToken() public {
        address unsupportedToken = makeAddr("unsupportedToken");

        vm.startPrank(alice);

        vm.expectRevert(abi.encodeWithSelector(StakingFacet.StakingUnsupportedToken.selector, unsupportedToken));
        facet.stakeToken(unsupportedToken, 0, 100 ether);

        vm.stopPrank();
    }

    function test_StakeToken_RevertsForMinimumAmount() public {
        vm.startPrank(alice);

        vm.expectRevert(
            abi.encodeWithSelector(StakingFacet.StakingAmountBelowMinimum.selector, 0 ether, MIN_STAKE_AMOUNT)
        );
        facet.stakeToken(address(erc20Token), 0, 0 ether);

        vm.stopPrank();
    }

    function test_StakeToken_RevertsForMaximumAmount() public {
        vm.startPrank(alice);

        vm.expectRevert(
            abi.encodeWithSelector(StakingFacet.StakingAmountAboveMaximum.selector, 2_000_000 ether, MAX_STAKE_AMOUNT)
        );
        facet.stakeToken(address(erc20Token), 0, 2_000_000 ether);

        vm.stopPrank();
    }

    function test_StakeERC721Token_RevertsIfNotOwner() public {
        vm.startPrank(bob);

        // Bob tries to stake Alice's NFT
        vm.expectRevert(
            abi.encodeWithSelector(StakingFacet.StakingNotTokenOwner.selector, bob, address(erc721Token), TOKEN_ID_1)
        );
        facet.stakeToken(address(erc721Token), TOKEN_ID_1, 1);

        vm.stopPrank();
    }

    function test_StakeERC1155Token_RevertsIfNotEnoughBalance() public {
        vm.startPrank(bob);

        // Bob tries to stake more ERC-1155 tokens than he owns
        vm.expectRevert(abi.encodeWithSelector(StakingFacet.StakingInsufficientBalance.selector, bob, 10, 20));
        facet.stakeToken(address(erc1155Token), TOKEN_ID_2, 20);

        vm.stopPrank();
    }

    function test_UnstakeERC20Token() public {
        vm.startPrank(alice);

        // Approve and stake tokens
        erc20Token.approve(address(facet), 500 ether);
        facet.stakeToken(address(erc20Token), 0, 500 ether);

        // Warp time to pass cooldown period
        vm.warp(block.timestamp + COOLDOWN_PERIOD + 1);

        // Unstake tokens
        facet.unstakeToken(address(erc20Token), 0);

        // Verify staking state is reset
        (uint256 amount,,,) = facet.getStakedTokenInfo(address(erc20Token), 0);
        assertEq(amount, 0);

        vm.stopPrank();
    }

    function test_UnstakeERC721Token() public {
        vm.startPrank(bob);

        // Approve and stake NFT
        erc721Token.approve(address(facet), TOKEN_ID_2);
        facet.stakeToken(address(erc721Token), TOKEN_ID_2, 1);

        // Warp time to pass cooldown period
        vm.warp(block.timestamp + COOLDOWN_PERIOD + 1);

        // Unstake NFT
        facet.unstakeToken(address(erc721Token), TOKEN_ID_2);

        // Verify staking state is reset
        (uint256 amount,,,) = facet.getStakedTokenInfo(address(erc721Token), TOKEN_ID_2);
        assertEq(amount, 0);

        vm.stopPrank();
    }

    function test_UnstakeERC1155Token() public {
        vm.startPrank(alice);

        // Approve and stake ERC-1155 tokens
        erc1155Token.setApprovalForAll(address(facet), true);
        facet.stakeToken(address(erc1155Token), TOKEN_ID_1, 5);

        // Warp time to pass cooldown period
        vm.warp(block.timestamp + COOLDOWN_PERIOD + 1);

        // Unstake ERC-1155 tokens
        facet.unstakeToken(address(erc1155Token), TOKEN_ID_1);

        // Verify staking state is reset
        (uint256 amount,,,) = facet.getStakedTokenInfo(address(erc1155Token), TOKEN_ID_1);
        assertEq(amount, 0);

        vm.stopPrank();
    }

    function test_UnstakeToken_EmitTokensUnstakedEvent() public {
        vm.startPrank(alice);

        // Approve and stake tokens
        erc20Token.approve(address(facet), 500 ether);
        facet.stakeToken(address(erc20Token), 0, 500 ether);

        // Warp time to pass cooldown period
        vm.warp(block.timestamp + COOLDOWN_PERIOD + 1);

        // Expect event
        vm.expectEmit(true, true, true, true);
        emit TokensUnstaked(alice, address(erc20Token), 0, 500 ether);

        // Unstake tokens
        facet.unstakeToken(address(erc20Token), 0);

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

    function test_Unstake_RevertsZeroStakeAmount() public {
        vm.startPrank(alice);

        vm.expectRevert(abi.encodeWithSelector(StakingFacet.StakingZeroStakeAmount.selector));
        facet.unstakeToken(address(erc20Token), 0);

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

        (uint256 amount, uint256 stakedAt, uint256 lastClaimedAt, uint256 accumulatedRewards) =
            facet.getStakedTokenInfo(address(erc20Token), 0);

        assertGt(rewardsBalanceAfter, rewardsBalanceBefore); // Alice should have received rewards
        assertEq(accumulatedRewards, rewardsBalanceAfter - rewardsBalanceBefore);
        assertEq(lastClaimedAt, block.timestamp);
        assertEq(amount, 1000 ether); // Staked amount should remain unchanged
        vm.stopPrank();
    }

    // Fuzz Tests for ERC-20 Staking
    function testFuzz_StakeAmount(uint256 stakeAmount) public {
        stakeAmount = bound(stakeAmount, 1e18, 1_000_000e18); // Clamp between 1 and 1,000,000 tokens

        vm.startPrank(owner);
        facet.addSupportedToken(address(erc20Token), true, false, false);
        facet.addSupportedToken(address(rewardToken), true, false, false);
        facet.setStakingParameters(1000, 1e18, 1 days, address(rewardToken), 0, 1e18, type(uint256).max);
        vm.stopPrank();

        erc20Token.mint(alice, stakeAmount);
        rewardToken.mint(address(facet), 1_000_000 ether);

        vm.startPrank(alice);
        erc20Token.approve(address(facet), stakeAmount);
        facet.stakeToken(address(erc20Token), 0, stakeAmount);

        (uint256 amount,,,) = facet.getStakedTokenInfo(address(erc20Token), 0);
        assertEq(amount, stakeAmount);
        vm.stopPrank();
    }

    // Fuzz Test for long staking durations
    function testFuzz_RewardAfterTime(uint256 daysStaked) public {
        daysStaked = bound(daysStaked, 1, 3650); // 1 day to 10 years

        vm.startPrank(owner);
        facet.addSupportedToken(address(erc20Token), true, false, false);
        facet.addSupportedToken(address(rewardToken), true, false, false);
        facet.setStakingParameters(1000, 1e18, 1 days, address(rewardToken), 0, 1e18, type(uint256).max);
        vm.stopPrank();

        erc20Token.mint(alice, 100 ether);
        rewardToken.mint(address(facet), 1_000_000 ether);

        vm.startPrank(alice);
        erc20Token.approve(address(facet), 100 ether);
        facet.stakeToken(address(erc20Token), 0, 100 ether);

        vm.warp(block.timestamp + (daysStaked * 1 days));
        uint256 rewards = facet.calculateRewardsForToken(address(erc20Token), 0);

        assertGt(rewards, 0);
        assertLe(rewards, 1_000_000 ether); // Should not exceed total reward pool
        vm.stopPrank();
    }

    function testFuzz_RewardDecay(uint256 stakedSeconds, uint256 decayRate, uint256 compoundFreq) public {
        vm.startPrank(owner);
        // Clamp fuzzed values to safe bounds
        stakedSeconds = bound(stakedSeconds, 1 days, 3650 days); // 1 day to 10 years
        decayRate = bound(decayRate, 0.5e18, 1.5e18); // 50% to 150%
        compoundFreq = bound(compoundFreq, 1 days, 365 days); // 1 day to 1 year

        facet.addSupportedToken(address(erc20Token), true, false, false);
        facet.addSupportedToken(address(rewardToken), true, false, false);

        // set the staking parameters
        facet.setStakingParameters(
            1000, decayRate, compoundFreq, address(rewardToken), COOLDOWN_PERIOD, 1, type(uint256).max
        );

        vm.stopPrank();

        /**
         * Warp time forward to ensure block.timestamp > stakedSeconds
         * Add buffer to ensure we're well past the stake time
         */
        vm.warp(stakedSeconds + 1 days);

        uint256 stakeTime = block.timestamp - stakedSeconds;
        facet.testSetStakeInfo(alice, address(erc20Token), 0, 100 ether, stakeTime, stakeTime);

        vm.prank(alice);
        uint256 rewards = facet.calculateRewardsForToken(address(erc20Token), 0);

        assertLe(rewards, type(uint256).max);
        if (decayRate >= 1e18 && stakedSeconds < 10 * 365 days) {
            assertGt(rewards, 0);
        }

        if (rewards == 0 || rewards > 1_000_000 ether) {
            emit log_named_uint("Decay Rate", decayRate);
            emit log_named_uint("Compound Frequency", compoundFreq);
            emit log_named_uint("Staked Seconds", stakedSeconds);
            emit log_named_uint("Calculated Rewards", rewards);
        }
    }

    function testFuzz_StakeUnstake(uint256 stakeAmount, uint256 waitDays) public {
        stakeAmount = bound(stakeAmount, 1e18, 1_000e18); // 1 to 1,000 tokens
        waitDays = bound(waitDays, 1, 365); // 1 to 365 days

        vm.startPrank(owner);
        facet.addSupportedToken(address(erc20Token), true, false, false);
        facet.addSupportedToken(address(rewardToken), true, false, false);
        facet.setStakingParameters(1000, 1e18, 1 days, address(rewardToken), 1 days, 1e18, type(uint256).max);
        vm.stopPrank();

        erc20Token.mint(alice, stakeAmount);
        rewardToken.mint(address(facet), 1_000_000 ether);

        vm.startPrank(alice);
        erc20Token.approve(address(facet), stakeAmount);
        facet.stakeToken(address(erc20Token), 0, stakeAmount);

        vm.warp(block.timestamp + (waitDays * 1 days) + COOLDOWN_PERIOD + 1);

        facet.unstakeToken(address(erc20Token), 0);
        (uint256 amount,,,) = facet.getStakedTokenInfo(address(erc20Token), 0);
        assertEq(amount, 0);
        vm.stopPrank();
    }

    function testFuzz_UnsupportedToken(address randomToken) public {
        vm.assume(randomToken != address(erc20Token) && randomToken != address(0));

        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(StakingFacet.StakingUnsupportedToken.selector, randomToken));
        facet.stakeToken(randomToken, 0, 100 ether);
        vm.stopPrank();
    }

    function test_FixedPoint_IntegerPower() public {
        uint256 result = facet.rPow(2e18, 3); // 2^3 = 8
        assertEq(result, 8e18);

        result = facet.rPow(5e18, 0); // 5^0 = 1
        assertEq(result, 1e18);

        result = facet.rPow(1e18, 10); // 1^10 = 1
        assertEq(result, 1e18);

        result = facet.rPow(3e18, 4); // 3^4 = 81
        assertEq(result, 81e18);
    }

    function test_FixedPoint_Multiply() public {
        uint256 result = facet.rMul(2e18, 3e18); // 2 * 3 = 6
        assertEq(result, 6e18);

        result = facet.rMul(5e18, 0e18); // 5 * 0 = 0
        assertEq(result, 0);

        result = facet.rMul(1e18, 10e18); // 1 * 10 = 10
        assertEq(result, 10e18);

        result = facet.rMul(3e18, 4e18); // 3 * 4 = 12
        assertEq(result, 12e18);
    }
}
