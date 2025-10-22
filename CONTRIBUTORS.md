# Contributor Guidelines

## No logic inheritance

No logic may be inherited from another contract.
All code MUST be self-contained within the contract itself.
This requirements supersedes all other style guide requirements.
Interface inheritance is under consideration.
Interface inheritance is being considered to ensure compile time implementation enforcement and ensure related events and errors are defined in a portable manner. 
Currently, you may submit code that inherits relevant interfaces, but this is subject to change.

## All Code MUST follow the Solidity Style Guide

The [Solidity Style Guide](https://docs.soliditylang.org/en/latest/style-guide.html) provides a comprehensive set of conventions for writing clean and maintainable Solidity code.
Adhering to these guidelines ensures consistency across the codebase and improves readability for all contributors.
All code contributions must comply with the standards outlined in the Solidity Style Guide.
Running 'forge lint' before submitting your pull request should ensure your code meets formatting and style requirements.

## A code MUST include NatSpec Comments

The [Solidity NatSpec documentation format](https://docs.soliditylang.org/en/latest/natspec-format.html) is essential for providing clear and structured documentation for smart contracts.
All code contribution must include NatSpec comments to describe the purpose, parameters, return values, and any other relevant information about functions and contracts.
The `@inheritdoc` tag is FORBIDDEN in all code contributions.
This means that all NatSpec comments must be explicitly written out in each contract and function, rather than relying on inherited documentation.
Changes to existing code MUST ADD `@author` tags below any existing `@author` tags to indicate the new contributor.
If a contributor does not wish to declare their authorship, they MUST add an `@author` tag with the value `Anonymous`.

# Minimize path depth and favor existing groups

When adding new contracts, favor placing subdirectories inside existing relevant groups rather than creating new top-level directories.
Implementations of existing ERCs MUST use `ERC<number>` as a prefix of directory containing their code or groups of subdirectories.

*EXAMPLE*

*YES*

```
src/
---- erc20/
-------- ERC20Facet.sol
```

*NO*

```
src/
---- tokens/
-------- ERC20/
------------ ERC20Facet.sol
```

## Implementation Scopes

All state changes MUST be implemented in libraries.
Facets MUST ONLY expose wrapped library functions.

## Component Naming Conventions

Contracts intended for reuse as facets configured into deployed diamond proxies MUST use the `Facet` suffix.

Diamond Storage libraries MUST use the `Repo` suffix.
Repo libraries MUST define a STORAGE_POSITION constant of type `bytes32`.
STORAGE_POSITION constant MUST be defined as the keccak256 hash of a ABI encoded string of the `src/` dot separated relative path prefixed by `compose`.

*YES*

```solidity
bytes32 constant STORAGE_POSITION = keccak256(abi.encode("compose.erc20"));
```

*NO*

```solidity
bytes32 constant STORAGE_POSITION = keccak256(abi.encode("My ERC20 Repo"));
```

Diamond Storage structs MUST use the `Storage` suffix.
Diamond Storage structs MUST be embedded in a library with the `Repo` suffix.

Diamond Storage libraries MUST expose a `getStorage()` function that returns a storage pointer to the diamond storage struct of that library.
The `getStorage()` function MUST be defined as an internal pure function.

Diamond Storage libraries MUST implement atomic state change logic relevant to ERC or intended business logic.
Diamond Storage libraries MAY include helper functions that do not modify state to support atomic state change logic.

*YES*

```solidity
    function transfer(address _to, uint256 _value) internal {
        ERC20Storage storage s = getStorage();
        if (_to == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        uint256 fromBalance = s.balanceOf[msg.sender];
        if (fromBalance < _value) {
            revert ERC20InsufficientBalance(msg.sender, fromBalance, _value);
        }
        unchecked {
            s.balanceOf[msg.sender] = fromBalance - _value;
        }
        s.balanceOf[_to] += _value;
        emit Transfer(msg.sender, _to, _value);
    }
```

*NO*

```solidity
    function incrementBalance(address _to, uint256 _value) internal {
        ERC20Storage storage s = getStorage();
        s.balanceOf[_to] += _value;
    }

    function decrementBalance(address _from, uint256 _value) internal {
        ERC20Storage storage s = getStorage();
        uint256 fromBalance = s.balanceOf[_from];
        if (fromBalance < _value) {
            revert ERC20InsufficientBalance(_from, fromBalance, _value);
        }
        unchecked {
            s.balanceOf[_from] = fromBalance - _value;
        }
    }
```

Libraries consisting of pure and other non-state changing functions MUST use the `Utils` suffix.
`Utils` libraries MUST NOT define or modify state.

*YES*

```solidity
library ERC20Utils {
    function calculateTransferFee(uint256 _value, uint256 _feeBasisPoints) internal pure returns (uint256) {
        return (_value * _feeBasisPoints) / 10000;
    }
}
```

*NO*

```solidity
library ERC20Math {
    function incrementBalance(mapping(address => uint256) storage _balances, address _to, uint256 _value) internal {
        _balances[_to] += _value;
    }
}
```

Libraries that make external calls MUST be named descriptively to indicate their purpose.
Libraries that make external calls MUST use the `Caller` suffix.

*YES*

```solidity
library ERC20PermitCaller {
    function callPermit(address _token, address _owner, address _spender, uint256 _value, uint256 _deadline, uint8 _v, bytes32 _r, bytes32 _s) internal {
        IERC20Permit(_token).permit(_owner, _spender, _value, _deadline, _v, _r, _s);
    }
}
```

*NO*

```solidity
library ERC20External {
    function approveExternal(address _token, address _spender, uint256 _value) internal {
        IERC20(_token).approve(_spender, _value);
    }
}
```