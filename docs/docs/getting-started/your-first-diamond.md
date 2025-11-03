---
sidebar_position: 3
---

# Your First Diamond

In this guide, you'll learn how to create a diamond from scratch and understand every piece of the architecture.

## What is a Diamond?

A **diamond** is a smart contract that follows the **ERC-2535 Diamond Standard**. Think of it as a modular smart contract system where you can:

- **Add, replace, or remove functionality** after deployment
- **Combine multiple facets** (modules) into one address
- **Share storage** across all facets using a unified storage layout
- **Exceed the 24KB contract size limit** by splitting code across facets

### The Diamond Architecture

```
┌─────────────────────────────────────┐
│          Diamond Proxy              │
│  (Single Address, Delegatecalls)    │
└─────────────┬───────────────────────┘
              │
      ┌───────┴────────┬──────────────┐
      │                │              │
┌─────▼─────┐   ┌──────▼──────┐  ┌───▼────┐
│  Facet A  │   │   Facet B   │  │ Facet C│
│  (ERC-20) │   │  (ERC-721)  │  │ (Owner)│
└───────────┘   └─────────────┘  └────────┘
      │                │              │
      └────────────────┴──────────────┘
                     │
         ┌───────────▼────────────┐
         │   Shared Storage      │
         │  (Diamond Storage)    │
         └───────────────────────┘
```

## Step-by-Step Guide

### 1. Understanding the Components

A complete diamond consists of:

1. **Diamond Contract** - The main contract that users interact with
2. **DiamondCutFacet** - Manages adding/removing/replacing facets
3. **Functional Facets** - Your actual business logic (ERC-20, etc.)
4. **Libraries** - Helper functions for custom facets

### 2. Create the Diamond Base

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Diamond} from "compose/Diamond.sol";

/// @title MyDiamond
/// @notice A customizable diamond contract
/// @dev Inherits core diamond functionality from Compose
contract MyDiamond is Diamond {
    /// @notice Creates a new diamond
    /// @param _contractOwner The address that will own this diamond
    /// @param _diamondCutFacet The address of the DiamondCutFacet
    constructor(
        address _contractOwner,
        address _diamondCutFacet
    ) Diamond(_contractOwner, _diamondCutFacet) {
        // The diamond is now ready to receive facets
    }
}
```

### 3. Deploy DiamondCutFacet

The DiamondCutFacet is special—it's the only facet that must be added during construction:

```solidity
import {DiamondCutFacet} from "compose/facets/DiamondCutFacet.sol";

// Deploy it once
DiamondCutFacet diamondCutFacet = new DiamondCutFacet();

// Pass its address to your diamond
MyDiamond diamond = new MyDiamond(
    msg.sender,  // owner
    address(diamondCutFacet)
);
```

### 4. Add Your First Facet

Let's add ERC-20 functionality:

```solidity
import {ERC20Facet} from "compose/facets/ERC20Facet.sol";
import {IDiamondCut} from "compose/interfaces/IDiamondCut.sol";

// 1. Deploy the facet
ERC20Facet erc20Facet = new ERC20Facet();

// 2. Prepare the function selectors
bytes4[] memory selectors = new bytes4[](9);
selectors[0] = ERC20Facet.name.selector;
selectors[1] = ERC20Facet.symbol.selector;
selectors[2] = ERC20Facet.decimals.selector;
selectors[3] = ERC20Facet.totalSupply.selector;
selectors[4] = ERC20Facet.balanceOf.selector;
selectors[5] = ERC20Facet.transfer.selector;
selectors[6] = ERC20Facet.allowance.selector;
selectors[7] = ERC20Facet.approve.selector;
selectors[8] = ERC20Facet.transferFrom.selector;

// 3. Create the facet cut
IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
cut[0] = IDiamondCut.FacetCut({
    facetAddress: address(erc20Facet),
    action: IDiamondCut.FacetCutAction.Add,
    functionSelectors: selectors
});

// 4. Execute the diamond cut
IDiamondCut(address(diamond)).diamondCut(cut, address(0), "");
```

### 5. Initialize Your Token

Create an init facet for one-time setup:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {LibERC20} from "compose/libraries/LibERC20.sol";

contract ERC20InitFacet {
    /// @notice Initialize the ERC-20 token
    /// @dev Can only be called once
    function initERC20(
        string calldata _name,
        string calldata _symbol,
        uint8 _decimals,
        uint256 _initialSupply
    ) external {
        LibERC20.ERC20Storage storage s = LibERC20.getStorage();
        
        // Ensure we haven't initialized yet
        require(bytes(s.name).length == 0, "Already initialized");
        
        // Set token details
        s.name = _name;
        s.symbol = _symbol;
        s.decimals = _decimals;
        
        // Mint initial supply to caller
        if (_initialSupply > 0) {
            s.totalSupply = _initialSupply;
            s.balances[msg.sender] = _initialSupply;
            
            emit Transfer(address(0), msg.sender, _initialSupply);
        }
    }
    
    event Transfer(address indexed from, address indexed to, uint256 value);
}
```

Call it via `diamondCut` with initialization data:

```solidity
// Deploy init facet
ERC20InitFacet initFacet = new ERC20InitFacet();

// Prepare init data
bytes memory initData = abi.encodeWithSelector(
    ERC20InitFacet.initERC20.selector,
    "My Token",
    "MTK",
    18,
    1_000_000 ether
);

// Execute diamond cut with initialization
IDiamondCut(address(diamond)).diamondCut(
    cut,  // empty or with more facets
    address(initFacet),
    initData
);
```

### 6. Interact with Your Diamond

Now you can use your diamond like any ERC-20 token:

```solidity
import {IERC20} from "compose/interfaces/IERC20.sol";

// Cast diamond to ERC-20 interface
IERC20 token = IERC20(address(diamond));

// Use standard ERC-20 functions
uint256 balance = token.balanceOf(msg.sender);
token.transfer(recipient, 100 ether);
token.approve(spender, 1000 ether);
```

## Key Concepts Explained

### Delegatecall Magic

When you call a function on the diamond:
1. Diamond receives the call
2. Diamond looks up which facet implements that function
3. Diamond `delegatecalls` to that facet
4. Facet executes using **diamond's storage**
5. Result is returned to caller

```
User → Diamond.transfer() 
       ↓ (delegatecall)
       ERC20Facet.transfer() 
       ↓ (reads/writes)
       Diamond's Storage
```

### Shared Storage

All facets share the same storage in the diamond. This is why libraries like `LibERC20` are crucial—they ensure everyone accesses storage at the same location:

```solidity
// Both the facet and your custom code access the same storage
LibERC20.ERC20Storage storage s = LibERC20.getStorage();
// Always returns storage at keccak256("compose.erc20")
```

### Function Selectors

Each function has a unique 4-byte signature (selector):

```solidity
bytes4 selector = ERC20Facet.transfer.selector;
// selector = 0xa9059cbb (first 4 bytes of keccak256("transfer(address,uint256)"))
```

The diamond uses these selectors to route calls to the correct facet.

## Complete Example

Here's a complete deployment script:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {MyDiamond} from "../src/MyDiamond.sol";
import {DiamondCutFacet} from "compose/facets/DiamondCutFacet.sol";
import {ERC20Facet} from "compose/facets/ERC20Facet.sol";
import {ERC20InitFacet} from "../src/facets/ERC20InitFacet.sol";
import {IDiamondCut} from "compose/interfaces/IDiamondCut.sol";

contract DeployDiamond is Script {
    function run() external {
        vm.startBroadcast();

        // Step 1: Deploy DiamondCutFacet
        DiamondCutFacet cutFacet = new DiamondCutFacet();
        
        // Step 2: Deploy Diamond
        MyDiamond diamond = new MyDiamond(msg.sender, address(cutFacet));
        
        // Step 3: Deploy ERC20Facet
        ERC20Facet erc20 = new ERC20Facet();
        
        // Step 4: Deploy InitFacet
        ERC20InitFacet initFacet = new ERC20InitFacet();
        
        // Step 5: Prepare facet cuts
        bytes4[] memory selectors = getERC20Selectors();
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(erc20),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: selectors
        });
        
        // Step 6: Prepare init data
        bytes memory initData = abi.encodeWithSelector(
            ERC20InitFacet.initERC20.selector,
            "Compose Token",
            "COMP",
            18,
            1_000_000 ether
        );
        
        // Step 7: Execute diamond cut with initialization
        IDiamondCut(address(diamond)).diamondCut(
            cuts,
            address(initFacet),
            initData
        );
        
        vm.stopBroadcast();
        
        console.log("Diamond deployed at:", address(diamond));
    }
    
    function getERC20Selectors() internal pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](9);
        selectors[0] = ERC20Facet.name.selector;
        selectors[1] = ERC20Facet.symbol.selector;
        selectors[2] = ERC20Facet.decimals.selector;
        selectors[3] = ERC20Facet.totalSupply.selector;
        selectors[4] = ERC20Facet.balanceOf.selector;
        selectors[5] = ERC20Facet.transfer.selector;
        selectors[6] = ERC20Facet.allowance.selector;
        selectors[7] = ERC20Facet.approve.selector;
        selectors[8] = ERC20Facet.transferFrom.selector;
        return selectors;
    }
}
```

## Testing Your Diamond

```solidity
// test/MyDiamond.t.sol
import {Test} from "forge-std/Test.sol";
import {IERC20} from "compose/interfaces/IERC20.sol";

contract MyDiamondTest is Test {
    address diamond;
    IERC20 token;
    
    function setUp() public {
        // Deploy your diamond (using the script above)
        // ...
        
        token = IERC20(diamond);
    }
    
    function testTokenName() public {
        assertEq(token.name(), "Compose Token");
    }
    
    function testTransfer() public {
        address recipient = address(0x123);
        uint256 amount = 100 ether;
        
        token.transfer(recipient, amount);
        assertEq(token.balanceOf(recipient), amount);
    }
}
```

## Next Steps

You now understand how to build a diamond from scratch! Continue learning:

- **[Core Concepts: Facets and Libraries](/)** - Deep dive into the architecture
- **[Available Facets](/)** - Explore what Compose provides
- **[Creating Custom Facets](/)** - Build your own facets
- **[Upgrading Diamonds](/)** - Learn about diamond cuts

:::tip Pro Tip
In production, consider using a multi-sig wallet or DAO for the diamond owner to ensure secure upgrades.
:::

