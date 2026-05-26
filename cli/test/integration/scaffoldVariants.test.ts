import test from "node:test";
import assert from "node:assert/strict";
import path from "node:path";
import os from "node:os";
import fs from "fs-extra";
import {
  loadTemplateConfig,
  pickVariant,
  resolveTemplatePath,
} from "../../src/scaffold/utils/templateLoader.js";
import { scaffold } from "../../src/scaffold/scaffold.js";

async function scaffoldWithVariant(
  variant: ReturnType<typeof pickVariant>,
  options: { projectName?: string } = {}
) {
  const tempRoot = await fs.mkdtemp(
    path.join(os.tmpdir(), "compose-cli-it-")
  );
  const originalCwd = process.cwd();
  process.chdir(tempRoot);
  try {
    const projectName = options.projectName || "demo-project";
    const result = await scaffold({
      projectName,
      templatePath: resolveTemplatePath(variant),
      options: {
        framework: variant.framework,
        language: variant.language,
        hardhatProjectType: variant.projectType,
        installDeps: false,
      },
    });
    return {
      tempRoot,
      projectDir: result.projectDir,
      nextSteps: result.nextSteps,
    };
  } finally {
    process.chdir(originalCwd);
  }
}

test("scaffolds hardhat minimal variant", async () => {
  const config = await loadTemplateConfig();
  const variant = pickVariant(config, {
    template: "default",
    framework: "hardhat",
    language: "typescript",
    projectType: "minimal",
  });

  const { projectDir, nextSteps } = await scaffoldWithVariant(variant, {
    projectName: "hardhat-minimal-app",
  });
  const packageJson: { name?: string } = await fs.readJson(
    path.join(projectDir, "package.json")
  );

  assert.equal(
    await fs.pathExists(path.join(projectDir, "hardhat.config.ts")),
    true
  );
  assert.equal(packageJson.name, "hardhat-minimal-app");
  assert.equal(nextSteps.includes("npm install"), true);
});

test("scaffolds hardhat mocha-ethers variant", async () => {
  const config = await loadTemplateConfig();
  const variant = pickVariant(config, {
    template: "default",
    framework: "hardhat",
    language: "typescript",
    projectType: "mocha-ethers",
  });

  const { projectDir } = await scaffoldWithVariant(variant, {
    projectName: "hardhat-mocha-app",
  });
  const readme: string = await fs.readFile(
    path.join(projectDir, "README.md"),
    "utf8"
  );

  assert.equal(
    await fs.pathExists(path.join(projectDir, "test", "Counter.ts")),
    true
  );
  assert.equal(readme.includes("{{projectName}}"), false);
  assert.equal(readme.includes("hardhat-mocha-app"), true);
});

test("scaffolds hardhat node-runner-viem variant", async () => {
  const config = await loadTemplateConfig();
  const variant = pickVariant(config, {
    template: "default",
    framework: "hardhat",
    language: "typescript",
    projectType: "node-runner-viem",
  });

  const { projectDir } = await scaffoldWithVariant(variant, {
    projectName: "hardhat-viem-app",
  });
  const packageJson: { dependencies?: Record<string, string> } =
    await fs.readJson(path.join(projectDir, "package.json"));

  assert.equal(
    await fs.pathExists(path.join(projectDir, "test", "Counter.ts")),
    true
  );
  assert.equal(
    packageJson.dependencies?.["@perfect-abstractions/compose"],
    "latest"
  );
});

test("scaffolds into current directory when projectName is dot and directory is logically empty", async () => {
  const config = await loadTemplateConfig();
  const variant = pickVariant(config, {
    template: "default",
    framework: "hardhat",
    language: "typescript",
    projectType: "minimal",
  });

  const tempRoot = await fs.mkdtemp(
    path.join(os.tmpdir(), "compose-cli-it-dot-")
  );
  const originalCwd = process.cwd();
  process.chdir(tempRoot);

  try {
    const result = await scaffold({
      projectName: ".",
      templatePath: resolveTemplatePath(variant),
      options: {
        framework: variant.framework,
        language: variant.language,
        hardhatProjectType: variant.projectType,
        installDeps: false,
      },
    });

    const packageJson: { name?: string } = await fs.readJson(
      path.join(result.projectDir, "package.json")
    );
    assert.equal(result.projectDir, tempRoot);
    assert.equal(packageJson.name, path.basename(tempRoot));
  } finally {
    process.chdir(originalCwd);
  }
});

test("scaffold throws for unknown framework", async () => {
  await assert.rejects(
    () =>
      scaffold({
        projectName: "demo",
        templatePath: resolveTemplatePath({
          id: "test",
          framework: "foundry",
          path: "templates/default/foundry",
        }),
        options: { framework: "unknown", installDeps: false },
      }),
    /Unknown framework/
  );
});

test("scaffold throws when template path is missing", async () => {
  await assert.rejects(
    () =>
      scaffold({
        projectName: "demo",
        templatePath: path.join(
          process.cwd(),
          "this-template-does-not-exist"
        ),
        options: {
          framework: "hardhat",
          language: "typescript",
          installDeps: false,
        },
      }),
    /Template path does not exist/
  );
});
