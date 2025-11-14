# Contributing to Compose

Thank you for your interest in contributing to Compose! This is really appreciated and we are glad you are here.

This guide will help you get started with contributing to our smart contract library.

Please take the time to read this guide and explore the codebase to get a sense of the project and how it works.

## Project Status

**⚠️ IMPORTANT**: Compose is at a very early stage and is currently only available to contributors for building the library. It is **NOT production ready**.

## Code Standards

### Coding Style Guide
All code must follow the Compose coding style guide. See [STYLE.md](STYLE.md) for required conventions, rules, and examples.



### Design Principles

The design and implementation of Compose is based on the following design principles.

#### 1. Understanding:
   This is the top design and guiding principle of this project. We help our users *understand* the things they want to know so they can *confidently* achieve what they are trying to do. This is why we must have very good documentation, and why we write easy to read and understand code. Understanding leads to solutions, creates confidence, kills bugs and gets things done. Understanding is everything. So we nurture it and create it.

#### 2. The code is written to be read:
   The code in this library is written to be read and understood by others easily. We want our users to understand our library and be confident with it. We help them do that with code that is easy to read and understand.

   We hope thousands of smart contract systems use our smart contracts. We say in advance to thousands of people in the future, over tens or hundreds of years, who are reading the verified source code of deployed smart contract systems that use our library, **YOU'RE WELCOME**, for making it easy to read and understand.

#### 3. Repeat yourself:
   The DRY principle — *Don't Repeat Yourself* — is a well-known rule in software development. We **intentionally** break that rule.

   In traditional software, DRY reduces duplication and makes it easier to update multiple parts of a program by changing one section of code. But deployed smart contracts *don't change*. DRY can actually reduce clarity. Every internal function adds another indirection that developers must trace through, and those functions sometimes introduce extra logic for different cases. Repetition can make smart contracts easier to read and reason about.

   That said, DRY still has its place. When a large block of code performs a complete, self-contained action and is used identically in multiple locations, moving it into an internal function can improve readability. For example, Compose's ERC-721 implementation uses an `internalTransferFrom` function to eliminate duplication while keeping the code easy to read and understand. 
   
   Another example is a block of complicated code that performs a specific function that is not part of the main logic of what is being implemented can be put in a library function. The `toString(uint256)` function in the LibUtil library is such a function.

   **Guideline:** Repeat yourself when it makes your code easier to read and understand. Use DRY sparingly and only to make code more readable.

#### 4. Compose diamonds:
   A diamond contract is a smart contract that gets its functionality from other contracts called facets. You can add, replace, or remove functionality from these facets, which lets the diamond contract change or grow without deploying a completely new contract. This design makes it easier to build smart contracts that are modular (made of separate parts) and composable (able to work together in flexible ways). A diamond contract can be deployed and then incrementally developed by adding/replacing/removing functionality over time. Diamond contracts can be upgradeable or immutable. [ERC-2535 Diamonds](https://eips.ethereum.org/EIPS/eip-2535) is the standard that defines how diamond contracts work.
   
   Compose is specifically designed to help users develop and deploy [diamond contracts](https://eips.ethereum.org/EIPS/eip-2535). A major part of this project is creating an onchain diamond factory that makes it easy to deploy diamonds that use facets provided by this library and elsewhere.

   Much of Compose consists of facets and Solidity libraries that are used by users to create diamond contracts.

#### 5. Onchain composability:
   We design facets for maximum onchain reusability and composability.

   We plan to deploy the facets written in this library to many blockchains. There's no reason to take our Solidity source code, as is, and deploy it yourself to a blockchain if it is already deployed there. Just use the facets that are already deployed. We will maintain lists of blockchain addresses for facets that are deployed.

   For example if you want a diamond contract with standard ERC721 NFT functionality, then deploy a diamond contract using this library and add the ERC721 functionality from the existing, already deployed ERC721 facet. You do not need to deploy an ERC721 facet from this library if it has already been deployed to the blockchain you are using.

   Users also have the option of taking our facet source code and modifying it for their needs and deploying what they wish.

#### 6. Favor onchain composition over inheritance:
   > Favoring onchain composition over inheritance means designing blockchain-based systems by building them from smaller, independent components that are combined, rather than inheriting functionality from a large, parent class. This approach creates more flexible, loosely coupled, and maintainable smart contracts, as components can be easily swapped or reused without the rigid dependencies that inheritance introduces. It is a software design principle that emphasizes a "has-a" relationship (composition) over an "is-a" relationship (inheritance).  

   One of the reasons that inheritance is banned in the library is because onchain composition is favored over inheritance. This is a newer idea that wasn't very possible before diamond contracts. Instead of inheriting a contract to give it additional functionality, just make a new contract (facet), deploy it, and add its functions to your diamond.

   ### Example 
   Let's say you are making an onchain game that has its own NFTs with standard NFT (ERC721) functionality, plus additional custom NFT functionality. Here are steps you could take:
   
   1. Develop a new facet with the custom NFT functionality that you want. You can use the `LibERC721` Solidity library provided by Compose to access NFT storage. If needed you also create your own diamond storage for your custom functionality in your facet.
   2. Deploy your new facet with custom NFT functionality.
   3. Using Compose, setup the deployment of your diamond contract so that it adds the standard NFT functions from the existing, already deployed ERC721 facet (which was deployed by Compose), and also adds the functions from your custom NFT facet.
   4. Deploy your diamond!

   If you need to modify the functionality of standard ERC721 functions, then in that case you cannot use onchain composition. You can make your own custom ERC721 facet by copying the `ERC721Facet.sol` file in Compose and make the necessary changes, or you can inherit the `ERC721Facet`.

#### 7. Maintain compatibility with existing standards, libraries, and systems:
   We want things we build to interoperate and be compatible with existing tools, systems, and expectations. So when writing a smart contract, or particular functionality, find out if there are implementation details that are already established that affect how the functionality works, and make sure your implementation works the way that will be expected. I'm not talking about how the code is written, but how it works, how it functions. We can write our code better (more clear, more readable, and better documented), but make it function the same as established smart contract functionality.

   When implementing new functionality, here are some things you need to consider and do to ensure interoperability and to meet existing expectations of functionality:

   1. Are there any [ERC standards](https://eips.ethereum.org/erc) that cover the functionality? If so, should probably follow that.
   2. Has an existing established library such as [OpenZeppelin](https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable) already implemented that functionality in their library? Make sure your version functions the same -- emits the same events, issues the same error messages, reverts when it reverts, etc. Some judgement is required here, don't do the same thing as another library if it isn't good and doesn't really matter for compatibility. Generally we want to match existing widespread adopted functionality that matters. We don't want to surprise our users, unless it is a good surprise.
   3. Are there existing widespread systems, (for example OpenSea, other NFT exchanges, and DAO and voting systems), which expect contracts to function a certain way? Match it.

### Diamond Contract Development
- Create reusable facets for maximum onchain composability
- Use diamond storage patterns for state management
- Follow established ERC standards for interoperability

### Security Considerations
- All functions must be thoroughly tested
- Gas efficiency is important but how easy the code is to read is more important
- Follow established patterns from existing implementations
- Consider edge cases and potential attack vectors


## Reading a Facet

In Compose, each facet smart contract contains the storage variables and logic needed to implement its core functionality. The code in a facet is written to be easily read and understood from top to bottom—users can start at the first line and follow the logic sequentially to the end of the file without needing to jump to other sections or files.

Each facet includes the complete implementation of its main functionality. Facets do not rely on external contracts or Solidity libraries to implement their core behavior.

## The Use of Solidity Libraries

In Compose, it’s common for a facet to have a corresponding Solidity library. These libraries are designed to help developers integrate their custom facets with Compose’s built-in facets.

For example, Compose includes a facet called `ERC721Facet.sol` and a corresponding library called `LibERC721.sol`. The `ERC721Facet.sol` file contains the complete implementation of the ERC-721 functionality—it does not reference or depend on `LibERC721.sol`.

The `LibERC721.sol` library intentionally duplicates the storage variables and parts of the logic from `ERC721Facet.sol`. This allows developers creating their own custom facets to easily access and work with the `ERC-721` storage variables and functionality provided by Compose.

All Solidity libraries in Compose are prefixed with `Lib`.

## Testing

### Required
Before submitting a pull request:
- Format your code: `forge fmt`
- Run all tests: `forge test`
- Update gas snapshots: `forge snapshot`
- Ensure your code follows the banned features list
- Ensure your code follows the coding style in the existing code base.

## Recommended
- Write tests for new functionality 
- Test your changes thoroughly
- Ensure test coverage is maintained or improved

If you make changes to existing functionality, please make sure that the existing tests still work for that functionality and write new tests as necessary that cover the changes you made.

Please note that you can submit a pull request for new functionality without tests. Another person can write tests for new functionality.

### When writing tests
- Write comprehensive tests for all functionality
- Test edge cases and error conditions
- Use descriptive test names
- Follow the existing test patterns in the codebase
- Include gas optimization tests where relevant

### Running Tests
```bash
# Run all tests
forge test

# Run tests with verbose output
forge test -vvv

# Run specific test file
forge test --match-path test/ERC20.sol

# Run tests with gas reporting
forge test --gas-report
```

### Test Structure

Tests in Compose follow a specific organizational pattern:

- **Facet Tests** (`test/[Feature]/[Feature]Facet.t.sol`): Test external functions of facets
- **Library Tests** (`test/[Feature]/Lib[Feature].t.sol`): Test internal library functions
- **Test Harnesses** (`test/[Feature]/harnesses/`): Special contracts that expose internal functions for testing
  - Facet harnesses add initialization and helper functions
  - Library harnesses expose internal functions as external

Example structure:
```
test/
├── ERC20/
│   ├── ERC20Facet.t.sol          # Tests for facet external functions
│   ├── LibERC20.t.sol             # Tests for library internal functions
│   └── harnesses/
│       ├── ERC20FacetHarness.sol  # Adds mint() and initialize()
│       └── LibERC20Harness.sol    # Exposes internal functions
```

See [test/README.md](test/README.md) for detailed testing documentation and patterns.

## Available Commands

### Build

```bash
forge build
```

### Test

```bash
# Run all tests
forge test

# Run tests with verbose output
forge test -vvv

# Run specific test file
forge test --match-path test/ERC20.sol

# Run tests with gas reporting
forge test --gas-report
```

### Format

```bash
forge fmt
```

### Gas Snapshots

```bash
forge snapshot
```

### Local Development

```bash
# Start local node
anvil

# Interact with contracts
cast <subcommand>
```

### Deploy

```bash
# Deploy contracts
forge script script/ERC20.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Help

```bash
# Get help for any command
forge --help
anvil --help
cast --help
```

## Code of Conduct

### Our Pledge
We are committed to providing a welcoming and inspiring community for all. We pledge to make participation in our project a harassment-free experience for everyone.

### Our Standards
Examples of behavior that contributes to creating a positive environment include:
- Being respectful of differing viewpoints and experiences
- Gracefully accepting constructive criticism
- Focusing on what is best for the community & Compose itself.
- Showing empathy towards other community members.

## Getting Help

If you have contribution or development questions:
- See if the [README](https://github.com/Perfect-Abstractions/Compose/blob/main/README.md) or this CONTRIBUTING document answers your question.
- Start a [discussion](https://github.com/Perfect-Abstractions/Compose/discussions/new?category=q-a)
- Join our Discord: https://discord.gg/DCBD2UKbxc
- Contact Nick Mudge

### Community Guidelines
- Be respectful and constructive in all interactions
- Help others learn and grow
- Share knowledge and best practices
- Report issues and bugs promptly
- Participate in discussions about the project's direction

## License

By contributing to Compose, you agree that your contributions will be licensed under the same license as the project (see [LICENSE.md](LICENSE.md)).

---
<br>
This is the beginning and we are still working out how this will all work. We are glad you are interested in this project and want to make something great with you. - Nick

<br>
---