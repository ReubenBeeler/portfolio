/// Identifies the build that is actually running, so a change that appears to
/// do nothing because the deploy is stale cannot be mistaken for a change that
/// does nothing. Set by CI, see .github/workflows.
const String buildId = String.fromEnvironment('BUILD_ID', defaultValue: 'local (no BUILD_ID)');
