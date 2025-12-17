// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/**
 * @title Staking Library for Compose
 * @notice Provides internal logic for staking functionality using diamond storage.
 *        This library is intended to be used by custom facets to integrate with staking features.
 * @dev Uses ERC-8042 for storage location standardization.
 */

/**
 * @dev Storage position constant defined via keccak256 hash of diamond storage identifier.
 */
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
    mapping(address tokenAddress => uint256 totalStaked) totalStakedPerToken;
    uint256 cooldownPeriod;
    uint256 maxStakeAmount;
    uint256 minStakeAmount;
    mapping(address user => mapping(address spender => uint256 allowance)) allowance;
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

/**
 * @notice An admin function to support a new token type for staking.
 * @param _tokenAddress The address of the token to support.
 * @param _isERC20 Boolean indicating if the token is ERC-20.
 * @param _isERC721 Boolean indicating if the token is ERC-721.
 * @param _isERC1155 Boolean indicating if the token is ERC-1155
 * @dev This function should be restricted to admin use only.
 */
function addSupportedToken(address _tokenAddress, bool _isERC20, bool _isERC721, bool _isERC1155) {
    StakingStorage storage s = getStorage();
    s.supportedTokens[_tokenAddress] = TokenType({isERC20: _isERC20, isERC721: _isERC721, isERC1155: _isERC1155});
}

/**
 * @notice An admin function to set staking parameters.
 * @param _baseAPR The base annual percentage rate for rewards.
 * @param _rewardDecayRate The decay rate for rewards over time.
 * @param _compoundFrequency The frequency at which rewards are compounded.
 * @param _rewardToken The address of the token used for rewards.
 * @param _cooldownPeriod The cooldown period before unstaking is allowed.
 * @param _minStakeAmount The minimum amount required to stake.
 * @param _maxStakeAmount The maximum amount allowed to stake.
 * @dev This function should be restricted to admin use only.
 */
function setStakingParameters(
    uint256 _baseAPR,
    uint256 _rewardDecayRate,
    uint256 _compoundFrequency,
    address _rewardToken,
    uint256 _cooldownPeriod,
    uint256 _minStakeAmount,
    uint256 _maxStakeAmount
) {
    StakingStorage storage s = getStorage();
    s.baseAPR = _baseAPR;
    s.rewardDecayRate = _rewardDecayRate;
    s.compoundFrequency = _compoundFrequency;
    s.rewardToken = _rewardToken;
    s.cooldownPeriod = _cooldownPeriod;
    s.minStakeAmount = _minStakeAmount;
    s.maxStakeAmount = _maxStakeAmount;
}

