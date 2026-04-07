/**
 * vertexEnv - Google Vertex AI environment helpers.
 *
 * Shared utility for building the environment record passed to Claude CLI
 * subprocesses, injecting Vertex AI credentials when the feature is configured.
 *
 * @module vertexEnv
 */
import type { ClaudeSettings } from "@t3tools/contracts";

/**
 * Build the environment record to pass to the Claude Agent SDK / CLI process.
 *
 * Starts from `process.env` and, when Vertex AI is configured in settings,
 * injects `ANTHROPIC_VERTEX_PROJECT_ID` and `CLOUD_ML_REGION` so that the
 * Claude CLI uses Google Cloud Vertex AI with Application Default Credentials
 * instead of the direct Anthropic API.
 *
 * Explicitly set values always take precedence over what is already present in
 * the environment, making it safe to call even when the env vars are already
 * set via the shell.
 */
export function buildVertexEnv(
  claudeSettings: Pick<ClaudeSettings, "vertexProjectId" | "vertexRegion"> | undefined,
): NodeJS.ProcessEnv {
  const extras: Record<string, string> = {};
  if (claudeSettings?.vertexProjectId) {
    extras["ANTHROPIC_VERTEX_PROJECT_ID"] = claudeSettings.vertexProjectId;
  }
  if (claudeSettings?.vertexRegion) {
    extras["CLOUD_ML_REGION"] = claudeSettings.vertexRegion;
  }
  return { ...process.env, ...extras };
}
