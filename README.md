# opencode-cached

**OpenCode with prompt caching improvements from [PR #5422](https://github.com/anomalyco/opencode/pull/5422)**

This repository automatically builds patched versions of [OpenCode](https://github.com/anomalyco/opencode) with comprehensive prompt caching improvements that significantly reduce AI API costs.

## Why This Fork?

OpenCode's maintainer hasn't merged [PR #5422](https://github.com/anomalyco/opencode/pull/5422), which adds provider-specific caching configuration that can reduce cache write costs by 44% and effective costs by 73% (based on testing with Claude Opus 4.5).

This repository provides a **zero-maintenance clone-and-patch pipeline** that:
- Automatically detects new OpenCode releases
- Applies the caching improvements patch
- Builds arm64 binaries for Linux and macOS
- Publishes releases on GitHub

## Performance Impact

Based on PR #5422's A/B testing with Claude Opus 4.5:

| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| Cache writes (post-warmup) | 18,417 tokens | ~10,340 tokens | **44% reduction** |
| Effective cost (3rd prompt) | 13,021 tokens | 3,495 tokens | **73% reduction** |
| Initial cache write | 16,211 tokens | 17,987 tokens | +11% (one-time cost) |

**Real-world impact**: For users spending ~$900/month on cache writes, this can save ~$400/month.

## What's Included

The patch adds:

- **ProviderConfig System**: Provider-specific cache defaults for 19+ providers
  - Anthropic, Bedrock, Google Vertex, OpenAI, Azure, GitHub Copilot, DeepSeek, etc.
- **Three Caching Paradigms**:
  - Explicit breakpoint (Anthropic, Bedrock)
  - Automatic prefix (OpenAI, Azure, Copilot)
  - Implicit/content-based (Google/Gemini)
- **Configuration Overrides**: Per-agent and per-provider cache settings via `opencode.json`
- **Smarter Cache Breakpoints**: Respects `maxBreakpoints` to prevent over-caching
- **Tool Sorting**: Consistent cache hits across requests

## Installation

### Linux (arm64)

```bash
curl -sL https://github.com/johnnymo87/opencode-cached/releases/latest/download/opencode-linux-arm64.tar.gz | tar xz
sudo mv opencode /usr/local/bin/
opencode --version
```

### macOS (arm64)

```bash
curl -sL https://github.com/johnnymo87/opencode-cached/releases/latest/download/opencode-darwin-arm64.zip -o opencode.zip
unzip opencode.zip
sudo mv bin/opencode /usr/local/bin/
opencode --version
```

### Nix (with this fork)

See the [workstation repo](https://github.com/johnnymo87/workstation) for Nix integration example.

## Configuration

The patch is fully backward-compatible. To customize caching, add to your `opencode.json`:

```json
{
  "provider": {
    "anthropic": {
      "cache": {
        "enabled": true,
        "ttl": "5m",
        "maxBreakpoints": 4
      }
    }
  },
  "agent": {
    "default": {
      "cache": {
        "enabled": true,
        "minTokens": 1024
      }
    }
  }
}
```

See [PR #5422 description](https://github.com/anomalyco/opencode/pull/5422) for full configuration options.

## How It Works

1. **Automated Sync** (every 8 hours):
   - GitHub Actions checks for new OpenCode releases
   - Compares against existing `-cached` releases

2. **Clone and Patch**:
   - Clones upstream at specific tag
   - Applies `patches/caching.patch`
   - Fails loudly if patch doesn't apply (creates GitHub issue)

3. **Build**:
   - Uses Bun to build binaries for `linux-arm64` and `darwin-arm64`
   - No x86, Windows, or Desktop builds (intentionally minimal)

4. **Release**:
   - Publishes as `v{version}-cached` (e.g., `v1.1.65-cached`)
   - Includes checksums for verification

## Maintenance

### When Patch Breaks

If a new OpenCode release causes the patch to fail:

1. GitHub Actions creates an issue automatically
2. Manually update `patches/caching.patch` for the new version
3. Re-trigger build: `gh workflow run build-release.yml --field version=X.Y.Z`

### Sunset Criteria

This fork will be archived if:

- Upstream merges equivalent caching improvements
- PR #5422 is officially closed as "won't fix"
- Patch breaks for 3+ consecutive releases

## Development

### Manual Build

```bash
# Clone a specific version
git clone --depth 1 --branch v1.1.65 https://github.com/anomalyco/opencode.git

# Apply patch
cd opencode
git apply ../patches/caching.patch

# Build
cd packages/opencode
bun install
bun run script/build.ts

# Test
./dist/opencode-linux-arm64/bin/opencode --version
```

### Update Patch for New Version

```bash
# Clone both versions
git clone https://github.com/anomalyco/opencode.git opencode-old
git clone https://github.com/anomalyco/opencode.git opencode-new

cd opencode-old
git checkout v1.1.65  # Old version where patch works

cd ../opencode-new
git checkout v1.1.70  # New version

# Cherry-pick the caching changes
git remote add cached ../opencode-old
git fetch cached
git cherry-pick <commit-hash-from-patch>

# Resolve conflicts, then regenerate patch
git diff v1.1.70..HEAD > ../patches/caching.patch
```

## Credits

- **OpenCode**: [anomalyco/opencode](https://github.com/anomalyco/opencode)
- **Caching PR**: [PR #5422](https://github.com/anomalyco/opencode/pull/5422) by [@ormandj](https://github.com/ormandj)
- **Clone-and-patch inspiration**: [evil-opencode](https://github.com/winmin/evil-opencode)

## License

MIT (same as upstream OpenCode)

## Related

- [Feature request](https://github.com/anomalyco/opencode/issues/5416) for caching improvements
- [My workstation setup](https://github.com/johnnymo87/workstation) using this fork
- [Cost tracking analysis](https://github.com/johnnymo87/workstation/.opencode/skills/tracking-cache-costs) for validation
