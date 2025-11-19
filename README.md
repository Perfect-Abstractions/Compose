
**NOTE:** *Compose is at a very early stage and is currently only available to contributors for building the library. It is NOT production ready.* 

*The Solidity feature ban only applies to the library itself. It does not apply to the *users* of the library -- the people who will use this library to make their diamonds. It is our job to help users do what they want to do.*


# Compose

Forget everything you know about designing and organizing smart contracts -- because Compose is different.

We are building a high quality smart contract library by banning Solidity functionality and consistently following conventions and design principles that are oriented to smart contracts.

We are breaking existing software development rules in order to write good software specifically for smart contracts. This is smart contract oriented programming.

## Banned Solidity Features

None of the following features in the Solidity programming language are allowed to be used in this smart contract library. Anyone submitting a pull request that uses any of these features will be fined **$100 USDC**.

[Endless discussion](https://discord.gg/DCBD2UKbxc) about what and why Solidity features should or shouldn't be allowed in this library is *encouraged*.

It isn't that any of these features are bad, that isn't the point. It is that we are writing the best software we can, and part of that is using a limited feature set. This is the "less is more" idea or keep it simple stupid (KISS).

If this feature ban breaks your mind, just realize that this smart contract library is different than what you have encountered before -- it has different importances, different design principles and it has different ways of doing things. Open your mind and be willing to look at smart contracts a different way. Let the design section rewrite your brain.

1. ### Inheritance is **banned**.
   
   No contract may inherit any other contract or interface. For example `MyContract is OtherContract` or `MyContract is IMyInterface` etc. is not allowed. [Onchain composition is favored over inheritance](#favor-onchain-composition-over-inheritance).

2. ### No constructor functions

   No contracts other than a diamond contract (proxy contract), may have a constructor function. For example: `constructor() {owner = msg.sender; }` etc.

3. ### No modifiers

   No contract may use modifiers. For example: `modifier onlyOwner() { require(msg.sender == owner, "Caller is not the owner"); _; }` etc.

4. ### No public or private or internal variables

   No contract or library may have storage variables declared private or public or internal. For example: `uint256 public counter;`. These visibility labels are not needed because the library uses ERC-8042 Diamond storage s1hroughout. This restriction does not apply to constants or immutable variables, which may be declared `internal`.

5. ### No private or public functions

   No contract or library may have a function declared private or public. For example: `function approve(address _spender, uint256 _value) private { ...`. This means all functions in contracts must be declared `internal` or `external`.

6. ### No external functions in Solidity libraries

   No Solidity library may have any external functions. For example: `function name() external view returns (string memory)`. All functions in Solidity libraries must be declared `internal`.

7. ### No `using for` in Solidity libraries

   No Solidity library may use the `using` directive. For example: `using LibSomething for uint`.

8. ### No `selfdestruct`.

   No contract or library may use `selfdestruct`.

Other Solidity features will likely be added to this ban list.

**Note** that the feature ban applies to the smart contracts and libraries within Compose. It does not apply to the users that use Compose. Users can do what they want to do and it is our job to help them.

## Purpose of Compose

The purpose of Compose is to help people create smart contract systems. We want to help them do that quickly, securely, confidently, with understanding, and with the functionality they want. Nothing is more important than this purpose.

## Vision

Compose is an effort to apply software engineering principles specifically to a smart contract library. Smart contracts are not like other software, so let's not treat them like other software. We need to re-evaluate knowledge of programming and software engineering specifically as it applies to smart contracts. Let's really look at what smart contracts are and design and write our library for specifically what we are dealing with. 

What we are dealing with:

1. **Smart contracts are immutable.** Once deployed, the source code for a smart contract doesn't change.
2. **Smart contracts are forever.** Once deployed, smart contracts can run or exist forever.
3. **Smart contracts are shared.** Once deployed, smart contracts can be seen and accessed by anyone.
4. **Smart contracts run on a distributed network.**  Once deployed, smart contracts are running within the capabilities and constraints of the Ethereum Virtual Machine (EVM) and the blockchain network it is deployed on.
5. **Smart contracts must be secure.** Once deployed, there can be very serious consequences if there is a bug or security vulnerability in a smart contract.
6. **Smart contracts are written in a specific language** In our case Compose is written in the Solidity programming language.

If we gather all knowledge about programming and software engineering that has ever existed and will exist, including what you know and what you will soon learn or know, and we evaluate that knowledge as it can best apply specifically to a smart contract library, to create the best smart contract library possible, what do we end up with? Hopefully we end up with what Compose becomes.

## Design

The design and implementation of Compose is based on the following design principles.

1. ### Understanding
   This is the top design and guiding principle of this project. We help our users *understand* the things they want to know so they can *confidently* achieve what they are trying to do. This is why we must have very good documentation, and why we write easy to read and understand code. Understanding leads to solutions, creates confidence, kills bugs and gets things done. Understanding is everything. So we nurture it and create it.

1. ### The code is written to be read
   The code in this library is written to be read and understood by others easily. We want our users to understand our library and be confident with it. We help them do that with code that is easy to read and understand.

   We hope thousands of smart contract systems use our smart contracts. We say in advance to thousands of people in the future, over tens or hundreds of years, who are reading the verified source code of deployed smart contract systems that use our library, **YOU'RE WELCOME**, for making it easy to read and understand.

1. ### Repeat yourself
   The DRY principle — *Don’t Repeat Yourself* — is a well-known rule in software development. We **intentionally** break that rule.

   In traditional software, DRY reduces duplication and makes it easier to update multiple parts of a program by changing one section of code. But deployed smart contracts *don’t change*. DRY can actually reduce clarity. Every internal function adds another indirection that developers must trace through, and those functions sometimes introduce extra logic for different cases. Repetition can make smart contracts easier to read and reason about.

   That said, DRY still has its place. When a large block of code performs a complete, self-contained action and is used identically in multiple locations, moving it into an internal function can improve readability. For example, Compose's ERC-721 implementation uses an `internalTransferFrom` function to eliminate duplication while keeping the code easy to read and understand.

   **Guideline:** Repeat yourself when it makes your code easier to read and understand. Use DRY sparingly and only to make code more readable by removing a lot of unnecessary duplication.

1. ### Compose diamonds  

   A diamond contract is a smart contract that gets its functionality from other contracts called facets. You can add, replace, or remove functionality from these facets, which lets the diamond contract change or grow without deploying a completely new contract. This design makes it easier to build smart contracts that are modular (made of separate parts) and composable (able to work together in flexible ways). A diamond contract can be deployed and then incrementally developed by adding/replacing/removing functionality over time. Diamond contracts can be upgradeable or immutable. [ERC-2535 Diamonds](https://eips.ethereum.org/EIPS/eip-2535) is the standard that defines how diamond contracts work.
   
   Compose is specifically designed to help users develop and deploy [diamond contracts](https://eips.ethereum.org/EIPS/eip-2535). A major part of this project is creating an onchain diamond factory that makes it easy to deploy diamonds that use facets provided by this library and elsewhere.

   Much of Compose consists of facets and Solidity libraries that are used by users to create diamond contracts.

1. ### Onchain composability

   We design facets for maximum onchain reusability and composability.

   We plan to deploy the facets written in this library to many blockchains. There's no reason to take our Solidity source code, as is, and deploy it yourself to a blockchain if it is already deployed there. Just use the facets that are already deployed. We will maintain lists of blockchain addresses for facets that are deployed.

   For example if you want a diamond contract with standard ERC721 NFT functionality, then deploy a diamond contract using this library and add the ERC721 functionality from the existing, already deployed ERC721 facet. You do not need to deploy an ERC721 facet from this library if it has already been deployed to the blockchain you are using.

   Users also have the option of taking our facet source code and modifying it for their needs and deploying what they wish.

1. ### Favor onchain composition over inheritance

   > Favoring onchain composition over inheritance means designing blockchain-based systems by building them    from smaller, independent components that are combined, rather than inheriting functionality from a large, parent class. This approach creates more flexible, loosely coupled, and maintainable smart contracts, as components can be easily swapped or reused without the rigid dependencies that inheritance introduces. It is a software design principle that emphasizes a "has-a" relationship (composition) over an "is-a" relationship (inheritance).  

   One of the reasons that inheritance is banned in the library is because onchain composition is favored over inheritance. This is a newer idea that wasn't very possible before diamond contracts. Instead of inheriting a contract to give it additional functionality, just make a new contract (facet), deploy it, and add its functions to your diamond.

   #### Example 

   Let's say you are making an onchain game that has its own NFTs with standard NFT (ERC721) functionality, plus additional custom NFT functionality. Here are steps you could take:
   
   1. Develop a new facet with the custom NFT functionality that you want. You can use the `LibERC721` Solidity library provided by Compose to access NFT storage. If needed you also create your own diamond storage for your custom functionality in your facet.

   2. Deploy your new facet with custom NFT functionality.
 
   3. Using Compose, setup the deployment of your diamond contract so that it adds the standard NFT functions from the existing, already deployed ERC721 facet (which was deployed by Compose), and also adds the functions from your custom NFT facet.

   4. Deploy your diamond!

   If you need to modify the functionality of standard ERC721 functions, then in that case you cannot use onchain composition. You can make your own custom ERC721 facet by copying the `ERC721Facet.sol` file in Compose and make the necessary changes, or you can inherit the `ERC721Facet`.

1. ### Maintain compatibility with existing standards, libraries, and systems

   We want things we build to interoperate and be compatible with existing tools, systems, and expectations. So when writing a smart contract, or particular functionality, find out if there are implementation details that are already established that affect how the functionality works, and make sure your implementation works the way that will be expected. I'm not talking about how the code is written, but how it works, how it functions. We can write our code better (more clear, more readable, and better documented), but make it function the same as established smart contract functionality.

   When implementing new functionality, here are some things you need to consider and do to ensure interoperability and to meet existing expectations of functionality:

   1. Are there any [ERC standards](https://eips.ethereum.org/erc) that cover the functionality? If so, should probably follow that.
   2. Has an existing established library such as [OpenZeppelin](https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable) already implemented that functionality in their library? Make sure your version functions the same -- emits the same events, issues the same error messages, reverts when it reverts, etc. Generally we want to match existing widespread adopted functionality. We don't want to surprise our users, unless it is a good surprise.
   3. Are there existing widespread systems, (for example OpenSea, other NFT exchanges, and DAO and voting systems), which expect contracts to function a certain way? Match it.

   
   ## Contributors

   New contributors are welcome. Choose the [issues](https://github.com/Perfect-Abstractions/Compose/issues) you want to work on and leave comments describing what you want to do and how you want to do it. I'll answer you and assign you to issues and you can start.

   Look at the [ERC20 and ERC721 implementations](./src/) to see examples of how things are written in this library.
   
   Once you are assigned to an issue you can fork the repository, implement what you are working on, then submit a pull request and I will review it and merge it and/or give you feedback on the work.
   
   You can also make new issues to suggest new functionality or work.

   If you have contribution or development questions then please contact me or create an issue. The discord for Compose is here: https://discord.gg/DCBD2UKbxc

   This is the beginning and we are still working out how this will all work. I am glad you are interested in this project and I want to make something great with you.

   -Nick





## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
