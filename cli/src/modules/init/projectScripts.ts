/** npm scripts added to generated projects for Compose-specific workflows. */
export const COMPOSE_PROJECT_SCRIPTS = {
  validate: "compose validate",
  deploy: "compose deploy",
} as const;

/**
 * Adds the Compose project scripts without overwriting scripts the project
 * already defines.
 *
 * @param scripts - Existing npm scripts from the generated project manifest.
 * @returns The scripts with `validate` and `deploy` present.
 */
export function withComposeProjectScripts(
  scripts: Record<string, string>,
): Record<string, string> {
  return {
    ...scripts,
    validate: scripts.validate ?? COMPOSE_PROJECT_SCRIPTS.validate,
    deploy: scripts.deploy ?? COMPOSE_PROJECT_SCRIPTS.deploy,
  };
}
