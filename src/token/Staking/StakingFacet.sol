// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/**
 * @title LibStaking - Standard Staking Library
 * @notice Provides internal functions and storage layout for staking ERC-20, ERC-721, and ERC-1155 tokens.
 * @dev Uses ERC-8042 for storage location standardization.
 */

/**
 * @notice Thrown when attempting to stake an unsupported token type.
 * @param tokenAddress The address of the unsupported token.
 */
error StakingUnsupportedToken(address tokenAddress);

/**
 * @notice Thrown when attempting to stake an amount below the minimum stake amount.
 * @param amount The attempted stake amount.
 * @param minAmount The minimum required stake amount.
 */
error StakingAmountBelowMinimum(uint256 amount, uint256 minAmount);

/**
 * @notice Thrown when attempting to stake an amount above the maximum stake amount.
 * @param amount The attempted stake amount.
 * @param maxAmount The maximum allowed stake amount.
 */
error StakingAmountAboveMaximum(uint256 amount, uint256 maxAmount);

/**
 * @notice Thrown when attempting to unstake before the cooldown period has elapsed.
 * @param stakedAt The timestamp when the tokens were staked.
 * @param cooldownPeriod The required cooldown period in seconds.
 * @param currentTime The current block timestamp.
 */
error StakingCooldownNotElapsed(uint256 stakedAt, uint256 cooldownPeriod, uint256 currentTime);

bytes32 constant STAKING_STORAGE_POSITION = keccak256("compose.staking");

/**
 * @notice Structure containing staking information for a specific token.
 * @param amount The amount of tokens staked.
 * @param stakedAt The timestamp when the tokens were staked.
 * @param lastClaimedAt The timestamp when rewards were last claimed.
 * @param accumulatedRewards The total accumulated rewards for the staked tokens.
 */
struct StakedTokenInfo {
    uint256 amount;
    uint256 stakedAt;
    uint256 lastClaimedAt;
    uint256 accumulatedRewards;
}

/**
 * @notice Structure containing type of tokens being staked.
 * @param isERC20 Boolean indicating if the token is ERC-20.
 * @param isERC721 Boolean indicating if the token is ERC-721.
 * @param isERC1155 Boolean indicating if the token is ERC-1155.
 */
struct TokenType {
    bool isERC20;
    bool isERC721;
    bool isERC1155;
}

/**
 * @custom:storage-location erc8042:compose.staking
 */
struct StakingStorage {
    mapping(address tokenType => TokenType) supportedTokens;
    mapping(address tokenAddress => mapping(uint256 tokenId => StakedTokenInfo)) stakedTokens;
    uint256 baseAPR;
    uint256 rewardDecayRate;
    uint256 compoundFrequency;
    address rewardToken;
    mapping(address user => uint256 totalStaked) totalStakedPerToken;
    uint256 cooldownPeriod;
    uint256 maxStakeAmount;
    uint256 minStakeAmount;
}

/**
 * @notice Returns the staking storage structure from its predefined slot.
 * @dev Uses inline assembly to access diamond storage location.
 * @return s The storage reference to StakingStorage.
 */
function getStorage() pure returns (StakingStorage storage s) {
    bytes32 position = STAKING_STORAGE_POSITION;
    assembly {
        s.slot := position
    }
}
