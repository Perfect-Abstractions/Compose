// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/**
 * @title Staking Library for Compose
 * @notice Provides internal logic for staking functionality using diamond storage.
 *        This library is intended to be used by custom facets to integrate with staking features.
 * @dev Uses ERC-8042 for storage location standardization.
 */

/**
 * @notice Thrown when attempting to stake an unsupported token type.
 * @param tokenAddress The address of the unsupported token.
 */
error StakingUnsupportedToken(address tokenAddress);

/**
 * @notice Thrown when attempting to stake a zero amount.
 */
error StakingZeroStakeAmount();

/**
 * @notice Emitted when staking parameters are updated.
 * @param baseAPR The base annual percentage rate for rewards.
 * @param rewardDecayRate The decay rate for rewards over time.
 * @param compoundFrequency The frequency at which rewards are compounded.
 * @param rewardToken The address of the token used for rewards.
 * @param cooldownPeriod The cooldown period before unstaking is allowed.
 * @param minStakeAmount The minimum amount required to stake.
 * @param maxStakeAmount The maximum amount allowed to stake.
 */
event StakingParametersUpdated(
    uint256 baseAPR,
    uint256 rewardDecayRate,
    uint256 compoundFrequency,
    address rewardToken,
    uint256 cooldownPeriod,
    uint256 minStakeAmount,
    uint256 maxStakeAmount
);

/**
 * @notice Emitted when supported token types are added.
 */
event SupportedTokenAdded(address indexed tokenAddress, bool isERC20, bool isERC721, bool isERC1155);

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
 * @dev Emits a SupportedTokenAdded event upon successful addition.
 */
function addSupportedToken(address _tokenAddress, bool _isERC20, bool _isERC721, bool _isERC1155) returns (bool) {
    StakingStorage storage s = getStorage();
    s.supportedTokens[_tokenAddress] = TokenType({isERC20: _isERC20, isERC721: _isERC721, isERC1155: _isERC1155});

    emit SupportedTokenAdded(_tokenAddress, _isERC20, _isERC721, _isERC1155);

    return true;
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
 * @dev Emits a StakingParametersUpdated event upon successful update.
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

    bool isSupported = isTokenSupported(_rewardToken);
    if (!isSupported) {
        revert StakingUnsupportedToken(_rewardToken);
    }

    if (_minStakeAmount == 0 || _maxStakeAmount == 0) {
        revert StakingZeroStakeAmount();
    }

    s.baseAPR = _baseAPR;
    s.rewardDecayRate = _rewardDecayRate;
    s.compoundFrequency = _compoundFrequency;
    s.rewardToken = _rewardToken;
    s.cooldownPeriod = _cooldownPeriod;
    s.minStakeAmount = _minStakeAmount;
    s.maxStakeAmount = _maxStakeAmount;

    emit StakingParametersUpdated(
        _baseAPR, _rewardDecayRate, _compoundFrequency, _rewardToken, _cooldownPeriod, _minStakeAmount, _maxStakeAmount
    );
}

/**
 * @notice Stake ERC-20 tokens
 * @dev Transfers token from the user and updates the amount staked and staking info.
 * @param _tokenAddress The address of the ERC-20 token to stake.
 * @param _value The amount of tokens to stake.
 */
function stakeERC20(address _tokenAddress, uint256 _value) {
    StakingStorage storage s = getStorage();
    StakedTokenInfo storage stake = s.stakedTokens[_tokenAddress][0];

    bool isSupported = isTokenSupported(_tokenAddress);
    if (!isSupported) {
        revert StakingUnsupportedToken(_tokenAddress);
    }

    stake.amount += _value;
    stake.stakedAt = block.timestamp;
    stake.lastClaimedAt = block.timestamp;

    s.totalStakedPerToken[_tokenAddress] += _value;
}

/**
 * @notice Stake ERC-721 tokens
 * @dev Transfers token from the user and updates the amount staked and staking info.
 * @param _tokenAddress The address of the ERC-721 token to stake.
 * @param _tokenId The ID of the token to stake.
 */
function stakeERC721(address _tokenAddress, uint256 _tokenId) {
    StakingStorage storage s = getStorage();
    StakedTokenInfo storage stake = s.stakedTokens[_tokenAddress][_tokenId];

    bool isSupported = isTokenSupported(_tokenAddress);
    if (!isSupported) {
        revert StakingUnsupportedToken(_tokenAddress);
    }

    stake.amount = 1;
    stake.stakedAt = block.timestamp;
    stake.lastClaimedAt = block.timestamp;

    s.totalStakedPerToken[_tokenAddress] += 1;
}

/**
 * @notice Stake ERC-1155 tokens
 * @dev Transfers token from the user and updates the amount staked and staking info.
 * @param _tokenAddress The address of the ERC-1155 token to stake.
 * @param _tokenId The ID of the token to stake.
 * @param _value The amount of tokens to stake.
 */
function stakeERC1155(address _tokenAddress, uint256 _tokenId, uint256 _value) {
    StakingStorage storage s = getStorage();
    StakedTokenInfo storage stake = s.stakedTokens[_tokenAddress][_tokenId];

    bool isSupported = isTokenSupported(_tokenAddress);
    if (!isSupported) {
        revert StakingUnsupportedToken(_tokenAddress);
    }

    stake.amount += _value;
    stake.stakedAt = block.timestamp;
    stake.lastClaimedAt = block.timestamp;

    s.totalStakedPerToken[_tokenAddress] += _value;
}

/**
 * @notice Retrieve staking parameters
 * @return baseAPR The base annual percentage rate for rewards.
 * @return rewardDecayRate The decay rate for rewards over time.
 * @return compoundFrequency The frequency at which rewards are compounded.
 * @return rewardToken The address of the token used for rewards.
 * @return cooldownPeriod The cooldown period before unstaking is allowed.
 * @return minStakeAmount The minimum amount required to stake.
 * @return maxStakeAmount The maximum amount allowed to stake.
 */
function getStakingParameters()
    view
    returns (
        uint256 baseAPR,
        uint256 rewardDecayRate,
        uint256 compoundFrequency,
        address rewardToken,
        uint256 cooldownPeriod,
        uint256 minStakeAmount,
        uint256 maxStakeAmount
    )
{
    StakingStorage storage s = getStorage();
    return (
        s.baseAPR,
        s.rewardDecayRate,
        s.compoundFrequency,
        s.rewardToken,
        s.cooldownPeriod,
        s.minStakeAmount,
        s.maxStakeAmount
    );
}

/**
 * @notice Retrieve staked token info for ERC-20, ERC-721, or ERC-1155 tokens
 * @param _tokenAddress The address of the token.
 * @param _tokenId The ID of the token (0 for ERC-20).
 * @return amount The amount of tokens staked.
 * @return stakedAt The timestamp when the tokens were staked.
 * @return lastClaimedAt The timestamp when rewards were last claimed.
 * @return accumulatedRewards The total accumulated rewards for the staked tokens.
 */
function getStakedTokenInfo(address _tokenAddress, uint256 _tokenId)
    view
    returns (uint256 amount, uint256 stakedAt, uint256 lastClaimedAt, uint256 accumulatedRewards)
{
    StakingStorage storage s = getStorage();
    StakedTokenInfo storage stake = s.stakedTokens[_tokenAddress][_tokenId];
    return (stake.amount, stake.stakedAt, stake.lastClaimedAt, stake.accumulatedRewards);
}

/**
 * @notice Retrieve supported token types
 * @param _tokenAddress The address of the token.
 * @return true if the token is supported, false otherwise.
 */
function isTokenSupported(address _tokenAddress) view returns (bool) {
    StakingStorage storage s = getStorage();
    TokenType storage tokenType = s.supportedTokens[_tokenAddress];
    return tokenType.isERC20 || tokenType.isERC721 || tokenType.isERC1155;
}
