# Compose Test Suite

This directory contains comprehensive tests for the Compose smart contract library.

## Overview

Compose follows strict design principles that ban certain Solidity features (inheritance, modifiers, public/private storage, external library functions, etc.). These constraints require specialized testing patterns to ensure code quality without violating the project's architectural rules.

## Testing Architecture

### The Challenge

Compose's design constraints create unique testing challenges:

1. **No external functions in libraries** - Libraries like `LibERC20` only expose `internal` functions, which cannot be called directly from tests
2. **No initialization functions** - Facets like `ERC20Facet` have no built-in way to initialize storage (name, symbol, decimals)
3. **No constructors in facets** - Only diamond contracts can have constructors

### The Solution: Test Harnesses

Test harnesses are wrapper contracts that make production code testable without modifying it. This is a standard pattern used by OpenZeppelin and other production-grade smart contract projects.

## Directory Structure

```
test/
├── README.md (this file)
│
├── ERC20/
│   ├── ERC20Facet.t.sol         # Tests for ERC20Facet (44 tests)
│   ├── LibERC20.t.sol            # Tests for LibERC20 library (34 tests)
│   │
│   └── harnesses/
│       ├── ERC20FacetHarness.sol # Test harness for ERC20Facet
│       └── LibERC20Harness.sol   # Test harness for LibERC20
```

## Test Harnesses Explained

### ERC20FacetHarness

**Purpose:** Extends `ERC20Facet` with test-only utilities

**Why it's needed:**

- `ERC20Facet` has no way to initialize storage (set token name, symbol, decimals)
- In production, diamonds handle initialization via constructors or init facets
- For testing, we need a way to set up initial state

**What it adds:**

```solidity
function initialize(string memory _name, string memory _symbol, uint8 _decimals)
function mint(address _to, uint256 _value)
```

**Usage in tests:**

```solidity
ERC20FacetHarness token = new ERC20FacetHarness();
token.initialize("Test Token", "TEST", 18);
token.mint(alice, 1000e18);
// Now test transfer, approve, etc.
```

### LibERC20Harness

**Purpose:** Exposes `LibERC20`'s internal functions as external for testing

**Why it's needed:**

- `LibERC20` only has `internal` functions (per Compose's rules)
- Internal functions cannot be called from external test contracts
- We need a way to test library functionality in isolation

**What it does:**

```solidity
// Wraps each internal library function:
function mint(address _account, uint256 _value) external {
    LibERC20.mint(_account, _value);  // Calls internal function
}
```

**Usage in tests:**

```solidity
LibERC20Harness harness = new LibERC20Harness();
harness.mint(alice, 1000e18);
// Test library behavior
```

## Running Tests

### Run all tests

```bash
forge test
```

### Run ERC20 tests only

```bash
forge test --match-path "test/ERC20/*.t.sol"
```

### Run with verbose output

```bash
forge test --match-path "test/ERC20/*.t.sol" -vv
```

### Run specific test file

```bash
forge test --match-path "test/ERC20/ERC20Facet.t.sol"
```

### Run specific test function

```bash
forge test --match-test "test_Transfer"
```

### Generate gas report

```bash
forge test --gas-report
```

## Writing New Tests

### For New Facets

1. Create a test harness if needed:

   ```solidity
   contract MyFacetHarness is MyFacet {
       function initialize(...) external { /* setup storage */ }
       function testHelper(...) external { /* test utilities */ }
   }
   ```

2. Create test file:

   ```solidity
   import {Test} from "forge-std/Test.sol";
   import {MyFacet} from "../../src/MyFacet.sol";
   import {MyFacetHarness} from "./harnesses/MyFacetHarness.sol";

   contract MyFacetTest is Test {
       MyFacetHarness public facet;

       function setUp() public {
           facet = new MyFacetHarness();
           facet.initialize(...);
       }

       function test_Functionality() public { /* ... */ }
   }
   ```

### For New Libraries

1. Create a harness to expose internal functions:

   ```solidity
   contract MyLibHarness {
       function myInternalFunction(...) external {
           MyLib.myInternalFunction(...);
       }

       // Add view functions to read storage
       function getStorageValue() external view returns (...) {
           return MyLib.getStorage().value;
       }
   }
   ```

2. Create test file following the same pattern as `LibERC20.t.sol`

## Testing Best Practices

1. **Test behavior, not implementation** - Focus on what the contract does, not how
2. **Use descriptive test names** - Follow the pattern `test_FunctionName_Scenario`
3. **Test error conditions** - Use `test_RevertWhen_Condition` naming
4. **Use fuzz testing** - Prefix with `testFuzz_` for property-based tests
5. **Test events** - Use `vm.expectEmit()` to verify event emission
6. **Arrange-Act-Assert** - Structure tests clearly with setup, action, and verification
7. **Keep harnesses minimal** - Only add what's necessary for testing

## Test Naming Conventions

- `test_FunctionName()` - Basic happy path test
- `test_FunctionName_Scenario()` - Specific scenario test
- `test_RevertWhen_Condition()` - Tests that verify reverts
- `testFuzz_FunctionName()` - Fuzz tests (property-based)

## Example Test Pattern

```solidity
function test_Transfer() public {
    // Arrange
    uint256 amount = 100e18;

    // Act
    vm.prank(alice);
    token.transfer(bob, amount);

    // Assert
    assertEq(token.balanceOf(bob), amount);
}

function test_RevertWhen_TransferInsufficientBalance() public {
    vm.prank(alice);
    vm.expectRevert(
        abi.encodeWithSelector(
            ERC20Facet.ERC20InsufficientBalance.selector,
            alice,
            balance,
            amount
        )
    );
    token.transfer(bob, tooMuchAmount);
}
```

## Understanding Test Output

When tests pass, you'll see:

```
Ran 2 test suites: 78 tests passed, 0 failed, 0 skipped (78 total tests)
```

Each test shows gas usage:

```
[PASS] test_Transfer() (gas: 46819)
```

Fuzz tests show number of runs:

```
[PASS] testFuzz_Transfer(address,uint256) (runs: 256, μ: 42444, ~: 43179)
```

## Contributing

When adding new features to Compose:

1. Write test harnesses if the contract needs initialization or has internal functions
2. Follow existing test patterns and naming conventions
3. Aim for comprehensive coverage including error cases
4. Add fuzz tests for functions with numeric parameters
5. Verify events are emitted correctly
6. Run tests before submitting PRs: `forge test`

## Why This Approach?

This testing architecture:

- ✅ Respects Compose's design constraints
- ✅ Keeps production code clean (no test-only modifications)
- ✅ Provides comprehensive coverage
- ✅ Follows industry best practices (OpenZeppelin pattern)
- ✅ Makes internal code testable
- ✅ Enables isolated unit testing

## Questions?

If you're unsure about testing patterns or need help writing tests for a new feature, refer to the existing test files in `test/ERC20/` as examples, or ask in the Discord community.
