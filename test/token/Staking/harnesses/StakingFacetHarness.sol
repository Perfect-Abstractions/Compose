// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {StakingFacet} from "../../../../src/token/Staking/StakingFacet.sol";

/**
 * @title StakingFacetHarness
 * @notice Test harness for StakingFacet
 * @dev Adds helper functions to set up staking state for testing
 */
contract StakingFacetHarness is StakingFacet {
    /**
     * @notice Initialize the staking storage for testing
     * @dev Only used for testing purposes - production diamonds should initialize in constructor
     * @dev Set staking parameters
     * @param _baseAPR The base annual percentage rate for staking rewards
     * @param _rewardDecayRate The decay rate for staking rewards
     * @param _compoundFrequency The frequency at which rewards are compounded
     * @param _rewardToken The address of the reward ERC-20 token
     * @param _cooldownPeriod The cooldown period for unstaking
     * @param _minStakeAmount The minimum amount that can be staked
     * @param _maxStakeAmount The maximum amount that can be staked
     */
    function initialize(
        uint256 _baseAPR,
        uint256 _rewardDecayRate,
        uint256 _compoundFrequency,
        address _rewardToken,
        uint256 _cooldownPeriod,
        uint256 _minStakeAmount,
        uint256 _maxStakeAmount
    ) external {
        StakingStorage storage s = getStorage();
        s.baseAPR = _baseAPR;
        s.rewardDecayRate = _rewardDecayRate;
        s.compoundFrequency = _compoundFrequency;
        s.rewardToken = _rewardToken;
        s.cooldownPeriod = _cooldownPeriod;
        s.minStakeAmount = _minStakeAmount;
        s.maxStakeAmount = _maxStakeAmount;
    }

    function stakeERC20Token(address _tokenAddress, uint256 _value) external {
        stakeERC20(_tokenAddress, _value);
    }

    function stakeERC721Token(address _tokenAddress, uint256 _tokenId) external {
        stakeERC721(_tokenAddress, _tokenId);
    }

    function stakeERC1155Token(address _tokenAddress, uint256 _tokenId, uint256 _value) external {
        stakeERC1155(_tokenAddress, _tokenId, _value);
    }

    function calculateRewardsForToken(address _tokenAddress, uint256 _tokenId) external view returns (uint256) {
        return calculateRewards(_tokenAddress, _tokenId);
    }

    function claimRewardsForToken(address _tokenAddress, uint256 _tokenId) external {
        _claimRewards(_tokenAddress, _tokenId);
    }

    function tokenSupported(address _tokenAddress) external view {
        isTokenSupported(_tokenAddress);
    }

    function testSetStakeInfo(
        address user,
        address token,
        uint256 tokenId,
        uint256 amount,
        uint256 stakedAt,
        uint256 lastClaimedAt
    ) external {
        StakingStorage storage s = getStorage();
        StakedTokenInfo storage stake = s.stakedTokens[user][token][tokenId];

        stake.amount = amount;
        stake.stakedAt = stakedAt;
        stake.lastClaimedAt = lastClaimedAt;
    }

    function getStakeInfo(address user, address token, uint256 tokenId) external view returns (StakedTokenInfo memory) {
        StakingStorage storage s = getStorage();
        return s.stakedTokens[user][token][tokenId];
    }
}
