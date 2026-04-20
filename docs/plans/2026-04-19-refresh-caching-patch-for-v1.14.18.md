# Refresh caching.patch for v1.14.18 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. **Read the design doc first**: `~/projects/opencode-patched/docs/plans/2026-04-19-refresh-patch-stack-for-v1.14.18-design.md`. **Tracked in beads (`workstation` DB) as `workstation-5k6`** — mark `in_progress` when starting, `closed` when the `v1.14.18-cached` release is live.

**Goal:** Rebase `patches/caching.patch` onto upstream `anomalyco/opencode@v1.14.18` and cut a `v1.14.18-cached` release.

**Architecture:** Work in `/tmp/opencode-refresh/opencode-v1.14.18`, apply patch with `--reject`, resolve conflicts guided by upstream PR #5422, regenerate patch via `git diff`, validate with typecheck, push to `main`, trigger `build-release.yml`.

**Tech Stack:** Upstream opencode (TypeScript, Bun), git, bash, gh CLI.

---

## Compaction-Resilience Checklist

If resuming this plan after memory compaction:

1. Read the design doc at `~/projects/opencode-patched/docs/plans/2026-04-19-refresh-patch-stack-for-v1.14.18-design.md` (especially §"Repositories and Ownership", §"Refresh Mechanics", and §"Current Known State").
2. Check beads: `cd ~/projects/workstation && bd show workstation-5k6`.
3. Check this repo's state: `cd ~/projects/opencode-cached && git status && git log --oneline -5`.
4. Check if upstream has moved past v1.14.18: `gh release list --repo anomalyco/opencode --limit 5`. If there's a newer version that's been stable for 24h, consider targeting it instead — update this plan first.
5. Resume at the first unchecked task below.

**Current known state (2026-04-19):**
- `~/projects/opencode-cached` on `main`, clean working tree, last commit `4ceef96 fix: rebase caching patch onto v1.4.3`.
- Last release: `v1.4.3-cached`.
- `gh release list --repo anomalyco/opencode --limit 1` → `v1.14.18`.
- `patches/caching.patch` is 2140 lines; when applied against `v1.14.18`, 13 of ~17 hunks are rejected across 4 modified files. The two new files (`packages/opencode/src/provider/config.ts`, `packages/opencode/test/provider/config.test.ts`) apply cleanly.

---

## Task Tracking

Check off each task as it completes. Update beads `workstation-5k6` after each commit with `bd update workstation-5k6 --notes "<what's done>"`.

- [ ] Task 1: Prepare clean upstream checkout
- [ ] Task 2: Assess current patch conflicts
- [ ] Task 3: Resolve `config/config.ts` hunks
- [ ] Task 4: Resolve `provider/transform.ts` hunks
- [ ] Task 5: Resolve `session/prompt.ts` hunks
- [ ] Task 6: Resolve `test/provider/transform.test.ts` hunks
- [ ] Task 7: Regenerate patch file from clean diff
- [ ] Task 8: Validate by re-applying from scratch + typecheck
- [ ] Task 9: Commit and push
- [ ] Task 10: Trigger `build-release.yml` workflow and watch to success
- [ ] Task 11: Close blocker issues, close beads task

---

### Task 1: Prepare clean upstream checkout

**Files:**
- Create: `/tmp/opencode-refresh/opencode-v1.14.18` (git worktree)

**Step 1: Clone upstream at target tag**

```bash
rm -rf /tmp/opencode-refresh
mkdir -p /tmp/opencode-refresh
cd /tmp/opencode-refresh
git clone --depth 1 --branch v1.14.18 https://github.com/anomalyco/opencode.git opencode-v1.14.18
```

Expected output: `Cloning into 'opencode-v1.14.18'...` then completion.

**Step 2: Verify tag**

```bash
cd /tmp/opencode-refresh/opencode-v1.14.18
git log -1 --oneline
```

Expected: The HEAD commit message contains `release: v1.14.18` or similar.

---

### Task 2: Assess current patch conflicts

**Step 1: Attempt apply with --reject**

```bash
cd /tmp/opencode-refresh/opencode-v1.14.18
git apply --reject ~/projects/opencode-cached/patches/caching.patch 2>&1 | tee /tmp/opencode-refresh/apply-log.txt
```

Expected: Non-zero exit. Log lists which hunks failed per file. Record the count per file in beads notes for reference.

**Step 2: List reject files**

```bash
find /tmp/opencode-refresh/opencode-v1.14.18 -name "*.rej"
```

Expected (2026-04-19 snapshot — update if different):

```
.../packages/opencode/src/config/config.ts.rej
.../packages/opencode/src/provider/transform.ts.rej
.../packages/opencode/src/session/prompt.ts.rej
.../packages/opencode/test/provider/transform.test.ts.rej
```

If the set of conflicting files differs from the snapshot, adjust Tasks 3–6 to cover the actual set.

**Step 3: Fetch the upstream PR diff as behavioral guide**

```bash
gh pr diff 5422 --repo anomalyco/opencode > /tmp/opencode-refresh/pr-5422.patch
wc -l /tmp/opencode-refresh/pr-5422.patch
```

Expected: a file with a few thousand lines. This is what the patch *should express* behaviorally; use it as the source of truth for intent, not as a drop-in replacement (PR structure evolves).

---

### Task 3: Resolve `config/config.ts` hunks

**Files:**
- Modify: `/tmp/opencode-refresh/opencode-v1.14.18/packages/opencode/src/config/config.ts`
- Reference: `/tmp/opencode-refresh/opencode-v1.14.18/packages/opencode/src/config/config.ts.rej`
- Reference: `/tmp/opencode-refresh/pr-5422.patch` (search for `config/config.ts`)

**Step 1: Understand what the patch adds to config.ts**

```bash
grep -n "config/config.ts" ~/projects/opencode-cached/patches/caching.patch | head -5
```

Expected: shows the patch header. Then read the relevant section of the patch to understand which symbols (e.g., `CacheTTL`, `PromptSection`, provider-specific cache settings in schema) are being introduced.

**Step 2: Read the rejected hunks**

```bash
cat /tmp/opencode-refresh/opencode-v1.14.18/packages/opencode/src/config/config.ts.rej
```

Each `@@` section is a hunk that couldn't be applied. The rejection usually means the surrounding upstream context drifted (new fields, renamed symbols, reordered blocks).

**Step 3: Read the current upstream file around the targeted line ranges**

```bash
# For each rejected hunk's line range, inspect current upstream:
sed -n '500,560p' /tmp/opencode-refresh/opencode-v1.14.18/packages/opencode/src/config/config.ts
# Repeat for each hunk's line range.
```

**Step 4: Apply equivalent changes by hand**

For each rejected hunk, find the correct new location in the upstream file and insert the additions. Keep additions minimal — only what's needed to land PR #5422's behavior. Do not modify lines that don't need modifying.

**Step 5: Remove the `.rej` file when done**

```bash
rm /tmp/opencode-refresh/opencode-v1.14.18/packages/opencode/src/config/config.ts.rej
```

**Step 6: Smoke check**

```bash
cd /tmp/opencode-refresh/opencode-v1.14.18
bun install  # if not already done
bun --cwd packages/opencode typecheck 2>&1 | tail -20
```

Expected: at this point typecheck likely still fails because transform.ts/prompt.ts hunks aren't in yet. That's fine — the check is just that **config.ts doesn't introduce new errors beyond what's expected from the incomplete patch state**. If you see a syntax error in config.ts, go back and fix it before moving on.

---

### Task 4: Resolve `provider/transform.ts` hunks

Same procedure as Task 3, but for `packages/opencode/src/provider/transform.ts`:

**Step 1: Read the rejected hunks**

```bash
cat /tmp/opencode-refresh/opencode-v1.14.18/packages/opencode/src/provider/transform.ts.rej
```

**Step 2: Key caveat**

`transform.ts` also hosts the `isAnthropicAdaptive` model list that upstream `v1.14.18` now contains `opus-4-7` in (confirmed 2026-04-19). When resolving caching hunks, **do not accidentally re-add opus-4-7 logic** — that belongs to the (now obsolete) `opus-4-7.patch` in `opencode-patched`. Caching's changes to `transform.ts` are in the cache-config helper functions, a different area.

**Step 3: Apply caching-specific hunks**

Resolve each rejected hunk by finding the corresponding spot in upstream `transform.ts` and inserting the caching logic. Use `/tmp/opencode-refresh/pr-5422.patch` as the behavioral reference.

**Step 4: Remove `.rej`**

```bash
rm /tmp/opencode-refresh/opencode-v1.14.18/packages/opencode/src/provider/transform.ts.rej
```

**Step 5: Typecheck**

```bash
bun --cwd packages/opencode typecheck 2>&1 | tail -20
```

Note residual errors (likely from prompt.ts + test file still pending).

---

### Task 5: Resolve `session/prompt.ts` hunks

Same pattern.

**Step 1: Read rejected hunks**

```bash
cat /tmp/opencode-refresh/opencode-v1.14.18/packages/opencode/src/session/prompt.ts.rej
```

**Step 2: Understand the patch's role in prompt.ts**

From the design doc: caching touches `session/prompt.ts` to wire cache-breakpoint placement into prompt assembly. Look for sections that sort tools, place cache breakpoints, or respect `maxBreakpoints`.

**Step 3: Apply equivalent changes**

As before.

**Step 4: Remove `.rej`**

```bash
rm /tmp/opencode-refresh/opencode-v1.14.18/packages/opencode/src/session/prompt.ts.rej
```

**Step 5: Typecheck**

```bash
bun --cwd packages/opencode typecheck 2>&1 | tail -20
```

After this task, typecheck should pass or only have errors in `test/`.

---

### Task 6: Resolve `test/provider/transform.test.ts` hunks

**Step 1: Read rejected hunks**

```bash
cat /tmp/opencode-refresh/opencode-v1.14.18/packages/opencode/test/provider/transform.test.ts.rej
```

**Step 2: Apply**

Tests tend to drift more than production code (upstream adds/reshapes test cases freely). Focus on adding the caching-specific assertions from the patch into the current test file structure. Keep them in whichever `describe`/`it` block makes sense in the upstream layout.

**Step 3: Remove `.rej`**

```bash
rm /tmp/opencode-refresh/opencode-v1.14.18/packages/opencode/test/provider/transform.test.ts.rej
```

**Step 4: Typecheck must pass now**

```bash
bun --cwd packages/opencode typecheck
```

Expected: exit code 0, no errors. **Do not proceed until this passes.**

**Step 5: Run the caching test specifically**

```bash
bun --cwd packages/opencode test test/provider/transform.test.ts 2>&1 | tail -30
```

Expected: tests pass. If a test fails with a meaningful assertion error (not a type or import error), that's a signal the behavior port isn't quite right — go back to the relevant Task.

---

### Task 7: Regenerate patch file from clean diff

**Step 1: Stage all modified/new files**

```bash
cd /tmp/opencode-refresh/opencode-v1.14.18
git add -A
git status --short
```

Expected: the staged set matches the files the original patch touched (config/config.ts M, provider/config.ts A, provider/transform.ts M, session/prompt.ts M, test/provider/config.test.ts A, test/provider/transform.test.ts M).

**Step 2: Commit locally (not pushed anywhere — this is just to create a diff base)**

```bash
git commit -m "caching: rebased onto v1.14.18"
```

**Step 3: Regenerate patch**

```bash
git diff v1.14.18..HEAD -- . ':(exclude)packages/web/' > ~/projects/opencode-cached/patches/caching.patch
```

The `packages/web/` exclusion matches existing convention (opencode-patched's drift-detection also excludes it).

**Step 4: Sanity-check patch size**

```bash
wc -l ~/projects/opencode-cached/patches/caching.patch
```

Expected: roughly the same order of magnitude as the prior patch (2140 lines ± several hundred). If it's drastically different (e.g., 500 lines or 10000), something went wrong.

---

### Task 8: Validate by re-applying from scratch + typecheck

**Step 1: Fresh upstream clone**

```bash
rm -rf /tmp/opencode-refresh/opencode-v1.14.18-fresh
cd /tmp/opencode-refresh
git clone --depth 1 --branch v1.14.18 https://github.com/anomalyco/opencode.git opencode-v1.14.18-fresh
```

**Step 2: Apply the regenerated patch**

```bash
cd /tmp/opencode-refresh/opencode-v1.14.18-fresh
~/projects/opencode-cached/patches/apply.sh .
```

Expected: prints `Patch applied successfully. Modified files:` followed by git status showing the expected file set. No error.

**Step 3: Typecheck in the fresh checkout**

```bash
bun install
bun --cwd packages/opencode typecheck
```

Expected: exit code 0.

**Step 4: Run caching tests**

```bash
bun --cwd packages/opencode test test/provider/transform.test.ts test/provider/config.test.ts 2>&1 | tail -30
```

Expected: all pass.

---

### Task 9: Commit and push

**Step 1: Review the patch change**

```bash
cd ~/projects/opencode-cached
git diff patches/caching.patch | head -60
git status
```

**Step 2: Commit**

```bash
git add patches/caching.patch
git commit -m "fix: rebase caching patch onto v1.14.18"
```

**Step 3: Pull/rebase and push**

```bash
git pull --rebase
git push
```

---

### Task 10: Trigger build workflow and watch to success

**Step 1: Trigger the build**

```bash
gh workflow run build-release.yml \
  --repo johnnymo87/opencode-cached \
  --field version=1.14.18
```

**Step 2: Watch the run**

```bash
# Wait a moment for the run to register, then:
RUN_ID=$(gh run list --repo johnnymo87/opencode-cached --workflow build-release.yml --limit 1 --json databaseId -q '.[0].databaseId')
gh run watch "$RUN_ID" --repo johnnymo87/opencode-cached
```

Expected: all 4 platform build jobs succeed. The job also creates release `v1.14.18-cached` with all 4 assets.

**If the build fails:**

- Read the failed step with `gh run view "$RUN_ID" --repo johnnymo87/opencode-cached --log-failed | tail -100`.
- Most likely causes: patch doesn't apply cleanly in CI (check Task 8 was actually green), typecheck error, test failure, darwin smoke-test failure.
- If the failure is real: go back and fix the patch, push again, re-run workflow.
- If the failure is CI-env-specific (rare): open an issue in opencode-cached with the log, decide whether to patch the workflow or the patch.

**Step 3: Verify the release**

```bash
gh release view v1.14.18-cached --repo johnnymo87/opencode-cached
```

Expected: release exists with 4 `.tar.gz`/`.zip` assets.

---

### Task 11: Close blocker issues, close beads task

**Step 1: Close the outstanding build-failure issues**

All 10 "Release blocked" issues in `opencode-cached` (for v1.4.4 through v1.14.17) are now stale — this refresh skips past them to v1.14.18.

```bash
# List them:
gh issue list --repo johnnymo87/opencode-cached --label build-failure --state open --json number,title

# Close each with a reference to the resolving release:
for N in $(gh issue list --repo johnnymo87/opencode-cached --label build-failure --state open --json number -q '.[].number'); do
  gh issue close "$N" --repo johnnymo87/opencode-cached --comment "Superseded by v1.14.18-cached release."
done
```

**Step 2: Update beads**

```bash
cd ~/projects/workstation
bd close workstation-5k6 --reason "v1.14.18-cached released"
bd sync
```

---

## Gotchas to Watch For

- **`packages/web/` drift**: If your regenerated patch accidentally includes changes to `packages/web/`, the `opencode-patched` drift-detection script will alert falsely. Always use the `:(exclude)packages/web/` filter when regenerating.
- **Patch format sensitivity**: `git diff` produces different patches depending on `core.pager` and `diff.*` config. This repo has no custom `.gitattributes` that would affect this, but if the CI's `git apply` behaves differently from local, check `git diff`'s exact output format.
- **Bun version mismatch between local and CI**: local `bun` version may differ from CI's `bun-version: latest`. Typecheck is stable across versions; tests may not be. If tests pass locally but fail in CI, inspect the CI Bun version.
- **Apple Silicon signing**: irrelevant here. Cached's darwin build uses the same signing workflow as patched; if darwin smoke test fails, see the `@darwin-signing` skill in `opencode-patched/.opencode/skills/darwin-signing.md`.
- **Upstream re-released the same tag**: unlikely but possible. If `git clone --branch v1.14.18` yields a different SHA than an earlier run, redo Tasks 1–8.

---

## Fallback to v1.14.17

If v1.14.18 proves unusually difficult to rebase against (e.g., a late-stage refactor breaks a whole subsystem), fall back to v1.14.17:

1. Substitute `1.14.17` for `1.14.18` in every command in this plan.
2. Update the beads task notes explaining the fallback.
3. Update the design doc's "Target version" decision.
4. Proceed as normal. The upstream changelog between v1.14.17→v1.14.18 is minimal ("Restore native ripgrep backend").

---

## Definition of Done

- `patches/caching.patch` on `main` applies cleanly to upstream v1.14.18.
- `gh release view v1.14.18-cached --repo johnnymo87/opencode-cached` returns a release with 4 assets.
- beads `workstation-5k6` status is `closed`.
- All `build-failure`-labeled issues in `opencode-cached` are closed.
