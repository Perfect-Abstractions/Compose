import { ComposeContext, ModuleState } from "../context/types";
import { BasesCatalog } from "./configModule";
import { cyan, red, yellow } from "../utils/terminal";

// =====================
// Helper
// =====================

const COMPOSE_DOCS_URL = "https://compose.diamonds/";
const VERSION = "0.1.0";

const COMPOSE_HEADER = `
   _____ ____  __  __ _____   ____   _____ ______     _____ _      _____ 
  / ____/ __ \\|  \\/  |  __ \\ / __ \\ / ____|  ____|   / ____| |    |_   _|
 | |   | |  | | \\  / | |__) | |  | | (___ | |__     | |    | |      | |  
 | |   | |  | | |\\/| |  ___/| |  | |\\___ \\|  __|    | |    | |      | |  
 | |___| |__| | |  | | |    | |__| |____) | |____   | |____| |____ _| |_ 
  \\_____\\____/|_|  |_|_|     \\____/|_____/|______|   \\_____|______|_____|
  
  `;

const HELP_TEXT = `
Compose CLI v${VERSION}

Scaffolds Diamond-based projects using the Compose Library

Usage:
  compose init [options]
  compose validate [options]
  compose inspect [options]
  compose --help

Options:
  --framework <foundry|hardhat>
  --starter <starter-id>
  --out <output-directory>
  --help

For more information about Compose, see: ${COMPOSE_DOCS_URL}
`;

type PromptApi = {
  checkbox: <Value>(
    config: {
      message: string;
      choices: readonly { name: string; value: Value; checked?: boolean }[];
      theme?: {
        prefix?: string | { idle?: string; done?: string };
        icon?: {
          checked?: string;
          unchecked?: string;
          cursor?: string;
          disabledChecked?: string;
          disabledUnchecked?: string;
        };
        style?: {
          keysHelpTip?: (keys: [key: string, action: string][]) => string | undefined;
        };
      };
    },
  ) => Promise<Value[]>;
  select: <Value>(
    config: {
      message: string;
      choices: readonly { name: string; value: Value }[];
      default?: Value;
      theme?: {
        prefix?: string | { idle?: string; done?: string };
        icon?: {
          cursor?: string;
        };
        style?: {
          keysHelpTip?: (keys: [key: string, action: string][]) => string | undefined;
        };
      };
    },
  ) => Promise<Value>;
};

type SelectorExportIssue = {
  facetName: string;
  path: string;
  missingExports: string[];
  extraExports: string[];
};

type SelectorExportValidationResult = {
  checkedFacets: number;
  issues: SelectorExportIssue[];
};

type SelectorOwner = {
  facetName: string;
  path: string;
  functionName: string;
  signature: string;
};

type SelectorCollision = {
  selector: string;
  owners: SelectorOwner[];
};

type SelectorCollisionValidationResult = {
  checkedFacets: number;
  collisions: SelectorCollision[];
};

type IdentifierCollisionOwner = {
  facetName: string;
  path: string;
  slot: string;
  layout: string[];
  source: "erc8042" | "slot-assignment";
  structName: string | null;
};

type IdentifierCollision = {
  identifier: string;
  owners: IdentifierCollisionOwner[];
};

type IdentifierCollisionValidationResult = {
  checkedFacets: number;
  collisions: IdentifierCollision[];
};

type FacetScanWarning = {
  facetName: string;
  path: string;
  warnings: string[];
};

type FacetScanResult = {
  facets: FacetScanWarning[];
};

const checkboxTheme = {
  prefix: "",
  icon: {
    checked: "[✓]",
    unchecked: "[ ]",
    cursor: ">",
    disabledChecked: "[✓]",
    disabledUnchecked: "[ ]",
  },
  style: {
    keysHelpTip: () => undefined,
  },
} as const;

const selectTheme = {
  prefix: "",
  icon: {
    cursor: ">",
  },
  style: {
    keysHelpTip: () => undefined,
  },
} as const;

// Load Inquirer lazily so non-interactive commands do not pay prompt startup cost.
async function loadPrompts(): Promise<PromptApi> {
  return (await import("@inquirer/prompts")) as unknown as PromptApi;
}

// Read selector export validation state from context with a typed result.
function getSelectorExportValidationState(
  ctx: ComposeContext,
): ModuleState<SelectorExportValidationResult> | null {
  return (ctx.state.validationSelectorExports as ModuleState<SelectorExportValidationResult> | undefined) ?? null;
}

// Read selector collision validation state from context with a typed result.
function getSelectorCollisionValidationState(
  ctx: ComposeContext,
): ModuleState<SelectorCollisionValidationResult> | null {
  return (
    ctx.state.validationSelectorCollisions as ModuleState<SelectorCollisionValidationResult> | undefined
  ) ?? null;
}

// Read identifier collision validation state from context with a typed result.
function getIdentifierCollisionValidationState(
  ctx: ComposeContext,
): ModuleState<IdentifierCollisionValidationResult> | null {
  return (
    ctx.state.validationIdentifierCollisions as ModuleState<IdentifierCollisionValidationResult> | undefined
  ) ?? null;
}

// Read facet scan state so warnings can be reported before hard failures.
function getFacetScanState(ctx: ComposeContext): ModuleState<FacetScanResult> | null {
  return (ctx.state.facetScan as ModuleState<FacetScanResult> | undefined) ?? null;
}

// =====================
// Modules
// =====================

export const EntryModule = {
  // Print the Compose welcome header shown by interactive init.
  async showComposeHeader(ctx: ComposeContext): Promise<ComposeContext> {
    console.log(cyan(COMPOSE_HEADER));
    console.log(cyan("Scaffold your diamond smart contracts project with Compose"));
    console.log(cyan(`Explore our library: ${COMPOSE_DOCS_URL}\n`));

    ctx.state.welcome = {
      success: true,
      result: {
        header: COMPOSE_HEADER,
        docsUrl: COMPOSE_DOCS_URL,
      },
      error: null,
    };

    return ctx;
  },

  // Print top-level command help for empty CLI invocations.
  async showHelp(ctx: ComposeContext): Promise<ComposeContext> {
    console.log(HELP_TEXT.trim());

    ctx.state.entry = {
      success: true,
      result: {
        helpText: HELP_TEXT.trim(),
      },
      error: null,
    };

    return ctx;
  },

  // Render validation warnings and fail-fast validation reports.
  async showReport(ctx: ComposeContext): Promise<ComposeContext> {
    const facetScan = getFacetScanState(ctx);
    const scanWarnings = (facetScan?.result?.facets ?? [])
      .map((facet) => ({
        facetName: facet.facetName,
        path: facet.path,
        warnings: facet.warnings,
      }))
      .filter((facet) => facet.warnings.length > 0);

    if (scanWarnings.length > 0) {
      console.warn(yellow("\nValidation warnings"));
      for (const facet of scanWarnings) {
        console.warn(`\n${facet.facetName}`);
        console.warn(`  ${facet.path}`);
        for (const warning of facet.warnings) {
          console.warn(`  ${warning}`);
        }
      }
    }

    const selectorExportValidation = getSelectorExportValidationState(ctx);

    if (selectorExportValidation && !selectorExportValidation.success) {
      console.error(red("\nValidation failed"));
      console.error(red(selectorExportValidation.error?.message ?? "Validation failed."));

      for (const issue of selectorExportValidation.result?.issues ?? []) {
        console.error(`\n${issue.facetName}`);
        console.error(`  ${issue.path}`);

        if (issue.missingExports.length > 0) {
          console.error(`  Missing exports: ${issue.missingExports.join(", ")}`);
        }

        if (issue.extraExports.length > 0) {
          console.error(`  Extra exports: ${issue.extraExports.join(", ")}`);
        }
      }

      ctx.status = {
        success: false,
        stopped: true,
        failedAt: "validationSelectorExports",
        error: selectorExportValidation.error,
      };

      return ctx;
    }

    const selectorCollisionValidation = getSelectorCollisionValidationState(ctx);

    if (selectorCollisionValidation && !selectorCollisionValidation.success) {
      console.error(red("\nValidation failed"));
      console.error(red(selectorCollisionValidation.error?.message ?? "Validation failed."));

      for (const collision of selectorCollisionValidation.result?.collisions ?? []) {
        console.error(`\n${collision.selector}`);
        for (const owner of collision.owners) {
          console.error(`  ${owner.facetName}: ${owner.signature}`);
          console.error(`    ${owner.path}`);
        }
      }

      ctx.status = {
        success: false,
        stopped: true,
        failedAt: "validationSelectorCollisions",
        error: selectorCollisionValidation.error,
      };

      return ctx;
    }

    const identifierCollisionValidation = getIdentifierCollisionValidationState(ctx);

    if (identifierCollisionValidation && !identifierCollisionValidation.success) {
      console.error(red("\nValidation failed"));
      console.error(red(identifierCollisionValidation.error?.message ?? "Validation failed."));

      for (const collision of identifierCollisionValidation.result?.collisions ?? []) {
        console.error(`\n${collision.identifier}`);
        for (const owner of collision.owners) {
          console.error(`  ${owner.facetName}: [${owner.layout.join(", ")}]`);
          console.error(`    ${owner.path}`);
        }
      }

      ctx.status = {
        success: false,
        stopped: true,
        failedAt: "validationIdentifierCollisions",
        error: identifierCollisionValidation.error,
      };
    }

    return ctx;
  },

  // Run the no-argument interactive init prompt flow.
  async runInitInteractive(ctx: ComposeContext): Promise<ComposeContext> {
    const { checkbox, select } = await loadPrompts();
    const catalog = ctx.config.bases as BasesCatalog;
    const featureChoices = Object.entries(catalog.features).map(([key, definition]) => ({
      name: definition.label,
      value: key,
    }));

    const framework = await select({
      message: "Select project framework:",
      choices: [
        { name: "Foundry", value: "foundry" },
        { name: "Hardhat", value: "hardhat" },
      ] as const,
      default: "foundry",
      theme: selectTheme,
    });

    const selectedBaseKey = await select({
      message: "Select base:",
      choices: featureChoices,
      theme: selectTheme,
    });

    const selectedBase = catalog.features[selectedBaseKey];

    const mergedRequiredFacets = {
      ...(catalog.globals.diamond?.required ?? {}),
      ...(catalog.globals.libraries?.required ?? {}),
      ...selectedBase.required,
    };

    const availableLibraryFacets = Object.fromEntries(
      [
        ...Object.entries(catalog.globals.diamond?.optional ?? {}),
        ...Object.entries(catalog.globals.libraries?.optional ?? {}),
      ].filter(
        ([facetName]) => !(facetName in mergedRequiredFacets),
      ),
    );

    const libraryChoices = Object.keys(availableLibraryFacets).map((facetName) => ({
      name: facetName,
      value: facetName,
    }));

    const selectedLibraries = await checkbox({
      message: "Select Compose library facets:",
      choices: libraryChoices,
      theme: checkboxTheme,
    });

    const extensionChoices = Object.keys(selectedBase.optional).map((facetName) => ({
      name: facetName,
      value: facetName,
    }));

    const selectedExtensions = await checkbox({
      message: "Select extension facets:",
      choices: extensionChoices,
      theme: checkboxTheme,
    });

    const localExampleChoices = Object.keys(catalog.globals.examples?.optional ?? {}).map((facetName) => ({
      name: facetName,
      value: facetName,
    }));

    const selectedLocalExamples = await checkbox({
      message: "Select local example facets:",
      choices: localExampleChoices,
      theme: checkboxTheme,
    });

    ctx.param.framework = framework;
    ctx.param.base = selectedBaseKey;
    ctx.param.extensions = selectedExtensions;
    ctx.param.libraries = selectedLibraries;
    ctx.param.localExamples = selectedLocalExamples;

    ctx.config.bases = catalog;
    ctx.state.entry = {
      success: true,
      result: {
        framework,
        selectedBaseKey,
        selectedBaseLabel: selectedBase.label,
        selectedLibraries,
        selectedExtensions,
        selectedLocalExamples,
        requiredFacets: Object.keys(mergedRequiredFacets),
        availableLibraryFacets: Object.keys(availableLibraryFacets),
      },
      error: null,
    };

    return ctx;
  },
};
