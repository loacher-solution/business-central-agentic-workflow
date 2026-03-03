#!/usr/bin/env node
/**
 * BC Replay test runner
 *
 * Wraps the npx replay command with configuration from environment variables.
 * Environment variables (set in CI or locally via .env):
 *
 *   BC_START_ADDRESS  - Business Central web client URL (required)
 *                       e.g. https://mybc.example.com/BC/
 *   BC_AUTH           - Authentication type: Windows | AAD | UserPassword (default: UserPassword)
 *   BC_USERNAME_KEY   - Env var name holding the BC username (default: BC_USERNAME)
 *   BC_PASSWORD_KEY   - Env var name holding the BC password (default: BC_PASSWORD)
 *   BC_TESTS_GLOB     - Glob pattern for test recordings (default: recordings/*.yml)
 *   BC_RESULT_DIR     - Directory for test results (default: results)
 *   BC_HEADED         - Set to "true" to run headed (shows browser)
 *
 * Usage:
 *   node run-tests.js [--headed]
 */

const { execSync } = require("child_process");
const path = require("path");
const fs = require("fs");

// Parse CLI flags
const args = process.argv.slice(2);
const headedFlag = args.includes("--headed") || process.env.BC_HEADED === "true";

// Read config from environment
const startAddress = process.env.BC_START_ADDRESS;
if (!startAddress) {
  console.error("ERROR: BC_START_ADDRESS environment variable is required.");
  console.error("Set it to your Business Central web client URL, e.g.:");
  console.error("  export BC_START_ADDRESS=https://mybc.example.com/BC/");
  process.exit(1);
}

const auth = process.env.BC_AUTH || "UserPassword";
const usernameKey = process.env.BC_USERNAME_KEY || "BC_USERNAME";
const passwordKey = process.env.BC_PASSWORD_KEY || "BC_PASSWORD";
const testsGlob = process.env.BC_TESTS_GLOB || "recordings/*.yml";
const resultDir = path.resolve(process.env.BC_RESULT_DIR || "results");

// Build the npx replay command
const parts = [
  "npx replay",
  `"${testsGlob}"`,
  `-StartAddress "${startAddress}"`,
  `-Authentication ${auth}`,
  `-UserNameKey ${usernameKey}`,
  `-PasswordKey ${passwordKey}`,
  `-ResultDir "${resultDir}"`,
];

if (headedFlag) {
  parts.push("-Headed");
}

const cmd = parts.join(" ");
console.log("Running BC Playwright tests...");
console.log(`Command: ${cmd}`);
console.log(`Start address: ${startAddress}`);
console.log(`Authentication: ${auth}`);
console.log(`Test recordings: ${testsGlob}`);
console.log(`Results dir: ${resultDir}`);
console.log("");

// Ensure result directory exists
fs.mkdirSync(resultDir, { recursive: true });

try {
  execSync(cmd, { stdio: "inherit", cwd: __dirname });
  console.log("\nAll tests passed.");
} catch (err) {
  console.error("\nSome tests failed. Run 'npm run report' to view the report.");
  process.exit(1);
}
