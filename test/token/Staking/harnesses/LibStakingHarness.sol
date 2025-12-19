// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import "../../../../src/token/Staking/StakingMod.sol" as StakingMod;

/**
 * @title LibStakingHarness
 * @notice Test harness that exposes internal functions of LibStaking as external
 * @dev Required for testing since StakingMod functions are internal
 */
contract LibStakingHarness {
    /**
     * @notice Initialize the staking storage for testing
     * @dev Only used for testing purposes
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
        StakingMod.setStakingParameters(
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
     * @notice Exposes StakingMod.addSupportedToken as an external function
     */
    function addSupportedToken(address _tokenAddress, bool _isERC20, bool _isERC721, bool _isERC1155) external {
        StakingMod.addSupportedToken(_tokenAddress, _isERC20, _isERC721, _isERC1155);
    }

    /**
     * @notice Exposes StakingMod._stakeERC20 as an external function
     */
    function stakeERC20(address _tokenAddress, uint256 _value) external {
        StakingMod.stakeERC20(_tokenAddress, _value);
    }

    /**
     * @notice Exposes StakingMod._stakeERC721 as an external function
     */
    function stakeERC721(address _tokenAddress, uint256 _tokenId) external {
        StakingMod.stakeERC721(_tokenAddress, _tokenId);
    }

    /**
     * @notice Exposes StakingMod._stakeERC1155 as an external function
     */
    function stakeERC1155(address _tokenAddress, uint256 _tokenId, uint256 _value) external {
        StakingMod.stakeERC1155(_tokenAddress, _tokenId, _value);
    }

    /**
     * @notice Exposes StakingMod.getStakingParameters as an external function
     */
    function getStakingParameters()
        external
        view
        returns (uint256, uint256, uint256, address, uint256, uint256, uint256)
    {
        return StakingMod.getStakingParameters();
    }

    /**
     * @notice Exposes StakingMod.getStakedTokenInfo as an external function
     */
    function getStakedTokenInfo(address _tokenAddress, uint256 _tokenId)
        external
        view
        returns (uint256, uint256, uint256, uint256)
    {
        return StakingMod.getStakedTokenInfo(_tokenAddress, _tokenId);
    }

    /**
     * @notice Exposes StakingMod.isSupportedToken as an external function
     */
    function isTokenSupported(address _tokenAddress) external view returns (bool) {
        return StakingMod.isTokenSupported(_tokenAddress);
    }
}
