---
sidebar_position: 2
---

# Quick Start

Let's build your first diamond using Compose facets in under 5 minutes! 🚀

## What We'll Build

We'll create a simple ERC-20 token diamond that demonstrates:
- How to use Compose facets
- How shared storage works
- How to deploy and interact with your diamond

## Step 1: Set Up Your Project

```bash
# Create a new Foundry project
forge init my-diamond
cd my-diamond

# Install Compose (when available as dependency)
# For now, clone the repository
git clone https://github.com/Perfect-Abstractions/Compose.git lib/Compose
```

## Step 2: Create Your Diamond Contract

Create `src/MyTokenDiamond.sol`:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Diamond} from "compose/Diamond.sol";

/// @title MyTokenDiamond
/// @notice A diamond that implements ERC-20 functionality
contract MyTokenDiamond is Diamond {
    constructor(
        address owner,
        address diamondCutFacet
    ) Diamond(owner, diamondCutFacet) {
        // Diamond is initialized and ready to receive facets
    }
}
```

## Step 3: Deploy Script

Create `script/DeployMyDiamond.s.sol`:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {MyTokenDiamond} from "../src/MyTokenDiamond.sol";
import {DiamondCutFacet} from "compose/facets/DiamondCutFacet.sol";
import {ERC20Facet} from "compose/facets/ERC20Facet.sol";
import {IDiamondCut} from "compose/interfaces/IDiamondCut.sol";

contract DeployMyDiamond is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy DiamondCutFacet
        DiamondCutFacet diamondCutFacet = new DiamondCutFacet();

        // 2. Deploy Diamond
        MyTokenDiamond diamond = new MyTokenDiamond(
            deployer,
            address(diamondCutFacet)
        );

        // 3. Deploy ERC20Facet
        ERC20Facet erc20Facet = new ERC20Facet();

        // 4. Add ERC20Facet to diamond
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        
        bytes4[] memory erc20Selectors = new bytes4[](9);
        erc20Selectors[0] = ERC20Facet.name.selector;
        erc20Selectors[1] = ERC20Facet.symbol.selector;
        erc20Selectors[2] = ERC20Facet.decimals.selector;
        erc20Selectors[3] = ERC20Facet.totalSupply.selector;
        erc20Selectors[4] = ERC20Facet.balanceOf.selector;
        erc20Selectors[5] = ERC20Facet.transfer.selector;
        erc20Selectors[6] = ERC20Facet.allowance.selector;
        erc20Selectors[7] = ERC20Facet.approve.selector;
        erc20Selectors[8] = ERC20Facet.transferFrom.selector;

        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(erc20Facet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: erc20Selectors
        });

        IDiamondCut(address(diamond)).diamondCut(cuts, address(0), "");

        vm.stopBroadcast();

        console.log("Diamond deployed at:", address(diamond));
        console.log("ERC20Facet deployed at:", address(erc20Facet));
    }
}
```

## Step 4: Create Initialization Facet

For initializing your token with name, symbol, and initial supply:

```solidity
// src/facets/TokenInitFacet.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {LibERC20} from "compose/libraries/LibERC20.sol";

contract TokenInitFacet {
    function init(
        string memory name,
        string memory symbol,
        uint8 decimals,
        uint256 initialSupply,
        address recipient
    ) external {
        LibERC20.ERC20Storage storage s = LibERC20.getStorage();
        
        require(bytes(s.name).length == 0, "Already initialized");
        
        s.name = name;
        s.symbol = symbol;
        s.decimals = decimals;
        
        if (initialSupply > 0) {
            s.totalSupply = initialSupply;
            s.balances[recipient] = initialSupply;
        }
    }
}
```

## Step 5: Test Your Diamond

Create `test/MyTokenDiamond.t.sol`:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MyTokenDiamond} from "../src/MyTokenDiamond.sol";
import {ERC20Facet} from "compose/facets/ERC20Facet.sol";
import {IERC20} from "compose/interfaces/IERC20.sol";

contract MyTokenDiamondTest is Test {
    MyTokenDiamond diamond;
    IERC20 token;
    
    address owner = address(1);
    address user1 = address(2);
    address user2 = address(3);

    function setUp() public {
        // Deploy and configure diamond
        // (Diamond cut logic here - see deploy script)
        
        // Cast diamond to IERC20 interface
        token = IERC20(address(diamond));
    }

    function test_Transfer() public {
        vm.prank(owner);
        token.transfer(user1, 100 ether);
        
        assertEq(token.balanceOf(user1), 100 ether);
    }

    function test_Approve() public {
        vm.prank(user1);
        token.approve(user2, 50 ether);
        
        assertEq(token.allowance(user1, user2), 50 ether);
    }

    function test_TransferFrom() public {
        // Setup: owner has tokens, user1 is approved
        vm.prank(owner);
        token.approve(user1, 100 ether);
        
        // Act: user1 transfers from owner to user2
        vm.prank(user1);
        token.transferFrom(owner, user2, 50 ether);
        
        // Assert
        assertEq(token.balanceOf(user2), 50 ether);
    }
}
```

## Step 6: Run and Deploy

```bash
# Run tests
forge test

# Deploy to local network
anvil  # In another terminal

# Deploy
forge script script/DeployMyDiamond.s.sol:DeployMyDiamond --rpc-url http://localhost:8545 --broadcast
```

## Understanding What Happened

Let's break down what you just built:

1. **Diamond Base**: Your `MyTokenDiamond` inherits from `Diamond`, which provides the core diamond functionality
2. **Facet Integration**: You added `ERC20Facet`, a complete ERC-20 implementation
3. **Shared Storage**: The facet and your initialization logic both use `LibERC20` to access the same storage
4. **Upgradeable**: You can add more facets anytime using `diamondCut()`

### The Power of Composition

Your diamond now has:
- ✅ Full ERC-20 functionality
- ✅ Upgradeability via diamond cuts
- ✅ Ability to add more facets (ERC-721, access control, etc.)
- ✅ Separation of concerns (each facet handles one responsibility)

## Next Steps

Congratulations! 🎉 You've created your first Compose diamond. Now:

- **[Learn Core Concepts](/)** - Understand the architecture deeply
- **[Explore Available Facets](/)** - See what else you can add
- **[Custom Facets](/)** - Build your own facets
- **[Best Practices](/)** - Write production-ready code

## Common Issues

### "Cannot find Diamond.sol"

Make sure Compose is properly installed in `lib/Compose/` and your remappings are configured.

### "DiamondCut failed"

Check that:
- Function selectors are correct
- Facet address is valid
- You have the right permissions

### Need Help?

- 💬 **[Join Discord](https://discord.gg/compose)** - Get immediate help
- 📚 **[Read FAQ](/)** - Common questions answered
- 🐛 **[Report Issues](https://github.com/Perfect-Abstractions/Compose/issues)** - Found a bug?

