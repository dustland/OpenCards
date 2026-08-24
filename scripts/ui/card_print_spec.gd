class_name CardPrintSpec
extends RefCounted

## Physical manufacturing reference for OpenCards poker/TCG cards.
## Digital catalog pixels are a preview; print masters use PRINT_PX at 300 DPI.

const TRIM_MM := Vector2(63.5, 88.9)
const BLEED_MM := 3.0
const SAFE_MM := 3.0

const CATALOG_PX := Vector2(180, 252)
const PRINT_PX := Vector2(750, 1050)
const PRINT_DPI := 300

const FRAME_TEXTURE := "res://game_assets/ui/card_frame.png"
const FOIL_MASK_TEXTURE := "res://game_assets/ui/card_frame_foil.png"

## Procedural frames are print-layout placeholders. Production physical decks
## should replace card_frame.png with commissioned border art while keeping
## the same trim (750×1050) and foil-mask workflow.
