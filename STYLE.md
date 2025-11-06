# Compose Coding Style Guide

This style guide documents the coding conventions required for all Compose code. All contributors must follow these rules to ensure consistency and readability.


## 1. No Imports in Facets
Facets in Compose are self-contained, stand-alone smart contracts. Keep the code in the facet and make it as readable as possible.

Importing other files into Compose facets **is not allowed**.
- Example of what not to do:
  ```solidity
  // This is not allowed in Compose' facets or libraries
  import {LibOwner} from "../../../src/access/Owner/LibOwner.sol";
  ```

## 2. Facets And Libraries Are Read From The Top Down
Put your code in a facet or library in a way that it can be read from the top of the file and down to the bottom of the file, without having to jump to any other place in the file.

This means that everything must be defined before it used. This makes it easier to read a facet or library because the reader doesn't have to jump around the file to see what things are. In addition, it makes the code base consistent in how it is written and read.

## 3. No Inheritance

Facets may not inherit other contracts or interfaces.

- Example of what not to do:
  ```solidity
  // This is not allowed in Compose' facets or libraries
  contract ERC721Facet is IERCFacet {
  ```

## 4. Naming Conventions
- **Parameter Names:** All parameters for events, errors, and functions must be preceded with an underscore (`_`).
  - Example:
    ```solidity
    event Transfer(address indexed _from, address indexed _to, uint256 indexed _tokenId);
    error ERC20InvalidSender(address _sender);
    function transfer(address _to, uint256 _amount) external {}
    ```
- **Camel Case:** Use camelCase for variable, function, contract, and library names, except for standard uppercase abbreviations (e.g., ERC).
  - Example: `totalSupply`, `LibERC20`, `ERC721Facet`

## 5. Control Structures
- **Brackets Required:** One-line `if` statements without code block brackets `{}` are not allowed. Always use a newline and brackets.
  - Example:
    ```solidity
    // Bad
    if (x > 0) return;
    // Good
    if (x > 0) {
        return;
    }
    ```

## 6. Internal Functions
- **Facets:** Internal function names in facets should be prefixed with `internal` if they otherwise have the same name as an external function in the same facet. Usually, there should be few or no internal functions in facets; repeat code if it improves readability.
- **Libraries:** All functions in libraries use the `internal` visibility specifier. 

## 7. Value Resetting
- Use `delete` to set a value to zero.
  - Example:
    ```solidity
    delete balances[_owner];
    ```

## 8. Avoid Assembly
 - Avoid using assembly if you can. If you can't and you access memory, do it [safely](https://docs.soliditylang.org/en/latest/assembly.html#memory-safety), and use `assembly ("memory-safe")`.
   `"memory safe"` tells the Solidity compiler that memory is being used safely so it should not disable optimizations.
   - Example:
     ```solidity
     assembly ("memory-safe") {
         revert(add(reason, 0x20), mload(reason))
     }
     ```

## 9. Formatting
- Format code using the default settings of `forge fmt`. Run `forge fmt` before submitting code.

## 10. References and Examples
- For more examples, see:
  - [`src/token/ERC721/ERC721/ERC721Facet.sol`](src/token/ERC721/ERC721/ERC721Facet.sol)
  - [`src/token/ERC721/ERC721/LibERC721.sol`](src/token/ERC721/ERC721/LibERC721.sol)

## 11. Additional Rules
- More rules may be derived from the above example files. When in doubt, follow the patterns established in those files.

---

Note: All these rules do not apply to *tests*.

**All contributors must follow this style guide.**
