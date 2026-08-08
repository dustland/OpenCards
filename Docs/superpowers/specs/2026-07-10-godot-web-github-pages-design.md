# OpenCards Godot Web and GitHub Pages Design

**Date:** 2026-07-10
**Status:** Approved design, pending implementation plan
**Target:** https://opencards.dustland.ai

## Goal

Publish the complete OpenCards Godot 4.7 game as a browser-playable release from GitHub Actions. A push to `main` or a manual workflow dispatch must produce a reproducible Web build and deploy it through GitHub Pages without Unity tooling, license secrets, or a generated deployment branch.

## Current State

The repository is a Godot 4.7 GDScript project using the `gl_compatibility` renderer, which is compatible with Godot Web exports. The existing `.github/workflows/webgl-pages.yml` is a legacy Unity workflow that expects Unity 6000, Unity license secrets, `Assets`, `ProjectSettings`, and a `Web` wrapper. It cannot build the current project and will be replaced in place.

`export_presets.cfg` is not currently tracked on the gameplay branch. The final release work must add a deterministic Web preset alongside any retained native presets.

## Chosen Approach

Use GitHub Pages' native custom-workflow artifact deployment:

1. Check out the repository.
2. Download the pinned official Godot 4.7 Linux editor and matching export templates from the `godotengine/godot-builds` `4.7-stable` release.
3. Install the templates in the runner's Godot template directory.
4. Import the project and run the headless rules suite.
5. Export the `Web` release preset to `builds/web/index.html`.
6. Verify the required `.html`, `.js`, `.wasm`, and `.pck` files exist and contain no unexpected symbolic links.
7. Configure Pages, upload `builds/web` as the Pages artifact, and deploy it to the `github-pages` environment.

This avoids a mutable `gh-pages` branch and uses GitHub's supported `configure-pages`, `upload-pages-artifact`, and `deploy-pages` actions.

## Web Export

The Web preset will:

- export a release build named `index.html`;
- use the existing Compatibility renderer and WebGL 2;
- disable thread support, avoiding `SharedArrayBuffer` and cross-origin isolation header requirements on GitHub Pages;
- disable GDExtension support because the project is GDScript-only;
- use browser-window canvas resizing;
- export all project resources needed by the game;
- keep generated files under ignored `builds/web/`;
- avoid PWA mode initially so stale service-worker caches do not obscure deployments during active development.

The workflow will pin `GODOT_VERSION=4.7` and the `4.7-stable` official release URLs. Downloaded archives will be cached by version, while the project export itself will always be rebuilt.

## Workflow Structure

The replacement workflow keeps two jobs:

- `build`: read-only repository access, installs Godot, runs tests, exports Web, validates output, configures Pages, and uploads the artifact.
- `deploy`: depends on `build`, has `pages: write` and `id-token: write`, targets the `github-pages` environment, and exposes the deployment URL.

Triggers:

- `push` to `main`;
- `workflow_dispatch` for manual releases.

Concurrency uses one Pages deployment group with `cancel-in-progress: true`, so a newer `main` build replaces an obsolete queued deployment.

No project secret is required. The workflow uses the standard GitHub token and OIDC permissions expected by `deploy-pages`.

## Custom Domain

The GitHub organization is `lyuai`, so the DNS record is:

```text
Type:  CNAME
Name:  opencards
Value: lyuai.github.io
```

The repository administrator must configure `opencards.dustland.ai` under **Settings > Pages > Custom domain**. With an Actions-based Pages source, the custom domain is repository configuration; a generated `CNAME` file is not required and GitHub documents that existing `CNAME` files are ignored for custom workflows.

The domain should be verified for the `lyuai` GitHub organization before DNS is switched to reduce takeover risk. After DNS propagation and certificate issuance, **Enforce HTTPS** must be enabled. DNS propagation and certificate issuance are external states and may take time.

## Failure Handling

The build fails before deployment when:

- the official editor or templates cannot be downloaded or unpacked;
- the headless rules suite fails;
- the `Web` export preset is missing or Godot export fails;
- `index.html`, JavaScript, WebAssembly, or PCK output is absent;
- the Pages artifact upload fails.

The deployment job cannot run after a failed build. GitHub's environment records the last successful deployment URL and status.

## Verification

Local and CI verification will include:

- `godot --headless --path . --script tests/test_suite.gd`;
- `godot --headless --path . --export-release Web builds/web/index.html`;
- output manifest checks for HTML, JS, WASM, and PCK;
- a local static HTTP server smoke test;
- Playwright loading the exported page at desktop and mobile viewports;
- checks that the Godot canvas is nonblank, the page has no fatal console errors, and a basic menu-to-match interaction works;
- after deployment, an HTTPS smoke request to `https://opencards.dustland.ai`.

The custom-domain smoke check may be reported as pending until DNS and GitHub Pages settings are active; this does not weaken local export or artifact validation.

## Non-Goals

- Multiplayer servers or authoritative online matches.
- PWA/offline installation in the first Web release.
- Threaded Web exports or custom cross-origin headers.
- Maintaining a separate `gh-pages` branch.
- Reusing legacy Unity wrappers or Unity license secrets.
