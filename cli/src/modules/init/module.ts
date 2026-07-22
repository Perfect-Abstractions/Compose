import { ComposeContext } from "../../context/types";
import { BasesCatalog } from "../config/types";
import { ConfigModule } from "../config/module";
import {
  getOwnershipChoices,
  getOwnershipExtensionChoices,
  getRoleAccessChoices,
  getRoleAccessExtensionChoices,
  toFacetChoices,
} from "./prompts";
import { checkboxTheme, clearStdin , inputTheme, loadPrompts, selectTheme } from "../../utils/inquirer";
import { getFrameworkDependencies } from "./frameworkDeps";
import { resolveAccessFlags } from "./flags";
import { splitCommaSeparated } from "../../utils/strings";
import { validateProjectName, validateProjectNameWithFolder } from "./projectNameValidation";
import { showComposeHeader, showDependencies, showSuccess } from "./output";

/**
 * Handles interactive and non-interactive init input collection.
 *
 * Validates user selections against the loaded bases catalog, resolves
 * framework, base, library, extension, access, and example choices, and stores
 * the assembled configuration on the context.
 */
export const InitModule = {
  showComposeHeader,
  showSuccess,
  /**
   * Runs the init flow non-interactively from CLI flags.
   *
   * Validates the framework (`foundry` or `hardhat`), base key, library
   * extensions, access layers, and example selections against the catalog. Defaults the
   * Hardhat toolbox to `ethers` if not specified. Throws on any invalid
   * selection.
   *
   * @param ctx - The compose context with CLI flags and the loaded bases catalog.
   * @returns The context with init options stored in `ctx.state.entry`.
   */
  async runInitNonInteractive(ctx: ComposeContext): Promise<ComposeContext> {
    const catalog = ctx.config.bases as BasesCatalog;

    const framework = String(ctx.param.framework ?? "foundry").toLowerCase();
    if (framework !== "foundry" && framework !== "hardhat") {
      throw new Error(`Unsupported framework: ${framework}. Must be "foundry" or "hardhat".`);
    }

    if (framework === "hardhat" && !ctx.param.toolbox) {
      ctx.param.toolbox = "ethers";
    }

    const baseKey = ctx.param.base ? String(ctx.param.base) : "";
    if (!baseKey) {
      throw new Error('Missing required flag: --base');
    }
    if (baseKey !== "none" && !catalog.features[baseKey]) {
      throw new Error(`Unknown base: ${baseKey}. Available: ${Object.keys(catalog.features).join(", ")}`);
    }

    const selectedLibraries = splitCommaSeparated(ctx.param.libraries);
    const selectedExtensions = splitCommaSeparated(ctx.param.extensions);

    const {
      selectedOwnership,
      selectedRoleAccess,
      selectedOwnershipExtensions,
      selectedRoleAccessExtensions,
      selectedAccess,
      selectedAccessExtensions,
    } = resolveAccessFlags(ctx.param);

    ConfigModule.validateGroupedAccessFlags(
      catalog,
      baseKey,
      selectedOwnership,
      selectedRoleAccess,
      selectedOwnershipExtensions,
      selectedRoleAccessExtensions,
    );

    const selection = ConfigModule.resolveCatalogSelection(
      catalog,
      baseKey,
      selectedLibraries,
      selectedExtensions,
      selectedAccess,
      selectedAccessExtensions,
    );

    ctx.param.projectName = ctx.param.projectName ?? "my-diamond";
    const projectNameValidation = validateProjectName(String(ctx.param.projectName));
    if (projectNameValidation !== true) {
      throw new Error(projectNameValidation);
    }
    ctx.param.framework = framework;
    ctx.param.base = baseKey;
    ctx.param.libraries = selectedLibraries;
    ctx.param.extensions = selectedExtensions;
    ctx.param.access = selectedAccess;
    ctx.param.accessExtensions = selectedAccessExtensions;

    ctx.config.bases = catalog;
    ctx.state.entry = {
      success: true,
      result: {
        framework,
        selectedBaseKey: baseKey,
        selectedBaseLabel: selection.selectedBase.label,
        selectedLibraries,
        selectedAccess,
        selectedExtensions: selection.selectedExtensions,
        selectedAccessExtensions: selection.selectedAccessExtensions,
        requiredFacets: Object.keys(selection.requiredFacets),
        availableLibraryFacets: Object.keys(selection.availableGlobalLibraryFacets),
      },
      error: null,
    };

    return ctx;
  },

  /**
   * Runs the init flow interactively using Inquirer prompt primitives.
   *
   * Prompts the user for project name, framework (Foundry/Hardhat), toolbox
   * (for Hardhat), base, library facets, extension facets, access layers,
   * access extension facets, and local example
   * facets via select and checkbox prompts. Each selection is validated against
   * the loaded bases catalog.
   *
   * @param ctx - The compose context with the loaded bases catalog.
   * @returns The context with user selections stored in `ctx.state.entry`.
   */
  async runInitInteractive(ctx: ComposeContext): Promise<ComposeContext> {
    const { input, checkbox, select } = await loadPrompts();
    const catalog = ctx.config.bases as BasesCatalog;

    if (!ctx.param.projectName) {
      const outDir = String(ctx.param.outDir ?? process.cwd());
      await clearStdin();
      const projectName = await input({
        message: "Enter project name:",
        default: "my-diamond",
        validate: (name) => validateProjectNameWithFolder(name, outDir),
        theme: inputTheme,
      });
      ctx.param.projectName = projectName;
    } else {
      const projectNameValidation = validateProjectName(String(ctx.param.projectName));
      if (projectNameValidation !== true) {
        throw new Error(projectNameValidation);
      }
    }

    const featureChoices = [
      { name: "Blank project", value: "none" },
      ...Object.entries(catalog.features)
        .filter(([, definition]) => definition.access !== true && definition.visible !== false)
        .map(([key, definition]) => ({
          name: definition.label,
          value: key,
        })),
    ];

    await clearStdin();
    const framework = await select({
      message: "Select project framework:",
      choices: [
        { name: "Foundry", value: "foundry" },
        { name: "Hardhat", value: "hardhat" },
      ] as const,
      default: "foundry",
      theme: selectTheme,
    });

    if (framework === "hardhat") {
      await clearStdin();
      const toolbox = await select({
        message: "Select Hardhat toolbox:",
        choices: [
          { name: "Ethers (hardhat-toolbox-mocha-ethers)", value: "ethers" },
          { name: "Viem (hardhat-toolbox-viem)", value: "viem" },
        ],
        default: "ethers",
        theme: selectTheme,
      });
      ctx.param.toolbox = toolbox;
    }

    await clearStdin();
    const selectedBaseKey = await select({
      message: "Select base:",
      choices: featureChoices,
      theme: selectTheme,
    });

    const selectedBase = selectedBaseKey === "none"
      ? ConfigModule.EMPTY_BASE
      : catalog.features[selectedBaseKey];

    const availableExtensions = selectedBase.optional ?? {};
    const extensionChoices = toFacetChoices(Object.keys(availableExtensions));

    const selectedExtensions = extensionChoices.length > 0
      ? await (async () => {
          await clearStdin();
          return checkbox({
            message: "Select extension facets:",
            choices: extensionChoices,
            theme: checkboxTheme,
          });
        })()
      : [];

    const availableLibraryFacets = ConfigModule.getAvailableLibraryFacets(catalog, selectedBase);
    const libraryChoices = toFacetChoices(Object.keys(availableLibraryFacets));

    await clearStdin();
    const selectedLibraries = await checkbox({
      message: "Select Compose library facets:",
      choices: libraryChoices,
      theme: checkboxTheme,
    });

    const accessBases = ConfigModule.getAccessBases(catalog, selectedBaseKey);
    const selectedOwnership = selectedBase.accessType === "ownership"
      ? undefined
      : await (async () => {
          await clearStdin();
          return select({
            message: "Select ownership:",
            choices: getOwnershipChoices(accessBases),
            theme: selectTheme,
          });
        })();

    const ownershipExtensionChoices = getOwnershipExtensionChoices(accessBases, selectedOwnership);
    const selectedOwnershipExtensions = ownershipExtensionChoices.length > 0
      ? await (async () => {
          await clearStdin();
          return checkbox({
            message: "Select ownership extension facets:",
            choices: ownershipExtensionChoices,
            theme: checkboxTheme,
          });
        })()
      : [];

    const accessChoices = getRoleAccessChoices(accessBases);

    await clearStdin();
    const selectedAccessControl = await select({
      message: "Select access control:",
      choices: accessChoices,
      theme: selectTheme,
    });
    const selectedRoleAccess = selectedAccessControl ? [selectedAccessControl] : [];
    const selectedAccess = [
      ...(selectedOwnership ? [selectedOwnership] : []),
      ...selectedRoleAccess,
    ];

    const accessExtensionChoices = getRoleAccessExtensionChoices(accessBases, selectedAccessControl);

    const selectedRoleAccessExtensions = accessExtensionChoices.length > 0
      ? await (async () => {
          await clearStdin();
          return checkbox({
            message: "Select access control extension facets:",
            choices: accessExtensionChoices,
            theme: checkboxTheme,
          });
        })()
      : [];
    const selectedAccessExtensions = [
      ...selectedOwnershipExtensions,
      ...selectedRoleAccessExtensions,
    ];

    const { deps, packageType } = getFrameworkDependencies(framework, String(ctx.param.toolbox));
    showDependencies(deps, packageType);
    await clearStdin();
    const installDeps = await (await loadPrompts()).confirm({
      message: "Install project dependencies?",
      default: true,
    });
    ctx.param.installDeps = installDeps;

    const selection = ConfigModule.resolveCatalogSelection(
      catalog,
      selectedBaseKey,
      selectedLibraries,
      selectedExtensions,
      selectedAccess,
      selectedAccessExtensions,
    );

    ctx.param.framework = framework;
    ctx.param.base = selectedBaseKey;
    ctx.param.extensions = selectedExtensions;
    ctx.param.libraries = selectedLibraries;
    ctx.param.access = selectedAccess;
    ctx.param.accessExtensions = selectedAccessExtensions;

    ctx.config.bases = catalog;
    ctx.state.entry = {
      success: true,
      result: {
        framework,
        selectedBaseKey,
        selectedBaseLabel: selectedBase.label,
        selectedLibraries,
        selectedAccess,
        selectedExtensions: selection.selectedExtensions,
        selectedAccessExtensions: selection.selectedAccessExtensions,
        requiredFacets: Object.keys(selection.requiredFacets),
        availableLibraryFacets: Object.keys(availableLibraryFacets),
      },
      error: null,
    };

    return ctx;
  },
};
