import inquirer from "inquirer";
import {
  getTemplateChoices,
  validateProjectLocation,
} from "../utils/prompts/initUtils.js";

type InitOptionsSeed = {
  name?: string;
  template?: string;
  framework?: string;
  hardhatProjectType?: string;
  installDeps?: boolean;
};

type InitAnswers = {
  name: string;
  template: string;
  framework: string;
  hardhatProjectType: string;
  installDeps: boolean;
};

export async function askInitPrompts(
  seed: InitOptionsSeed = {}
): Promise<InitAnswers> {
  const answers = await inquirer.prompt<InitAnswers>([
    {
      type: "input",
      name: "name",
      message:
        'Where would you like to initialize the project? ("." for current directory) ',
      default: seed.name || "my-first-diamond",
      when: () => !seed.name,
      validate: validateProjectLocation,
    },
    {
      type: "select",
      name: "template",
      message: "Choose your diamond template? ",
      choices: () => getTemplateChoices(),
      when: () => !seed.template,
    },
    {
      type: "select",
      name: "framework",
      message: "Choose your framework?",
      choices: ["foundry", "hardhat"],
      when: () => !seed.framework,
    },
    {
      type: "select",
      name: "hardhatProjectType",
      message: "What Hardhat 3 project do you want to create? ",
      choices: [
        {
          name: "Minimal Hardhat Project",
          value: "minimal",
        },
        {
          name: "TypeScript Hardhat project using Mocha and Ethers.js",
          value: "mocha-ethers",
        },
        {
          name: "TypeScript Hardhat project using Node Test Runner and Viem",
          value: "node-runner-viem",
        },
      ],
      when: (answers) => {
        const framework = seed.framework || answers.framework;
        return framework === "hardhat" && !seed.hardhatProjectType;
      },
    },
    {
      type: "confirm",
      name: "installDeps",
      message: "Install dependencies now? ",
      default: true,
      when: () => typeof seed.installDeps !== "boolean",
    },
  ]);

  return {
    ...seed,
    ...answers,
  } as InitAnswers;
}
