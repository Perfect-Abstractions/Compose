# Repository Assistant / Copilot Instructions

> This file provides repository-scoped guidance for GitHub Copilot, AI code assistants, automation, and all contributors to [Compose](https://compose.diamonds/docs/).  
> It summarizes the most important principles, rules, and patterns. The canonical source of truth remains the public documentation and maintainers' decisions.

---

## 0. Quick Machine-Readable Checklist (Assistants & Bots)

When generating code, PRs, or issue actions:

- PRIORITY: Favor readability and self-contained facets over clever abstractions.
- FACETS: One file, no imports, no inheritance, no modifiers, no constructors.
- LIBRARIES: Self-contained, all functions `internal`, no `using X for Y`.
- VISIBILITY: Facet storage vars have no visibility specifier (except `internal` for `immutable`/`constant`).
- FUNCTION VISIBILITY (facets): Only `external` (entry points) or `internal` (rare helpers).
- STYLE: Parameters prefixed with `_`; camelCase names; braces required for every `if` / `else`.
- BANNED: In facets & libraries: inheritance, constructors, modifiers, public/private functions, external library functions, ternary operator, single-line ifs w/o braces, `selfdestruct`, `using` directives in libraries, visibility specifiers on storage variables.
- TESTS: Add/adjust tests for behavior changes; harness pattern respected.
- APPROVALS: At least 1 core maintainer approval for non-doc changes, 2 for breaking/critical.
- LABELS: Apply appropriate labels (bug, enhancement, docs, security, breaking-change, chore).
- COMPATIBILITY: Preserve externally observable standard behavior (events, errors, return values).
- STORAGE: Reuse structs by copying; only remove trailing variables; maintain original order.
- NO SURPRISES: Document deviations from standards and justify them.
- DO NOT AUTO-MERGE: Human approval required for on-chain logic.
- UPDATE DOCS: If behavior, interface, or rules change, update docs + this file in same PR.

---

## 1. Purpose

- Provide concise guidance to assistants, automation, and contributors.
- Act as the authoritative short-form of contribution, issue, and review policy.
- Prevent drift between code style, facet architecture, and documented design philosophy.

Canonical documentation:
- Main Docs: https://compose.diamonds/docs/
- (Add specific deep links as they are published: contributing, code-review, issues, security, design, testing.)

If a conflict arises: maintainers decide; update this file to match accepted decisions.

---

## 2. Scope

Applies to:
- Code suggestions (AI or human).
- PR authoring and review workflow.
- Issue creation, labeling, and triage.
- Facet & library architecture decisions.
- Automation enforcing style or rules.

Not granting:
- Automatic merge rights for on-chain code.
- Modification of security policy workflows without explicit approval.

---

## 3. Core Philosophy — Compose Is Written to Be Read

The highest priority: code must be easy to read and understand.

Why:
- Clarity builds confidence.
- Understandable code reduces bugs and accelerates correct extension.
- Consistency matters: the library should appear written by one careful author.

We invest in documentation + accessible code so users can confidently build and audit.

---

## 4. Facet Design Principles

### Facets Are Self-Contained
- One facet = one source file = one coherent functional unit.
- No inheritance, no cross-file dependencies, no imports.
- Each facet intended to be added as a complete unit (not partially sliced).

### Facets Are Read Top-to-Bottom
- Definitions precede use.
- Avoid forward mental jumps and indirection unless strictly improving clarity.

### Repeat Yourself (Selective Anti-DRY)
- Prefer inline clarity over indirection.
- Internal helpers are allowed only when they:
  - Encapsulate a fully self-contained action.
  - Remove large blocks of identical logic.
- Repetition is acceptable when it enhances immediate comprehension.
- Example: `internalTransferFrom` in ERC-721 where block duplication would harm clarity.

Guideline: Repeat yourself when it helps understanding; apply DRY only if it improves readability.

---

## 5. Banned Solidity Features — Facets & Libraries

Purpose: Keep deployed on-chain logic minimal, explicit, and consistent.

Exceptions: Tests, scripts, or external consumer projects may use these features.

Rules & Rationale:

1. No inheritance  
   - Replace with on-chain facet composition. Reduces coupling.

2. No constructors  
   - Use explicit initializer functions in deployment flows.

3. No modifiers  
   - Inline checks improve transparency and auditability.

4. No visibility specifiers on facet storage variables  
   - Diamond storage pattern (EIP-8042) makes visibility redundant.  
   - Exception: `immutable` and `constant` may be declared `internal`.

5. Facet functions: only `external` or `internal`  
   - No `public` or `private`—keeps external ABI explicit and internal use minimal.

6. Library functions: all `internal`  
   - No external library entry points; do not use `using Lib for X` inside Compose libraries.

7. No ternary operator  
   - Use explicit `if / else` blocks for clarity.

8. Braces required on all `if` / `else` blocks  
   - Prevents subtle errors and improves scanning.

9. No `selfdestruct`  
   - Preserve contract state continuity and audit expectations.

10. No `using X for Y` directives in libraries  
    - Avoid hidden dispatch patterns; preserve explicitness.

Enforcement:
- Applied to production facet & library code only.
- Tests may violate these for utility or coverage.

---

## 6. Composability Guidelines

- Compose replaces inheritance with on-chain assembly of facets.
- Facets: smallest building blocks, reusable across diamonds.
- Libraries: initialization support and integration points.

Storage reuse:
- Copy the original struct (same ordering).
- Remove unused trailing variables only.
- Never remove variables from middle or beginning.
- Design new structs with removable trailing fields in mind.
- Implement new storage with a unique slot if adding new state.

Authorization:
- Minimize owner/admin checks; only include if fundamental to functionality.
- Favor permissionless, composable design where safe.

---

## 7. Extending Existing Facets

1. Extensions are implemented as new facets.
2. Do not patch or inherit existing facets.
3. Reuse storage by copying struct definitions (preserve ordering).
4. Remove only trailing unused variables.
5. Optimize for packed storage (narrow types).
6. Add new storage via a separate diamond storage struct + unique slot.
7. Document behavioral additions and ensure compatibility with original facet semantics.

Important:
- Maintain strict ordering of reused structs across facets.
- Removing non-final variables is forbidden (breaks layout compatibility).

---

## 8. Exception Process

If a rule appears to block critical functionality:
- Open an Issue or Discussion with justification and alternatives.
- Provide rationale for deviation + security/audit implications.
- Do not unilaterally bypass rules.

Channels:
- Discord: https://discord.gg/DCBD2UKbxc
- Issues: https://github.com/Perfect-Abstractions/Compose/issues
- Discussions: https://github.com/Perfect-Abstractions/Compose/discussions

Example exception: `ERC721EnumerableFacet` reimplements logic rather than layering over `ERC721Facet`.

---

## 9. Example: Extending ERC20Facet (Staking)

(Inline example retained for clarity. Consider relocating to docs/examples and linking if file size becomes a concern.)

```solidity
/**
 * SPDX-License-Identifier: MIT
 */
pragma solidity >=0.8.30;

contract ERC20StakingFacet {
    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event TokensStaked(address indexed _account, uint256 _amount);
    event TokensUnstaked(address indexed _account, uint256 _amount);

    error ERC20InsufficientBalance(address _sender, uint256 _balance, uint256 _needed);
    error InsufficientStakedBalance(address _account, uint256 _requested, uint256 _staked);

    bytes32 constant ERC20_STORAGE_POSITION = keccak256("compose.erc20");

    struct ERC20Storage {
        mapping(address owner => uint256 balance) balanceOf;
    }

    function getERC20Storage() internal pure returns (ERC20Storage storage s) {
        bytes32 position = ERC20_STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }

    bytes32 constant STAKING_STORAGE_POSITION = keccak256("compose.erc20.staking");

    struct ERC20StakingStorage {
        mapping(address account => uint256 stakedBalance) stakedBalances;
        mapping(address account => uint256 stakingStartTime) stakingStartTimes;
    }

    function getStorage() internal pure returns (ERC20StakingStorage storage s) {
        bytes32 position = STAKING_STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }

    function stake(uint256 _amount) external {
        ERC20Storage storage erc20s = getERC20Storage();
        ERC20StakingStorage storage s = getStorage();

        if (erc20s.balanceOf[msg.sender] < _amount) {
            revert ERC20InsufficientBalance(msg.sender, erc20s.balanceOf[msg.sender], _amount);
        }

        erc20s.balanceOf[msg.sender] -= _amount;
        erc20s.balanceOf[address(this)] += _amount;
        emit Transfer(msg.sender, address(this), _amount);

        s.stakedBalances[msg.sender] += _amount;
        if (s.stakingStartTimes[msg.sender] == 0) {
            s.stakingStartTimes[msg.sender] = block.timestamp;
        }

        emit TokensStaked(msg.sender, _amount);
    }

    function unstake(uint256 _amount) external {
        ERC20Storage storage erc20s = getERC20Storage();
        ERC20StakingStorage storage s = getStorage();

        if (s.stakedBalances[msg.sender] < _amount) {
            revert InsufficientStakedBalance(msg.sender, _amount, s.stakedBalances[msg.sender]);
        }

        s.stakedBalances[msg.sender] -= _amount;
        erc20s.balanceOf[address(this)] -= _amount;
        erc20s.balanceOf[msg.sender] += _amount;
        emit Transfer(address(this), msg.sender, _amount);

        if (s.stakedBalances[msg.sender] == 0) {
            s.stakingStartTimes[msg.sender] = 0;
        }

        emit TokensUnstaked(msg.sender, _amount);
    }

    function getStakedBalance(address _account) external view returns (uint256) {
        return getStorage().stakedBalances[_account];
    }

    function getStakingStartTime(address _account) external view returns (uint256) {
        return getStorage().stakingStartTimes[_account];
    }
}
```

Summary of correctness:
- New facet instead of modifying `ERC20Facet`.
- Storage struct reused with trailing removal only.
- Order preserved.
- New storage slot for staking data.
- No imports, no inheritance, no banned features.

---

## 10. Maintain Compatibility

Checklist before implementing new facets:

1. ERC Standards: Review relevant [ERC references](https://eips.ethereum.org/erc). Implement required interface signatures & events precisely.
2. Common Libraries: Mirror externally observable behavior of widely adopted patterns (e.g. OpenZeppelin) where it affects interoperability (event ordering, error semantics).
3. Ecosystem Tools: Ensure compatibility with wallets, indexers, marketplaces (ERC-165 detection, metadata interfaces, approval flows).
4. Deviations: If deviating for valid reasons, clearly document differences and supply tests proving intended alternative behavior.

Goal: No surprises for integrators.

---

## 11. Code Style Guide

Follow overarching design principles.

### Naming
- Parameters: prefix with `_` in events, errors, functions.
- camelCase identifiers (except standardized uppercase acronyms like `ERC`).
- Facet internal helpers may optionally prefix `internal` if name collision risk exists (keep internal helper usage minimal).

### Comments
- Use `/** */` block comment style for all documentation and inline comments.
- For multiline comments, use proper block format with `*` on each line:
  ```solidity
  /**
   * First line of comment.
   * Second line of comment.
   */
  ```
- Single-line comments also use block style: 
  ```Solidity
  /** 
   * Single line comment. 
   */
  ```
- Use NatSpec tags (`@title`,`@custom:`,`@notice`, `@dev`, `@param`, `@return`) for documentation.

### Resetting Values
- Use `delete` for zeroing mappings/variables.

### Assembly
- Avoid unless necessary; if needed and memory accessed, use `assembly ("memory-safe") { ... }`.
- Provide inline comments for non-trivial assembly blocks.

### Formatting
- Use default `forge fmt`. Run prior to committing.

### Error Reporting
- Prefer custom errors over revert strings for clarity and gas efficiency.

---

## 12. Testing

Expectations:
- New behavior: add tests (unit + edge cases).
- Changed behavior: adjust existing tests + add regression cases.
- It is acceptable to submit an initial PR without tests for new functionality, but tests must land before merge.

Test patterns:
- Facet tests: `test/[Feature]/[Feature]Facet.t.sol`
- Library tests: `test/[Feature]/Lib[Feature].t.sol`
- Harnesses: `test/[Feature]/harnesses/` (expose internal logic safely)

Recommended commands:
```bash
forge build
forge test
forge test -vvv
forge test --match-path test/ERC20.sol
forge test --gas-report
forge snapshot
forge fmt
anvil            # local node
cast <subcommand>
```

Gas considerations:
- Provide gas reports for significant changes.
- Avoid unnecessary storage writes or recalculations.

---

## 13. Available Developer Commands (Summary)

| Action            | Command Example                    |
|-------------------|------------------------------------|
| Build             | `forge build`                      |
| Test (all)        | `forge test`                       |
| Test (verbose)    | `forge test -vvv`                  |
| Test (single)     | `forge test --match-path test/X.sol` |
| Gas report        | `forge test --gas-report`          |
| Snapshot          | `forge snapshot`                   |
| Format            | `forge fmt`                        |
| Local node        | `anvil`                            |
| Cast utilities    | `cast --help`                      |

---

## 14. Pull Request Expectations

PR Description Checklist:
- What changed + why.
- Linked Issue(s) (if any).
- Risk & upgrade notes (if storage layout or external behavior changes).
- Test plan (or follow-up test PR reference).
- Changelog entry (if user-facing facet/library changes).

Approvals:
- 1 core maintainer for normal changes.
- 2 for breaking, critical, or multi-standard extensions.

Labels:
- Apply at creation: `bug`, `enhancement`, `docs`, `security`, `breaking-change`, `chore`.

---

## 15. Security & Safety

- Never publicly disclose vulnerabilities; follow security doc guidance.
- Avoid introducing unbounded loops dependent on attacker-controlled state unless gas feasibility is documented.
- Explicitly document any external calls and reentrancy protections (check-effects-interactions or nonReentrant patterns implemented inline).

---

## 16. Maintenance & Versioning

Update this file:
- Whenever rules, patterns, or banned feature rationale changes.
- Alongside any systemic architecture shifts (e.g., storage design changes).
- Reference a changelog section (consider adding `CHANGELOG.md` or release notes).

Include version tag here (update manually):
- File version: `v1.0.0` (update as needed)

---

## 17. Contacts & Escalation

- Discord: https://discord.gg/DCBD2UKbxc
- Issues: https://github.com/Perfect-Abstractions/Compose/issues
- Discussions: https://github.com/Perfect-Abstractions/Compose/discussions
- Maintainers: see `.github/CODEOWNERS`

---

## 18. Compliance Summary (For Auditors)

This file enforces:
- Deterministic facet architecture.
- Explicit storage layout reuse rules.
- Clear readability-first philosophy.
- Banned feature list preventing unsafe or obfuscating patterns.
- Structured test + PR workflow to reduce regression risk.

---

## 19. Final Reminder

Assistants: Prefer clarity over micro-optimizations unless gas impact is measurable and documented.  
Contributors: Include rationale for architectural changes.  
Maintainers: Keep docs + this file synchronized.

Signed-off-by: Repository Maintainers
```