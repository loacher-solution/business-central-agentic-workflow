#!/usr/bin/env node
/**
 * BC E2E Test Runner
 *
 * Runs Business Central page script E2E tests using @microsoft/bc-replay.
 * Reads configuration from environment variables.
 *
 * Required env vars:
 *   BC_URL      - Business Central web client URL
 *
 * Optional env vars:
 *   BC_AUTH     - Authentication type: Windows, AAD, UserPassword (default: UserPassword)
 *   BC_USERNAME - Username env var name for AAD/UserPassword (default: BC_USERNAME)
 *   BC_PASSWORD - Password env var name for AAD/UserPassword (default: BC_PASSWORD)
 *   BC_TEST_PATTERN - Glob pattern for test files (default: tests/e2e/*.yml)
 *   BC_RESULT_DIR   - Directory for test results (default: results)
 */

const { execSync } = require('child_process');
const path = require('path');

const bcUrl = process.env.BC_URL;
if (!bcUrl) {
  console.error('ERROR: BC_URL environment variable is required.');
  console.error('Set it to the URL of your Business Central web client.');
  console.error('Example: BC_URL=https://businesscentral.dynamics.com/tenant/sandbox/');
  process.exit(1);
}

const auth = process.env.BC_AUTH || 'UserPassword';
const testPattern = process.env.BC_TEST_PATTERN || 'tests/e2e/*.yml';
const resultDir = process.env.BC_RESULT_DIR || 'results';

const args = [
  `"${testPattern}"`,
  `-StartAddress "${bcUrl}"`,
  `-Authentication ${auth}`,
  `-ResultDir "${resultDir}"`,
];

if (auth === 'AAD' || auth === 'UserPassword') {
  args.push(`-UserNameKey BC_USERNAME`);
  args.push(`-PasswordKey BC_PASSWORD`);
}

const command = `npx replay ${args.join(' ')}`;
console.log('Running BC E2E tests...');
console.log(`Command: ${command}`);
console.log('');

try {
  execSync(command, { stdio: 'inherit' });
  console.log('\nAll tests passed.');
} catch (err) {
  console.error('\nSome tests failed. Check the results directory for details.');
  console.error(`Run: npx playwright show-report ${path.join(resultDir, 'playwright-report')}`);
  process.exit(1);
}
