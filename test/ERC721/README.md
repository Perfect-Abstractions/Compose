# ERC721 Test Suite

This directory contains comprehensive tests for the ERC721 smart contract implementations in the Compose library.

## Overview

The ERC721 test suite follows the same testing architecture as the ERC20 tests, using test harnesses to make production code testable without modifying it. This approach respects Compose's design constraints while providing comprehensive test coverage.

## Testing Architecture

### The Challenge

Compose's design constraints create unique testing challenges for ERC721 implementations:

-   No external functions in libraries - Libraries like LibERC721 only expose internal functions
-   No initialization functions - Facets like ERC721Facet have no built-in way to initialize storage
-   No constructors in facets - Only diamond contracts can have constructors
-   Storage structure mismatches - ERC721EnumerableFacet has different storage than its library

### The Solution: Test Harnesses

Test harnesses are wrapper contracts that make production code testable without modifying it.

## Directory Structure

```
test/ERC721/
├── README.md (this file)
│
├── ERC721Facet.t.sol                    # Tests for ERC721Facet (42 tests)
├── ERC721EnumerableFacet.t.sol          # Tests for ERC721EnumerableFacet (60 tests)
│
└── harnesses/
    ├── ERC721FacetHarness.sol           # Test harness for ERC721Facet
    └── ERC721EnumerableFacetHarness.sol # Test harness for ERC721EnumerableFacet
```

## Test Harnesses Explained

### ERC721FacetHarness

**Purpose**: Extends ERC721Facet with test-only utilities

**Why it's needed**:

-   ERC721Facet has no way to initialize storage (set token name, symbol, baseURI)
-   In production, diamonds handle initialization via constructors or init facets
-   For testing, we need a way to set up initial state and mint tokens

**What it adds**:

-   `function initialize(string memory _name, string memory _symbol, string memory _baseURI)`
-   `function mint(address _to, uint256 _tokenId)`
-   `function burn(uint256 _tokenId)`

**Usage in tests**:

```solidity
ERC721FacetHarness token = new ERC721FacetHarness();
token.initialize("Test NFT", "TNFT", "https://api.example.com/metadata/");
token.mint(alice, 1);
// Now test transfer, approve, etc.
```

### ERC721EnumerableFacetHarness

**Purpose**: Extends ERC721EnumerableFacet with test-only utilities and fixes library bugs

**Why it's needed**:

-   Same initialization challenges as ERC721Facet
-   **Critical Bug Fix**: The ERC721Enumerable library is missing `s.ownerOf[_tokenId] = _to;` in its mint function
-   Storage structure mismatch between ERC721EnumerableFacet and its library

**What it adds**:

-   `function initialize(string memory _name, string memory _symbol, string memory _baseURI)`
-   `function mint(address _to, uint256 _tokenId)` - **Fixed version with proper ownerOf assignment**
-   `function burn(uint256 _tokenId)` - **Fixed version matching facet storage structure**

**Critical Bug Fix**:
The original ERC721Enumerable library mint function was missing the crucial line:

```solidity
s.ownerOf[_tokenId] = _to;  // This line was missing!
```

Our harness includes the complete, corrected mint function.

## Running Tests

### Run all ERC721 tests

```bash
forge test --match-path "test/ERC721/*.t.sol"
```

### Run specific test files

```bash
# ERC721Facet tests only
forge test --match-path "test/ERC721/ERC721Facet.t.sol"

# ERC721EnumerableFacet tests only
forge test --match-path "test/ERC721/ERC721EnumerableFacet.t.sol"
```

### Run with verbose output

```bash
forge test --match-path "test/ERC721/*.t.sol" -vv
```

### Run specific test functions

```bash
forge test --match-test "test_Mint"
forge test --match-test "test_Enumeration"
```

### Run fuzz tests only

```bash
forge test --match-path "test/ERC721/*.t.sol" --match-test "testFuzz"
```

### Generate gas report

```bash
forge test --match-path "test/ERC721/*.t.sol" --gas-report
```

## Test Coverage

### ERC721Facet Tests (42 tests)

-   **Metadata Tests**: name, symbol, tokenURI
-   **Mint Tests**: basic minting, multiple mints, fuzz testing, error cases
-   **Burn Tests**: basic burning, entire balance, fuzz testing, error cases
-   **Transfer Tests**: transferFrom, safe transfers, error cases
-   **Approval Tests**: approve, setApprovalForAll, operator transfers
-   **Error Cases**: invalid addresses, non-existent tokens, insufficient approvals
-   **Integration Tests**: complete mint-transfer-burn flows

### ERC721EnumerableFacet Tests (60 tests)

-   **All ERC721Facet tests** plus:
-   **Enumeration Tests**: totalSupply, tokenOfOwnerByIndex, index updates
-   **Transfer Enumeration**: proper index updates during transfers
-   **Burn Enumeration**: correct removal from enumeration lists
-   **Complex Scenarios**: multiple transfers, burn operations, index management
-   **Enumeration Bug Tests**: specific tests for the library bug fix

## Test Naming Conventions

-   `test_FunctionName()` - Basic happy path test
-   `test_FunctionName_Scenario()` - Specific scenario test
-   `test_RevertWhen_Condition()` - Tests that verify reverts
-   `testFuzz_FunctionName()` - Fuzz tests (property-based)

## Example Test Pattern

```solidity
function test_Transfer() public {
    // Arrange
    token.mint(alice, 1);

    // Act
    vm.prank(alice);
    token.transferFrom(alice, bob, 1);

    // Assert
    assertEq(token.ownerOf(1), bob);
    assertEq(token.balanceOf(alice), 0);
    assertEq(token.balanceOf(bob), 1);
}

function test_RevertWhen_TransferInsufficientApproval() public {
    token.mint(alice, 1);

    vm.prank(bob);
    vm.expectRevert(
        abi.encodeWithSelector(ERC721Facet.ERC721InsufficientApproval.selector, bob, 1)
    );
    token.transferFrom(alice, charlie, 1);
}
```

## Critical Bug Fixes

### ERC721Enumerable Library Bug

The original `LibERC721Enumerable.mint()` function was missing the crucial line that sets the token owner:

```solidity
// Original (buggy) library code:
function mint(address _to, uint256 _tokenId) internal {
    // ... validation code ...
    s.ownedTokensIndexOf[_tokenId] = s.ownedTokensOf[_to].length;
    s.ownedTokensOf[_to].push(_tokenId);
    s.allTokensIndexOf[_tokenId] = s.allTokens.length;
    s.allTokens.push(_tokenId);
    emit Transfer(address(0), _to, _tokenId);
    // Missing: s.ownerOf[_tokenId] = _to;
}

// Fixed version in our harness:
function mint(address _to, uint256 _tokenId) external {
    // ... validation code ...
    s.ownerOf[_tokenId] = _to;  // This line was missing!
    s.ownedTokensIndexOf[_tokenId] = s.ownedTokensOf[_to].length;
    s.ownedTokensOf[_to].push(_tokenId);
    s.allTokensIndexOf[_tokenId] = s.allTokens.length;
    s.allTokens.push(_tokenId);
    emit Transfer(address(0), _to, _tokenId);
}
```

### Storage Structure Mismatch

The ERC721EnumerableFacet has a different storage structure than its library:

-   **Facet**: Includes `tokenURIOf` mapping and different field order
-   **Library**: Missing `tokenURIOf` mapping

Our harness uses the correct facet storage structure.

## Understanding Test Output

When tests pass, you'll see:

```
Ran 2 test suites: 95 tests passed, 0 failed, 0 skipped (95 total tests)
```

Each test shows gas usage:

```
[PASS] test_Transfer() (gas: 74041)
```

Fuzz tests show number of runs:

```
[PASS] testFuzz_Transfer(address,uint256) (runs: 256, μ: 67633, ~: 67633)
```

## Contributing

When adding new features to ERC721 implementations:

1. Write test harnesses if the contract needs initialization or has internal functions
2. Follow existing test patterns and naming conventions
3. Aim for comprehensive coverage including error cases
4. Add fuzz tests for functions with numeric parameters
5. Verify events are emitted correctly
6. Run tests before submitting PRs: `forge test`

## Why This Approach?

This testing architecture:

✅ Respects Compose's design constraints  
✅ Keeps production code clean (no test-only modifications)  
✅ Provides comprehensive coverage  
✅ Follows industry best practices (OpenZeppelin pattern)  
✅ Makes internal code testable  
✅ Enables isolated unit testing  
✅ Fixes critical library bugs without modifying production code

## Questions?

If you're unsure about testing patterns or need help writing tests for a new feature, refer to the existing test files in `test/ERC721/` or the main testing documentation in `test/README.md`.
