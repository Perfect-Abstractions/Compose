import type { PromptApi } from "../modules/init/types";

/** A choice option for an Inquirer select or checkbox prompt. */
export type PromptChoice<Value> = {
  name: string;
  value: Value;
};

/**
 * Dynamically imports the prompt primitives used by init.
 * Importing the primitives directly keeps npm hoisting from resolving newer
 * transitive prompt internals through the umbrella @inquirer/prompts package.
 *
 * @returns The prompt API with input, select, checkbox, and confirm methods.
 */
export async function loadPrompts(): Promise<PromptApi> {
  const [
    { default: input },
    { default: select },
    { default: checkbox },
    { default: confirm },
  ] = await Promise.all([
    import("@inquirer/input"),
    import("@inquirer/select"),
    import("@inquirer/checkbox"),
    import("@inquirer/confirm"),
  ]);

  return { input, select, checkbox, confirm } as unknown as PromptApi;
}

/** Custom theme for checkbox prompts with simplified icons, no help tip, and "None" when empty. */
export const checkboxTheme = {
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
    renderSelectedChoices: (selected: readonly { short: string }[]) => {
      if (selected.length === 0) return "None";
      return selected.map((c) => c.short).join(", ");
    },
  },
} as const;

/** Custom theme for input prompts with no prefix or confirmation icon. */
export const inputTheme = {
  prefix: {
    idle: undefined,
    done: undefined,
    active: undefined,
    error: undefined,
  },
  icon: {
    state: {
      done: "",
      idle: "",
      active: "",
      error: "",
    },
  },
  style: {
    helpTip: () => undefined,
    separator: ":",
  },
} as const;

/** Custom theme for select prompts with simplified cursor and no help tip. */
export const selectTheme = {
  prefix: "",
  icon: {
    cursor: ">",
  },
  style: {
    keysHelpTip: () => undefined,
  },
} as const;

/**
 * Clear any buffered data from stdin before the next prompt.
 *
 * Works around a Windows/libuv bug where {@link https://nodejs.org/api/tty.html#readsetrawmodemode | setRawMode(true)} doesn't
 * reliably switch to raw mode after a previous readline closes, causing
 * users to press Enter twice to select.
 */
export async function clearStdin(): Promise<void> {
  return new Promise((resolve) => {
    if (!process.stdin.isTTY) {
      resolve();
      return;
    }
    try {
      process.stdin.resume();
      while (process.stdin.read() !== null) { /* discard */ }
      setTimeout(resolve, 20);
    } catch {
      resolve();
    }
  });
}
