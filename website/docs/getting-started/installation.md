---
sidebar_position: 1
---

# Installation

Get up and running with Compose in just a few minutes.

## Prerequisites

Before you begin, make sure you have the following installed:

- **[Foundry](https://book.getfoundry.sh/getting-started/installation)** - Fast, portable Ethereum development framework
- **Git** - For cloning repositories
- **Node.js 20+** - (Optional) For running tests and scripts

## Quick Start

### Option 1: Clone the Repository (Contributors)

If you're contributing to Compose:

```bash
# Clone the repository
git clone https://github.com/Perfect-Abstractions/Compose.git
cd Compose

# Install dependencies
forge install

# Build the project
forge build

# Run tests
forge test
```

### Option 2: Install as Dependency (Coming Soon)

In the future, you'll be able to install Compose as a Foundry dependency:

```bash
# This will be available when Compose reaches stable release
forge install Perfect-Abstractions/Compose
```

## Project Structure

After installation, you'll find the following structure:

```
Compose/
├── src/                    # Source contracts
│   ├── facets/            # Facet implementations
│   ├── libraries/         # Library helpers
│   └── interfaces/        # Standard interfaces
├── test/                  # Test files
├── script/                # Deployment scripts
├── lib/                   # Dependencies
└── foundry.toml          # Foundry configuration
```

## Configuration

### Foundry Setup

Compose includes a pre-configured `foundry.toml`. If you're integrating Compose into an existing project, add these settings:

```toml
[profile.default]
src = "src"
out = "out"
libs = ["lib"]
<<<<<<< HEAD
solc_version = "0.8.24"
optimizer = true
optimizer_runs = 200
via_ir = false

[profile.default.fuzz]
runs = 256

[profile.ci]
fuzz = { runs = 5000 }
invariant = { runs = 1000 }
```

### Remappings

Add these remappings to your `remappings.txt` or `foundry.toml`:

```
compose/=lib/Compose/src/
forge-std/=lib/forge-std/src/
=======
optimizer = true
optimizer_runs = 20_000
evm_version = "prague"

[profile.ci]
src = "src"
out = "out"
libs = ["lib"]
optimizer = true
optimizer_runs = 20_000
evm_version = "prague"
# Coverage settings
fuzz = { runs = 1000 }
invariant = { runs = 1000 }

[fmt]
line_length = 120
tab_width = 4
bracket_spacing = false
int_types = 'long'
multiline_func_header = 'attributes_first'
quote_style = 'double'
number_underscore = 'preserve'
single_line_statement_blocks = 'preserve'
>>>>>>> mudge/main
```

## Verify Installation

Run the tests to verify everything is working:

```bash
forge test -vvv
```

You should see output indicating all tests pass.

<<<<<<< HEAD
## What's Next?
=======
<!-- ## What's Next?
>>>>>>> mudge/main

Now that you have Compose installed, let's understand the core concepts:

- **[Core Concepts](/)** - Learn about facets, libraries, and shared storage
- **[Quick Start Guide](/docs/getting-started/quick-start)** - Jump right in with a working example
<<<<<<< HEAD
- **[Your First Diamond](/docs/getting-started/your-first-diamond)** - Build a simple diamond with Compose facets
=======
- **[Your First Diamond](/docs/getting-started/your-first-diamond)** - Build a simple diamond with Compose facets -->
>>>>>>> mudge/main

## Getting Help

Having trouble with installation?

- Check the **[FAQ](/)**
- Ask in **[Discord](https://discord.gg/compose)**
- Open an **[issue on GitHub](https://github.com/Perfect-Abstractions/Compose/issues)**

:::tip Development Environment
We recommend using VSCode with the **Solidity** extension by Juan Blanco for the best development experience.
:::

