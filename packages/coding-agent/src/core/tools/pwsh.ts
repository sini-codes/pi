import { getPwshShellConfig, wrapPwshCommand } from "../../utils/shell.ts";
import {
	type BashOperations,
	type BashSpawnContext,
	type BashSpawnHook,
	type BashToolDetails,
	type BashToolInput,
	type BashToolOptions,
	type createBashTool,
	createLocalShellOperations,
	createShellToolDefinition,
	type ShellToolConfig,
} from "./bash.ts";
import { wrapToolDefinition } from "./tool-definition-wrapper.ts";

const UTF8_OUTPUT_PREFIX = "try { [Console]::OutputEncoding=[System.Text.Encoding]::UTF8 } catch {}\n";

export const pwshToolSystemPromptContribution = {
	snippet: "Execute PowerShell commands (Get-ChildItem, Select-String, git, npm, etc.)",
	guidelines: ["You can inspect PI_* environment variables for current model and session details."],
} as const;

export type PwshOperations = BashOperations;
export type PwshSpawnContext = BashSpawnContext;
export type PwshSpawnHook = BashSpawnHook;
export type PwshToolDetails = BashToolDetails;
export type PwshToolInput = BashToolInput;
export type PwshToolOptions = BashToolOptions;

/**
 * Create pwsh operations using pi's built-in local shell execution backend.
 * `shellPath` overrides pwsh resolution; `wrapPwshCommand` maps PowerShell errors to exit codes.
 */
export function createLocalPwshOperations(options?: { shellPath?: string }): PwshOperations {
	const operations = createLocalShellOperations("pwsh", () => getPwshShellConfig(options?.shellPath));
	return {
		exec: (command, cwd, execOptions) =>
			operations.exec(`${UTF8_OUTPUT_PREFIX}${wrapPwshCommand(command)}`, cwd, execOptions),
	};
}

const pwshToolConfig: ShellToolConfig = {
	name: "pwsh",
	label: "pwsh",
	shellName: "PowerShell",
	prompt: "PS>",
	promptSnippet: pwshToolSystemPromptContribution.snippet,
	promptGuidelines: pwshToolSystemPromptContribution.guidelines,
	tempFilePrefix: "pi-pwsh",
};

export function createPwshToolDefinition(
	cwd: string,
	options?: PwshToolOptions,
): ReturnType<typeof createShellToolDefinition> {
	return createShellToolDefinition(cwd, pwshToolConfig, {
		...options,
		operations: options?.operations ?? createLocalPwshOperations({ shellPath: options?.shellPath }),
	});
}

export function createPwshTool(cwd: string, options?: PwshToolOptions): ReturnType<typeof createBashTool> {
	const definition = createPwshToolDefinition(cwd, options);
	const tool = wrapToolDefinition(definition);
	Object.assign(tool, {
		promptSnippet: definition.promptSnippet,
		promptGuidelines: definition.promptGuidelines,
	});
	return tool;
}
