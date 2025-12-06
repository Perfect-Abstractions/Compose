# AI Documentation Enhancement Prompts

This file contains all prompts and instructions used for AI-powered documentation enhancement.
Edit this file to adjust AI behavior without modifying the JavaScript code.

---

## System Prompt

You are a Solidity smart contract documentation expert for the Compose framework.
Always respond with valid JSON only, no markdown formatting.
Follow the project conventions and style guidelines strictly.

---

## Relevant Guideline Sections

These section headers from copilot-instructions.md will be extracted and appended to the system prompt.
One section per line. Must match exactly as they appear in copilot-instructions.md.

```
## 3. Core Philosophy
## 4. Facet Design Principles
## 5. Banned Solidity Features
## 6. Composability Guidelines
## 11. Code Style Guide
```

---

## Module Prompt Template

Given this module documentation from the Compose diamond proxy framework, enhance it by generating:

1. **overview**: A clear, concise overview (2-3 sentences) explaining what this module does and why it's useful in the context of diamond contracts.

2. **usageExample**: A practical Solidity code example (10-20 lines) showing how to use this module. Show importing and calling functions.

3. **bestPractices**: 2-3 bullet points of best practices for using this module.

4. **integrationNotes**: A note about how this module works with diamond storage pattern and how changes made through it are visible to facets.

5. **keyFeatures**: A brief bullet list of key features.

Contract Information:
- Name: {{title}}
- Description: {{description}}
- Functions: {{functionNames}}
- Function Details:
{{functionDescriptions}}

Respond ONLY with valid JSON in this exact format (no markdown code blocks, no extra text):
{
  "overview": "enhanced overview text here",
  "usageExample": "solidity code here (use \\n for newlines)",
  "bestPractices": "- Point 1\\n- Point 2\\n- Point 3",
  "keyFeatures": "- Feature 1\\n- Feature 2",
  "integrationNotes": "integration notes here"
}

---

## Facet Prompt Template

Given this facet documentation from the Compose diamond proxy framework, enhance it by generating:

1. **overview**: A clear, concise overview (2-3 sentences) explaining what this facet does and why it's useful in the context of diamond contracts.

2. **usageExample**: A practical Solidity code example (10-20 lines) showing how to use this facet. Show how it would be used in a diamond.

3. **bestPractices**: 2-3 bullet points of best practices for using this facet.

4. **securityConsiderations**: Important security considerations when using this facet (access control, reentrancy, etc.).

5. **keyFeatures**: A brief bullet list of key features.

Contract Information:
- Name: {{title}}
- Description: {{description}}
- Functions: {{functionNames}}
- Function Details:
{{functionDescriptions}}

Respond ONLY with valid JSON in this exact format (no markdown code blocks, no extra text):
{
  "overview": "enhanced overview text here",
  "usageExample": "solidity code here (use \\n for newlines)",
  "bestPractices": "- Point 1\\n- Point 2\\n- Point 3",
  "keyFeatures": "- Feature 1\\n- Feature 2",
  "securityConsiderations": "security notes here"
}

---

## Module Fallback Content

Used when AI enhancement is unavailable for modules.

### integrationNotes

This module accesses shared diamond storage, so changes made through this module are immediately visible to facets using the same storage pattern. All functions are internal as per Compose conventions.

### keyFeatures

- All functions are `internal` for use in custom facets
- Follows diamond storage pattern (EIP-8042)
- Compatible with ERC-2535 diamonds
- No external dependencies or `using` directives

---

## Facet Fallback Content

Used when AI enhancement is unavailable for facets.

### keyFeatures

- Self-contained facet with no imports or inheritance
- Only `external` and `internal` function visibility
- Follows Compose readability-first conventions
- Ready for diamond integration
