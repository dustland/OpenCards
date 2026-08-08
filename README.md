# OpenCards

OpenCards is a Godot 4.7 card game.

## Run

Open this repository in Godot 4 and press Play. The main scene is `scenes/main.tscn`.

The playable flow is Deck Builder, opening-hand Mulligan, player-versus-AI Match, and Result. Choose a difficulty and use **Start Battle** when the starter deck is ready. AI opponents support Easy, Standard, and Hard difficulties. Result supports a rematch with the same complete player deck and difficulty or a return to Deck Builder with the current in-memory deck still selected. The starter cards use original generated illustrations in `game_assets/generated_cards/`; other source assets are kept under `game_assets/`.

During a match, the objective bar follows the current legal actions. Gold-bordered cards are legal, the brighter border marks the selected card, and unavailable cards explain why they cannot be played. The turn header announces whose turn it is (`YOUR TURN` / `OPPONENT'S TURN`), and the player strip shows HQ, hand, deck, and discard counts so fatigue risk is always visible. Credit starts at 1 and grows by one slot each turn. Units deploy into fixed Support Line columns, then move into the aligned five-column Frontline before attacking highlighted units or Headquarters. The four-card Support Lines reserve the fifth grid cell, while Headquarters remain outside the battlefield grid and hand cards keep fixed spacing. Accepted draws, deployments, moves, attacks, damage, destruction, Orders, and Countermeasures animate in event order, with the moving card's title and category tint shown on the motion proxy so opponent actions are easy to follow. Use **Animation: Reduced** for brief opacity feedback instead of full card motion. When no other action is legal, the objective directs you to **End Turn**. **Concede** forfeits the match (with a confirmation prompt) and routes to Result. Completed deploy, move, and attack lessons and the animation preference persist across rematches.

### Controls

- Mouse: select highlighted cards and targets, drag cards to highlighted legal zones, and activate commands.
- Enter or Space: activate the primary command where supported, including Play, confirm, and Rematch.
- Escape: clear the current Match selection or return from Result to Deck Builder.
- E: end the player turn when End Turn is legal.
- Concede button: forfeit the match (confirmation required); only available on your turn.

## Validate

With Godot 4 installed, run the focused validation commands:

```sh
godot --headless --path . --script tests/data_validation.gd
godot --headless --path . --script tests/test_suite.gd
sh tests/ui/run_task6.sh
godot --path . --script tests/capture_ui.gd
godot --headless --path . --script tests/run_ai_match.gd -- 90210 standard hard 300
```

The strict Task6 runner covers Result contracts and the complete Deck Builder -> Mulligan -> Match -> Result -> Rematch/Builder flow at 1280x720 and true 1024x720. It rejects runtime and teardown diagnostics except the exact known macOS headless system-CA lookup failure. The capture command writes five deterministic UI captures to ignored `builds/qa/`. The representative AI command must complete without illegal actions and reproduce its replay.

## Export

Export output is written under ignored `builds/`. The named `PCK` preset packages all project resources, including source data and generated card artwork:

```sh
godot --headless --path . --export-pack PCK builds/pck/OpenCards.pck
godot --headless --main-pack builds/pck/OpenCards.pck --script "$PWD/tests/verify_pck_manifest.gd"
```

The manifest check verifies required runtime files and all 12 generated card-art resources are packed while tests, documentation, legacy card art, unused backgrounds, and local build metadata are absent.

The `Web` preset targets Godot 4.7's Compatibility renderer without thread support, so it does not require cross-origin isolation. With matching Godot 4.7 export templates installed, create release builds with:

```sh
godot --headless --path . --export-release Web builds/web/index.html
godot --headless --path . --export-release macOS builds/macos/OpenCards.zip
```

Validate the GitHub Pages workflow and Web export preset without downloading dependencies:

```sh
sh tests/validate_web_deploy.sh
sh tests/test_web_deploy_validator.sh
```

To inspect a local Web export, serve it over HTTP after exporting and open the displayed local URL:

```sh
python3 -m http.server 8000 --directory builds/web
```

Pushes to `main` and manual runs of **Build Godot Web and Deploy to GitHub Pages** export the game to `builds/web/index.html` and deploy it through GitHub Pages.

### Custom domain

The production URL is <https://opencards.dustland.ai>. First verify the `dustland.ai` domain for the `lyuai` GitHub organization to reduce custom-domain takeover risk. Then configure `opencards.dustland.ai` in the repository under **Settings > Pages > Custom domain** before changing DNS. The DNS record must be:

```text
Type:  CNAME
Name:  opencards
Value: lyuai.github.io
```

After DNS propagation and GitHub certificate issuance, enable **Enforce HTTPS** in **Settings > Pages**. The Actions artifact intentionally does not include a `CNAME` file because the custom domain is managed in repository settings.

## Current limitations

- Matches are local player-versus-AI only; there is no network multiplayer.
- Replay data is retained on Result for verification but has no replay-browser UI.
- User deck changes remain in memory until Save is used in Deck Builder.
