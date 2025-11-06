// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {LibDiamondShard} from "./LibDiamondShard.sol";

/// @title InitShardedLoupe
/// @notice Initialization contract to enable sharded loupe on an existing diamond
contract InitShardedLoupe {
    /// @notice Enable sharded loupe and build initial snapshot
    function init() external {
        LibDiamondShard.enableShardedLoupe();
    }
}
