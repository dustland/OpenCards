class_name CardPrintSpec
extends RefCounted

## Physical manufacturing reference — metal / acrylic engraved cards.
## Digital catalog pixels are preview; print masters use PRINT_PX at 300 DPI.

const TRIM_MM := Vector2(63.5, 88.9)
const BLEED_MM := 3.0
const SAFE_MM := 3.0
const TYPICAL_THICKNESS_MM := 0.8

const CATALOG_PX := Vector2(180, 252)
const PRINT_PX := Vector2(750, 1050)
const PRINT_DPI := 300

const FRAME_TEXTURE := "res://game_assets/ui/card_frame.png"
const FOIL_MASK_TEXTURE := "res://game_assets/ui/card_frame_foil.png"

enum Material { ANODIZED_ALUMINUM, ACRYLIC, STAINLESS }

## Laser/CNC groove depths for quoting with fabricators (mm).
const ENGRAVE_HAIRLINE_MM := 0.08
const ENGRAVE_TEXT_MM := 0.12
const ENGRAVE_ART_CHANNEL_MM := 0.25
const ENGRAVE_STAT_WELL_MM := 0.30

## card_frame_foil.png marks edge glint zones → secondary polish (metal) or white ink (acrylic).
