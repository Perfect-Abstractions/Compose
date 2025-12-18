// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {Test} from "forge-std/Test.sol";
import {LibStakingHarness} from "./harnesses/LibStakingHarness.sol";
import {ERC20FacetHarness} from "../ERC20//ERC20/harnesses/ERC20FacetHarness.sol";
import {ERC721FacetHarness} from "../ERC721/ERC721/harnesses/ERC721FacetHarness.sol";
import {ERC1155FacetHarness} from "../ERC1155/ERC1155/harnesses/ERC1155FacetHarness.sol";

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
    string constant BASE_URI_1155 = "https://base.uri/";
    string constant TOKEN_URI = "token1.json";

    uint256 constant TOKEN_ID_1 = 1;
    uint256 constant TOKEN_ID_2 = 2;
    uint256 constant TOKEN_ID_3 = 3;

    uint256 constant BASE_APR = 500; // 5%
    uint256 constant REWARD_DECAY_RATE = 50; // 0.5%
    uint256 constant COMPOUND_FREQUENCY = 1 days;
    uint256 constant COOLDOWN_PERIOD = 7 days;
    uint256 constant MIN_STAKE_AMOUNT = 1 ether;
    uint256 constant MAX_STAKE_AMOUNT = 1000 ether;

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

    function test_StakeERC20UpdatesState() public {
        uint256 stakeAmount = 100 ether;

        // Stake ERC-20 tokens
        staking.stakeERC20(address(erc20Token), stakeAmount);

        (uint256 amount,,,) = staking.getStakedTokenInfo(address(erc20Token), 0);

        assertEq(amount, stakeAmount);
    }

    function test_StakeERC721UpdatesState() public {
        // Mint an ERC-721 token to Alice
        erc721Token.mint(alice, TOKEN_ID_1);

        // Stake ERC-721 token
        vm.prank(alice);
        staking.stakeERC721(address(erc721Token), TOKEN_ID_1);

        (uint256 amount,,,) = staking.getStakedTokenInfo(address(erc721Token), TOKEN_ID_1);

        assertEq(amount, 1);
    }

    function test_StakeERC1155UpdatesState() public {
        uint256 stakeAmount = 10;

        // Mint ERC-1155 tokens to Bob
        erc1155Token.mint(bob, TOKEN_ID_2, stakeAmount);

        // Stake ERC-1155 tokens
        vm.prank(bob);
        staking.stakeERC1155(address(erc1155Token), TOKEN_ID_2, stakeAmount);

        (uint256 amount,,,) = staking.getStakedTokenInfo(address(erc1155Token), TOKEN_ID_2);

        assertEq(amount, stakeAmount);
    }
}
