// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/**
 * @dev Simplified ERC20 interface.
 */
interface IERC20 {
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address to, uint256 amount) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

/**
 * @dev Simplified ERC721 interface.
 */
interface IERC721 {
    function ownerOf(uint256 tokenId) external view returns (address owner);

    function safeTransferFrom(address from, address to, uint256 tokenId) external;
}

/**
 * @dev Simplified ERC1155 interface.
 */
interface IERC1155 {
    function balanceOf(address account, uint256 id) external view returns (uint256);
    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes calldata data) external;
}

/**
 * @title ERC-721 Token Receiver Interface
 * @notice Interface for contracts that want to handle safe transfers of ERC-721 tokens.
 * @dev Contracts implementing this must return the selector to confirm token receipt.
 */
interface IERC721Receiver {
    /**
     * @notice Handles the receipt of an NFT.
     * @param _operator The address which called `safeTransferFrom`.
     * @param _from The previous owner of the token.
     * @param _tokenId The NFT identifier being transferred.
     * @param _data Additional data with no specified format.
     * @return The selector to confirm the token transfer.
     */
    function onERC721Received(address _operator, address _from, uint256 _tokenId, bytes calldata _data)
        external
        returns (bytes4);
}

/**
 * @title ERC-1155 Token Receiver Interface
 * @notice Interface that must be implemented by smart contracts in order to receive ERC-1155 token transfers.
 */
interface IERC1155Receiver {
    /**
     * @notice Handles the receipt of a single ERC-1155 token type.
     * @dev This function is called at the end of a `safeTransferFrom` after the balance has been updated.
     *
     * IMPORTANT: To accept the transfer, this must return
     * `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))`
     * (i.e. 0xf23a6e61, or its own function selector).
     *
     * @param _operator The address which initiated the transfer (i.e. msg.sender).
     * @param _from The address which previously owned the token.
     * @param _id The ID of the token being transferred.
     * @param _value The amount of tokens being transferred.
     * @param _data Additional data with no specified format.
     * @return `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))` if transfer is allowed.
     */
    function onERC1155Received(address _operator, address _from, uint256 _id, uint256 _value, bytes calldata _data)
        external
        returns (bytes4);

    /**
     * @notice Handles the receipt of multiple ERC-1155 token types.
     * @dev This function is called at the end of a `safeBatchTransferFrom` after the balances have been updated.
     *
     * IMPORTANT: To accept the transfer(s), this must return
     * `bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))`
     * (i.e. 0xbc197c81, or its own function selector).
     *
     * @param _operator The address which initiated the batch transfer (i.e. msg.sender).
     * @param _from The address which previously owned the token.
     * @param _ids An array containing ids of each token being transferred (order and length must match _values array).
     * @param _values An array containing amounts of each token being transferred (order and length must match _ids array).
     * @param _data Additional data with no specified format.
     * @return `bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))` if transfer is allowed.
     */
    function onERC1155BatchReceived(
        address _operator,
        address _from,
        uint256[] calldata _ids,
        uint256[] calldata _values,
        bytes calldata _data
    ) external returns (bytes4);
}

/**
 * @title Staking Facet
 * @notice A complete, dependency-free staking facet for ERC-20, ERC-721, and ERC-1155 tokens.
 * @dev Implements staking, unstaking, and reward claiming functionalities using diamond storage.
 */
contract StakingFacet {
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
     * @notice Thrown when attempting to stake an amount below the minimum stake amount.
     * @param amount The attempted stake amount.
     * @param minAmount The minimum required stake amount.
     */
    error StakingAmountBelowMinimum(uint256 amount, uint256 minAmount);

    /**
     * @notice Thrown when a token transfer fails.
     */
    error StakingTransferFailed();

    /**
     * @notice Thrown when attempting to stake an amount above the maximum stake amount.
     * @param amount The attempted stake amount.
     * @param maxAmount The maximum allowed stake amount.
     */
    error StakingAmountAboveMaximum(uint256 amount, uint256 maxAmount);

    /**
     * @notice Thrown when there's no rewards to claim for the staked token.
     * @param tokenAddress The address of the staked token.
     * @param tokenId The ID of the staked token.
     */
    error StakingNoRewardsToClaim(address tokenAddress, uint256 tokenId);

    /**
     * @notice Thrown when attempting to unstake before the cooldown period has elapsed.
     * @param stakedAt The timestamp when the tokens were staked.
     * @param cooldownPeriod The required cooldown period in seconds.
     * @param currentTime The current block timestamp.
     */
    error StakingCooldownNotElapsed(uint256 stakedAt, uint256 cooldownPeriod, uint256 currentTime);

    /**
     * @notice Thrown when owner is not the owner of the staked token.
     * @param owner The address of the token owner.
     * @param tokenAddress The address of the staked token.
     * @param tokenId The ID of the staked token.
     */
    error StakingNotTokenOwner(address owner, address tokenAddress, uint256 tokenId);

    /**
     * @notice Thrown when an account has insufficient balance for a transfer or burn.
     * @param _sender Address attempting the transfer.
     * @param _balance Current balance of the sender.
     * @param _needed Amount required to complete the operation.
     */
    error StakingInsufficientBalance(address _sender, uint256 _balance, uint256 _needed);

    /**
     * @notice Thrown when the sender address is invalid (e.g., zero address).
     * @param _sender Invalid sender address.
     */
    error StakingInvalidSender(address _sender);

    /**
     * @notice Thrown when the receiver address is invalid (e.g., zero address).
     * @param _receiver Invalid receiver address.
     */
    error StakingInvalidReceiver(address _receiver);

    /**
     * @notice Thrown when a spender tries to use more than the approved allowance.
     * @param _spender Address attempting to spend.
     * @param _allowance Current allowance for the spender.
     * @param _needed Amount required to complete the operation.
     */
    error StakingInsufficientAllowance(address _spender, uint256 _allowance, uint256 _needed);

    /**
     * @notice Thrown when an overflow occurs during arithmetic operations.
     */
    error StakingOverflow();

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
     * @notice Emitted when tokens are successfully staked.
     * @param staker The address of the user who staked the tokens.
     * @param tokenAddress The address of the staked token.
     * @param tokenId The ID of the staked token.
     * @param amount The amount of tokens staked.
     */
    event TokensStaked(address indexed staker, address indexed tokenAddress, uint256 indexed tokenId, uint256 amount);

    /**
     * @notice Emitted when tokens are successfully unstaked.
     * @param staker The address of the user who unstaked the tokens.
     * @param tokenAddress The address of the unstaked token.
     * @param tokenId The ID of the unstaked token.
     * @param amount The amount of tokens unstaked.
     */
    event TokensUnstaked(address indexed staker, address indexed tokenAddress, uint256 indexed tokenId, uint256 amount);

    /**
     * @notice Emitted when rewards are claimed for staked tokens.
     * @param staker The address of the user who claimed the rewards.
     * @param tokenAddress The address of the staked token.
     * @param tokenId The ID of the staked token.
     * @param rewardAmount The amount of rewards claimed.
     */
    event RewardsClaimed(
        address indexed staker, address indexed tokenAddress, uint256 indexed tokenId, uint256 rewardAmount
    );

    /**
     * @notice Emitted when an approval is made for a spender by an owner.
     * @param _owner The address granting the allowance.
     * @param _spender The address receiving the allowance.
     * @param _oldValue The previous allowance amount.
     * @param _newValue The new allowance amount.
     */
    event Approval(address indexed _owner, address indexed _spender, uint256 _oldValue, uint256 _newValue);

    /**
     * @notice Emitted when tokens are transferred between two addresses.
     * @param _from Address sending the tokens.
     * @param _to Address receiving the tokens.
     * @param _value Amount of tokens transferred.
     */
    event Transfer(address indexed _from, address indexed _to, uint256 _value);

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
    function getStorage() internal pure returns (StakingStorage storage s) {
        bytes32 position = STAKING_STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }

    /**
     * @notice Stakes tokens of a supported type.
     * @param _tokenAddress The address of the token to stake.
     * @param _tokenId The ID of the token to stake (for ERC-721 and ERC-1155).
     * @param _amount The amount of tokens to stake.
     */
    function stakeToken(address _tokenAddress, uint256 _tokenId, uint256 _amount) external {
        StakingStorage storage s = getStorage();
        TokenType storage tokenType = s.supportedTokens[_tokenAddress];

        bool isSupported = isTokenSupported(_tokenAddress);
        bool isTokenERC20 = s.supportedTokens[_tokenAddress].isERC20;

        if (!isSupported) {
            revert StakingUnsupportedToken(_tokenAddress);
        }

        if (s.minStakeAmount > 0) {
            if (isTokenERC20 && _amount < s.minStakeAmount) {
                revert StakingAmountBelowMinimum(_amount, s.minStakeAmount);
            }
        }
        if (s.maxStakeAmount > 0) {
            if (_amount + s.totalStakedPerToken[_tokenAddress] >= s.maxStakeAmount) {
                revert StakingAmountAboveMaximum(_amount, s.maxStakeAmount);
            }
        }

        if (s.supportedTokens[_tokenAddress].isERC20) {
            bool success = IERC20(_tokenAddress).transferFrom(msg.sender, address(this), _amount);
            if (!success) {
                revert StakingTransferFailed();
            }
            stakeERC20(_tokenAddress, _amount);
        } else if (s.supportedTokens[_tokenAddress].isERC721) {
            if (IERC721(_tokenAddress).ownerOf(_tokenId) != msg.sender) {
                revert StakingNotTokenOwner(msg.sender, _tokenAddress, _tokenId);
            }
            IERC721(_tokenAddress).safeTransferFrom(msg.sender, address(this), _tokenId);
            stakeERC721(_tokenAddress, _tokenId);
        } else if (s.supportedTokens[_tokenAddress].isERC1155) {
            if (IERC1155(_tokenAddress).balanceOf(msg.sender, _tokenId) < _amount) {
                revert StakingInsufficientBalance(
                    msg.sender, IERC1155(_tokenAddress).balanceOf(msg.sender, _tokenId), _amount
                );
            }
            IERC1155(_tokenAddress).safeTransferFrom(msg.sender, address(this), _tokenId, _amount, "");
            stakeERC1155(_tokenAddress, _tokenId, _amount);
        }

        emit TokensStaked(msg.sender, _tokenAddress, _tokenId, _amount);
    }

    /**
     * @notice Unstakes tokens of a supported type.
     * @param _tokenAddress The address of the token to unstake.
     * @param _tokenId The ID of the token to unstake (for ERC-721 and ERC-1155).
     */
    function unstakeToken(address _tokenAddress, uint256 _tokenId) external {
        StakingStorage storage s = getStorage();
        StakedTokenInfo storage stake = s.stakedTokens[msg.sender][_tokenAddress][_tokenId];

        uint256 amount = stake.amount;
        if (amount == 0) {
            revert StakingZeroStakeAmount();
        }

        if (s.cooldownPeriod > 0 && block.timestamp <= stake.stakedAt + s.cooldownPeriod) {
            revert StakingCooldownNotElapsed(stake.stakedAt, s.cooldownPeriod, block.timestamp);
        }

        uint256 rewards = calculateRewards(_tokenAddress, _tokenId);
        if (rewards > 0) {
            _claimRewards(_tokenAddress, _tokenId);
        }

        if (s.supportedTokens[_tokenAddress].isERC20) {
            IERC20(_tokenAddress).transfer(msg.sender, amount);
        } else if (s.supportedTokens[_tokenAddress].isERC721) {
            IERC721(_tokenAddress).safeTransferFrom(address(this), msg.sender, _tokenId);
        } else if (s.supportedTokens[_tokenAddress].isERC1155) {
            IERC1155(_tokenAddress).safeTransferFrom(address(this), msg.sender, _tokenId, amount, "");
        }

        s.totalStakedPerToken[_tokenAddress] -= amount;

        emit TokensUnstaked(msg.sender, _tokenAddress, _tokenId, amount);

        delete s.stakedTokens[msg.sender][_tokenAddress][_tokenId];
    }

    /**
     * @notice An admin function to support a new token type for staking.
     * @param _tokenAddress The address of the token to support.
     * @param _isERC20 Boolean indicating if the token is ERC-20.
     * @param _isERC721 Boolean indicating if the token is ERC-721.
     * @param _isERC1155 Boolean indicating if the token is ERC-1155
     * @dev This function should be restricted to admin use only.
     */
    function addSupportedToken(address _tokenAddress, bool _isERC20, bool _isERC721, bool _isERC1155)
        external
        returns (bool)
    {
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
     */
    function setStakingParameters(
        uint256 _baseAPR,
        uint256 _rewardDecayRate,
        uint256 _compoundFrequency,
        address _rewardToken,
        uint256 _cooldownPeriod,
        uint256 _minStakeAmount,
        uint256 _maxStakeAmount
    ) external {
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
            _baseAPR,
            _rewardDecayRate,
            _compoundFrequency,
            _rewardToken,
            _cooldownPeriod,
            _minStakeAmount,
            _maxStakeAmount
        );
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
        external
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
        external
        view
        returns (uint256 amount, uint256 stakedAt, uint256 lastClaimedAt, uint256 accumulatedRewards)
    {
        StakingStorage storage s = getStorage();
        StakedTokenInfo storage stake = s.stakedTokens[msg.sender][_tokenAddress][_tokenId];
        return (stake.amount, stake.stakedAt, stake.lastClaimedAt, stake.accumulatedRewards);
    }

    /**
     * @notice Claims rewards for a staked token.
     * @dev Updates the last claimed timestamp and accumulated rewards.
     * @param _tokenAddress The address of the staked token.
     * @param _tokenId The ID of the staked token.
     */
    function claimRewards(address _tokenAddress, uint256 _tokenId) external {
        _claimRewards(_tokenAddress, _tokenId);
    }

    /**
     * @notice Stake ERC-20 tokens
     * @dev Transfers token from the user and updates the amount staked and staking info.
     * @param _tokenAddress The address of the ERC-20 token to stake.
     * @param _value The amount of tokens to stake.
     */
    function stakeERC20(address _tokenAddress, uint256 _value) internal {
        StakingStorage storage s = getStorage();
        StakedTokenInfo storage stake = s.stakedTokens[msg.sender][_tokenAddress][0];

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
    function stakeERC721(address _tokenAddress, uint256 _tokenId) internal {
        StakingStorage storage s = getStorage();
        StakedTokenInfo storage stake = s.stakedTokens[msg.sender][_tokenAddress][_tokenId];

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
    function stakeERC1155(address _tokenAddress, uint256 _tokenId, uint256 _value) internal {
        StakingStorage storage s = getStorage();
        StakedTokenInfo storage stake = s.stakedTokens[msg.sender][_tokenAddress][_tokenId];

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
     * @notice Calculates the rewards for a staked token.
     * @dev Uses base APR, decay rate, and compounding frequency to compute rewards.
     * @dev Rewards are calculated based on the time since last claim.
     * @dev Uses fixed-point arithmetic with 1e18 precision.
     * @param _tokenAddress The address of the staked token.
     * @param _tokenId The ID of the staked token.
     * @return finalReward The calculated reward amount.
     */
    function calculateRewards(address _tokenAddress, uint256 _tokenId) internal view returns (uint256) {
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
     * @notice Claimes rewards for a staked token.
     * @dev Internal function to update staking info after rewards are claimed.
     * @param _tokenAddress The address of the staked token.
     * @param _tokenId The ID of the staked token.
     */
    function _claimRewards(address _tokenAddress, uint256 _tokenId) internal {
        StakingStorage storage s = getStorage();
        StakedTokenInfo storage stake = s.stakedTokens[msg.sender][_tokenAddress][_tokenId];

        uint256 rewards = calculateRewards(_tokenAddress, _tokenId);
        if (rewards == 0) {
            revert StakingNoRewardsToClaim(_tokenAddress, _tokenId);
        }

        bool success = IERC20(s.rewardToken).transfer(msg.sender, rewards);
        if (!success) {
            revert StakingTransferFailed();
        }

        stake.lastClaimedAt = block.timestamp;
        stake.accumulatedRewards += rewards;

        emit RewardsClaimed(msg.sender, _tokenAddress, _tokenId, rewards);
    }

    /**
     * @notice Retrieve supported token types
     * @param _tokenAddress The address of the token.
     * @return true if the token is supported, false otherwise.
     */
    function isTokenSupported(address _tokenAddress) internal view returns (bool) {
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
    function rpow(uint256 _base, uint256 _exp) internal pure returns (uint256 result) {
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
    function rmul(uint256 x, uint256 y) internal pure returns (uint256 z) {
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

    /**
     * @notice Support Interface to satisfy ERC-165 standard.
     * @param interfaceId The interface identifier, as specified in ERC-165.
     * @return True if the contract implements the requested interface.
     */
    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == type(IERC721Receiver).interfaceId || interfaceId == type(IERC1155Receiver).interfaceId;
    }

    /// @notice Handle the receipt of an NFT
    /// @dev The ERC721 smart contract calls this on the recipient after a `safeTransfer`.
    /// @return The selector to confirm token transfer. If any other value is returned or the interface is not implemented by the recipient, the transfer will be reverted.
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data)
        external
        pure
        returns (bytes4)
    {
        return IERC721Receiver.onERC721Received.selector;
    }

    /// @notice Handle the receipt of a single ERC1155 token type
    /// @dev The ERC1155 smart contract calls this on the recipient after a `safeTransferFrom`.
    /// @return The selector to confirm token transfer. If any other value is returned or the interface is not implemented by the recipient, the transfer will be reverted.
    function onERC1155Received(address operator, address from, uint256 id, uint256 value, bytes calldata data)
        external
        pure
        returns (bytes4)
    {
        return IERC1155Receiver.onERC1155Received.selector;
    }
}
