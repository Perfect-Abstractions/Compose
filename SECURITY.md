# Security Policy

If you discover a security vulnerability, report it PRIVATELY with the maintainers

## Supported Versions

Compose is currently under active development.</br>We actively support these versions:

| Version | Supported          |
| ------- | ------------------ |
| latest (main)   | :white_check_mark: |

## Reporting a Vulnerability

Email: <a href="mailto:nick@perfectabstractions.com">nick@perfectabstractions.com</a>

Include the following information:
- Description of the issue
- Affected contracts or modules
- Steps to reproduce (preferably with a minimal proof of concept)
- Expected vs actual behavior
- Impact assessment (e.g. funds at risk, privilege escalation, denial of service)
- Suggested mitigation, if available

## Security Model

Compose follows the diamond proxy pattern defined in ERC-2535. All facet calls are executed in the context of the diamond contract via delegatecall, sharing a single storage layout.

Security therefore depends on:
- Correct storage layout management
- Strict control over upgrade mechanisms
- Safe interaction between independent facets

## Audits

When Compose undergoes security audits, reports will be listed here.

If you are a smart contract auditor, we welcome external reviews and contributions to help strengthen the security of the Compose library. Please reach out through the security contact channels described above.

If you are using Compose in your project and have conducted an internal or third-party audit that includes Compose-related components, we encourage you to share relevant findings. This helps improve the overall robustness of the library and benefits the broader ecosystem.

Where appropriate, we may reference public audit reports that include Compose or its components.

## Disclaimer

Compose is provided "as is" without warranties of any kind. 

Users/Projects are responsible for performing their own security reviews and audits before deploying systems that rely on this library.
