# Visual Regression Tests

Pixel-exact baseline tests for every page in the app. 57 `lib/screens/**/*_page.dart`
files mapped to 94 Golden PNGs under `test/goldens/screens/` (page renderings
plus state variants: Buy/Sell error banners, KYC loading/failure, Dashboard
with-balance, RestoreWallet valid/invalid, Legal-Disclaimer steps, etc.),
validated on each PR by the `Visual Regression` job (required status check
on `develop` + `main`).

## Stack

| Component | Choice |
|---|---|
| Framework | [alchemist](https://pub.dev/packages/alchemist) 0.14.0 (Betterment) |
| Font | Open Sans, eingecheckt unter `assets/fonts/` (SIL OFL 1.1) |
| Render host | Self-hosted macOS ARM64 runner — Labels `self-hosted, macOS, ARM64, m3-ultra, realunit-app` |
| Theme | `realUnitTheme` (light) aus `lib/styles/themes.dart` |
| CI job | `golden-tests` in `.github/workflows/pull-request.yaml` |

Baselines werden ausschliesslich auf dem self-hosted Runner generiert und validiert. Lokales
`flutter test test/goldens/` schlägt erwartet mit Pixel-Drift fehl
(unterschiedliche Mac-Hardware/macOS-Versionen rendern Sub-Pixel-AA leicht
anders).

## Layout

One test file per `lib/screens/<feature>/<feature>_page.dart` under
`test/goldens/screens/<feature>/<feature>_golden_test.dart`. Some pages
have multiple state variants (e.g. Welcome has iOS + Android theme,
Buy has initial + payment-info-loaded, Settings has default +
confirm-logout-sheet) — those produce more than one PNG each. All
baselines live under `test/goldens/screens/<feature>/goldens/macos/*.png`.

### Skipped: `web_view_page.dart`

The one `skip: true` in the suite. `InAppWebView` from `flutter_inappwebview` is a platform-view, not a regular widget — its rendering happens via the iOS/Android view-embedding API and has no headless representation in `flutter_test`.

Method-channel stubbing alone is **not enough**: the widget's first build asserts that `InAppWebViewPlatform.instance` is set, and that interface declares five abstract `createPlatform…` methods (controller, widget, cookie manager, etc.) — each returning another platform-view-bound class. A working stub would need ~50 lines of mock subclasses and would still render the body as a blank rectangle.

For a one-page edge case the cost/benefit doesn't justify it. The test is committed with `skip: true` and reactivates the moment someone wires up a full `InAppWebViewPlatform` mock — preferably published as a separate test-only package so other Flutter apps can reuse it.

## Regenerating baselines

Permanent on-demand workflow `.github/workflows/golden-regenerate.yaml`
runs `flutter test test/goldens --update-goldens` on the self-hosted runner and commits
the regenerated PNGs back to the dispatched branch as
`github-actions[bot]`. One command:

```bash
gh workflow run golden-regenerate.yaml --ref <feature-branch>
```

When the run finishes green, the new baselines are already on the
branch — pull and continue. No download / rsync / manual commit step.

The workflow is `workflow_dispatch`-only, runs on the same
`[self-hosted, macOS, ARM64, m3-ultra, realunit-app]` labels as
`golden-tests`, and uses concurrency `golden-regenerate-<ref>` so two
back-to-back dispatches on the same branch don't race each other.

**Gotcha — bot push does not trigger PR-CI.** GitHub Actions
deliberately suppresses workflow runs for pushes made by the default
`GITHUB_TOKEN` (the credential the bot uses), to avoid recursion loops.
Consequence: after the bot lands the regenerated baselines, the latest
SHA on the PR has **zero status checks** and `mergeStateStatus` flips
to `CLEAN` because no required checks remain to wait for — even though
`Analyze & Test` / `Visual Regression` / `Coverage Floor Gate` never
ran against the new baselines. To re-arm the CI, push an empty commit
signed by your own user:

```bash
git commit --allow-empty -m "ci: trigger workflows on bot regen"
git push
```

The required checks now run against the bot's baselines for real.
Without this step the merge button is misleading.

On a protected ref (`develop`, `main`) the push fails by design — no
force-push, no bypass. The same artifact-fallback also kicks in if a
parallel human push raced the bot (non-fast-forward); the workflow
does not retry-rebase. In either case the regenerated PNGs are uploaded
as the `golden-baselines` artifact; download and rsync them onto a
feature branch:

```bash
RUN_ID=$(gh run list --workflow=golden-regenerate.yaml --limit 1 --json databaseId --jq '.[0].databaseId')
gh run download "$RUN_ID" -n golden-baselines -D /tmp/baselines
rsync -a /tmp/baselines/ test/goldens/
git add test/goldens/
git commit -m "test(goldens): regenerate baselines on the self-hosted runner"
git push
```

## Day-to-day workflow

### Adding a new golden test

1. Add a `*_golden_test.dart` under `test/goldens/screens/<feature>/`.
   Reuse the mock pattern from the existing golden tests.
2. Open a Draft PR. The `golden-tests` job will be red because the new
   test has no committed baseline.
3. Run `gh workflow run golden-regenerate.yaml --ref <branch>`. The
   workflow regenerates on the self-hosted runner and pushes the PNGs back to the
   branch as `github-actions[bot]`. Pull and verify `golden-tests`
   goes green.

### Reacting to a CI drift

CI shows the `Run visual regression tests` step red and an artifact
`golden-diffs` is uploaded. Open the artifact and inspect the diff PNG:

* **Intentional change** (you redesigned the UI): regenerate baselines via
  `gh workflow run golden-regenerate.yaml --ref <branch>` (see
  "Regenerating baselines" above) and let the bot commit the new PNGs
  onto the branch.
* **Regression** (UI shouldn't have moved): fix the code; CI returns to
  green when pixels match again.

Never silently re-record baselines to make CI green — review the diff
visually first.

### Flutter SDK bumps

A Flutter bump (`flutter-version` in `.github/workflows/*.yaml`) changes
Skia's text shaper or layout subtly. Goldens become stale. On the bump
branch, dispatch the regenerate workflow:

```bash
gh workflow run golden-regenerate.yaml --ref <bump-branch>
```

The bot pushes `test(goldens): regenerate baselines on the self-hosted runner` onto the
branch; rename or amend the commit message locally if a more specific
"regenerate after Flutter X.Y.Z bump" note is useful.

### Self-hosted runner outage fallback

If the self-hosted runner is down (power, macOS update, service maintenance) and a PR is
blocked on `golden-tests`:

1. Switch `runs-on:` in `pull-request.yaml` for the `golden-tests` job —
   and in `golden-regenerate.yaml` — from `[self-hosted, ..., realunit-app]`
   to `macos-15`.
2. Dispatch the regenerate workflow on the branch to refresh all baselines
   on `macos-15`.
3. Merge. When the self-hosted runner is back up, flip `runs-on:` back in both workflows
   and regenerate baselines on the self-hosted runner in a separate PR.

This path is intentionally manual — it's a notfall, not a routine. The
flipping of baselines between two hosts incurs a mass-PNG-change PR each
direction.

### macOS update on the self-hosted runner

The Mac Studio M3 Ultra runs macOS — updates change Skia/CoreText
versions slightly. Before applying a macOS update on the self-hosted runner:

1. Prepare a regenerate-baselines PR.
2. Apply the macOS update.
3. Run the regenerate workflow, commit, push, merge.

## Architecture notes

### Why `realunit-app` not `realunit-ios` as runner label?

The label registered in `RealUnitCH/app` is `realunit-app`, not the
`realunit-ios` from the earlier Tier 3 Maestro plan. Goldens are headless Skia (no iOS Simulator), so an
`-ios`-suffixed label would be misleading. If the runner later picks up
Tier 3 Maestro work too (e.g. when the self-hosted runner capacity allows it), add the
`realunit-ios` label alongside the existing one — single runner, two
workload classes.

### Why pin Open Sans as an asset?

`lib/styles/text_styles.dart:4` declares `fontFamily: 'Open Sans'` but
the font was never an asset — Flutter fell back to the system font at
runtime. That fallback is not deterministic across macOS hosts. Goldens
require pixel-stable text rendering; the only honest fix is to ship the
font with the app. The 5 TTF variants (Regular, Italic, SemiBold, Bold,
BoldItalic) live under `assets/fonts/` with the SIL OFL 1.1 license file.

### Why self-hosted, not GitHub-hosted macos-15?

Performance (M3 Ultra ~2-3× faster than the GitHub macOS hosted runner)
and Hardware-Determinismus (identical Skia/CoreText/HW across runs —
no GitHub image bump can drift the baselines). The cost argument does
**not** apply — `RealUnitCH/app` is public, GitHub Actions on
public repos are free even for macOS minutes.

## Handbook screenshots are sourced from Goldens

The 299 PNGs the handbook serves at `handbook.realunit.app/screenshots/`
are assembled from the Golden baselines at docker-build time. One
Golden → one handbook page, via the explicit mapping in
`scripts/assemble-handbook-screenshots.sh`. The handbook does **not**
have its own screenshot set anymore.

### Why

- **Single source of truth.** A UI regression that flips a Golden also
  breaks the handbook image before either ships. The pixel-checked
  baseline IS the documentation.
- **Determinism.** The self-hosted runner's headless Skia/Open Sans render is byte-stable
  across CI runs. The previous Maestro-driven iOS-Simulator capture
  drifted on Apple Silicon + iOS 26 driver hangs
  (mobile-dev-inc/maestro#3137).
- **Cycle time.** The handbook image rebuilds when Goldens change in
  seconds. No 30-minute Maestro suite to refresh a page.

### Where each handbook page comes from

Authoritative mapping table lives in
`scripts/assemble-handbook-screenshots.sh` — one row per handbook slot
(only slots 01–26 have a companion `.maestro/handbook/*.yaml` smoke flow;
slots 27+ are golden-only). The script copies the
Golden into the output directory with the handbook's expected
`NN-name.png` filename; the Dockerfile multi-stage build then layers
that directory into `/usr/share/nginx/html/screenshots/`.

### When you add a new handbook page

1. Optionally add a `.maestro/handbook/<NN>-<name>.yaml` flow (only as
   navigation smoke, not as screenshot source — see Maestro section
   below for current PR-gate vs nightly status).
2. Add a Golden test under `test/goldens/screens/<screen>/` that
   renders the same UI state as the handbook flow's terminal screen.
3. Add a row to the `MAPPING` array in
   `scripts/assemble-handbook-screenshots.sh` pointing at the new
   Golden file.
4. Open the PR. The `Handbook Build Check` workflow runs
   `docker build` and a container smoke (`/healthz` + auth gate +
   `docker exec test -f` on every mapped `/screenshots/<NN>-*.png`). A missing Golden surfaces here
   as a missing-source error from the assembly script before docker
   even spins up.

### When you change an existing handbook page

Touch the Golden test (or the underlying widget/copy), let CI regenerate
the baseline on the self-hosted runner, and commit the new PNG. The handbook picks up
the change automatically on the next docker build — no separate
handbook-screenshot recapture step needed.

### Reviewing a handbook visual change

Pull the artifact or diff the PNG in `test/goldens/screens/**/` like
any other Golden review. There is no second set of handbook PNGs to
also check.
