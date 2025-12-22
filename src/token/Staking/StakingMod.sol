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
 * @notice Thrown when an overflow occurs during arithmetic operations.
 */
error StakingOverflow();

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
    mapping(address tokenOwner => mapping(address tokenAddress => mapping(uint256 tokenId => StakedTokenInfo)))
        stakedTokens;
    uint256 baseAPR;
    uint256 rewardDecayRate;
    uint256 compoundFrequency;
    address rewardToken;
    mapping(address tokenAddress => uint256 totalStaked) totalStakedPerToken;
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
 * @notice Stake ERC-20 tokens
 * @dev Transfers token from the user and updates the amount staked and staking info.
 * @param _tokenAddress The address of the ERC-20 token to stake.
 * @param _value The amount of tokens to stake.
 */
function stakeERC20(address _tokenAddress, uint256 _value) {
    StakingStorage storage s = getStorage();
    StakedTokenInfo storage stake = s.stakedTokens[msg.sender][_tokenAddress][0];

    bool isSupported = isTokenSupported(_tokenAddress);
    if (!isSupported) {
        revert StakingUnsupportedToken(_tokenAddress);
    }

    unchecked {
        stake.amount += _value;
        stake.stakedAt = block.timestamp;
        stake.lastClaimedAt = block.timestamp;

        s.totalStakedPerToken[_tokenAddress] += _value;
    }
}

/**
 * @notice Stake ERC-721 tokens
 * @dev Transfers token from the user and updates the amount staked and staking info.
 * @param _tokenAddress The address of the ERC-721 token to stake.
 * @param _tokenId The ID of the token to stake.
 */
function stakeERC721(address _tokenAddress, uint256 _tokenId) {
    StakingStorage storage s = getStorage();
    StakedTokenInfo storage stake = s.stakedTokens[msg.sender][_tokenAddress][_tokenId];

    bool isSupported = isTokenSupported(_tokenAddress);
    if (!isSupported) {
        revert StakingUnsupportedToken(_tokenAddress);
    }

    unchecked {
        stake.amount = 1;
        stake.stakedAt = block.timestamp;
        stake.lastClaimedAt = block.timestamp;

        s.totalStakedPerToken[_tokenAddress] += 1;
    }
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
    StakedTokenInfo storage stake = s.stakedTokens[msg.sender][_tokenAddress][_tokenId];

    bool isSupported = isTokenSupported(_tokenAddress);
    if (!isSupported) {
        revert StakingUnsupportedToken(_tokenAddress);
    }

    unchecked {
        stake.amount += _value;
        stake.stakedAt = block.timestamp;
        stake.lastClaimedAt = block.timestamp;

        s.totalStakedPerToken[_tokenAddress] += _value;
    }
}

/**
 * @notice Calculates the rewards for a staked token.
 * @dev Uses base APR, decay rate, and compounding frequency to compute rewards.
 * @dev Rewards are calculated based on the time since last claim.
 * @dev Uses fixed-point arithmetic with 1e18 precision.
 * @param _tokenAddress The address of the staked token.
 * @param _tokenId The ID of the staked token.
 * @return finalReward The calculated reward amount.
 */
function calculateRewards(address _tokenAddress, uint256 _tokenId) view returns (uint256) {
    StakingStorage storage s = getStorage();
    StakedTokenInfo storage stake = s.stakedTokens[msg.sender][_tokenAddress][_tokenId];

    // Calculate staking duration
    uint256 stakedDuration = block.timestamp - stake.lastClaimedAt;
    if (stakedDuration == 0 || stake.amount == 0) {
        return 0;
    }

    // Base reward rate with decay
    uint256 baseReward = (stake.amount * s.baseAPR * stakedDuration) / (365 days * 100);

    // Apply decay factor based on staking duration and compound frequency
    uint256 decayFactor;
    if (s.rewardDecayRate > 0 && s.compoundFrequency > 0) {
        uint256 exponent = stakedDuration / s.compoundFrequency;

        /**
         * Cap exponent to prevent overflow
         * With max exponent of 125, even 2e18^125 is manageable with rpow
         */
        if (exponent > 125) {
            exponent = 125;
        }

        decayFactor = rpow(s.rewardDecayRate, exponent);
    } else {
        decayFactor = 1e18;
    }

    uint256 finalReward = (baseReward * decayFactor) / (10 ** 18);

    return finalReward;
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
    StakedTokenInfo storage stake = s.stakedTokens[msg.sender][_tokenAddress][_tokenId];
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

/**
 * @notice Raises a 1e18 fixed-point number to an integer power, with 1e18 precision.
 * @dev Implements binary exponentiation. Handles underflow and overflow safely.
 * @param _base 1e18-scaled fixed-point base (e.g. 0.99e18, 1e18, 1.01e18).
 * @param _exp Integer exponent (e.g staked duration / compound frequency).
 * @return result Fixed-point result of base^exp, scaled by 1e18.
 */
function rpow(uint256 _base, uint256 _exp) pure returns (uint256 result) {
    result = 1e18; // Initialize result as 1 in 1e18 fixed-point
    uint256 base = _base;

    while (_exp > 0) {
        if (_exp % 2 == 1) {
            result = rmul(result, base);
        }
        base = rmul(base, base);
        _exp /= 2;
    }

    return result;
}

/**
 * @notice Multiplies two 1e18 fixed-point numbers, returning a 1e18 fixed-point result.
 * @dev Equivalent to (x * y) / 1e18, rounded down.
 */
function rmul(uint256 x, uint256 y) pure returns (uint256 z) {
    if (x == 0 || y == 0) {
        return 0;
    }

    /**
     * Check for overflow in multiplication
     */
    if (x > type(uint256).max / y) {
        revert StakingOverflow();
    }

    unchecked {
        z = (x * y) / 1e18;
    }

    return z;
}
