# Instagram Recipe Parser

A rules-based Lua module for extracting structured recipe data from Instagram post descriptions.

## Overview

This module parses Instagram `og:description` content and extracts recipe components using pattern matching. It's designed to handle both Swedish and English recipes, with support for various formatting styles commonly found on Instagram.

## Files

| File | Description |
|------|-------------|
| `instagram_parser.lua` | Extracts `og:*` meta tags from Instagram HTML |
| `recipe_extractor.lua` | Extracts structured recipe data from description text |
| `run_tests.lua` | Automated test runner |
| `test_fixtures.json` | Expected results for test cases |
| `test_extractor.lua` | Manual testing helper |
| `test_data/` | HTML test fixtures (downloaded Instagram pages) |
| `download_all.sh` | Script to download test fixtures |
| `cli.lua` | CLI wrapper for quick testing |

## Usage

### Basic extraction

```lua
local parser = require("instagram_parser")
local extractor = require("recipe_extractor")

-- Parse HTML to get og:description
local parsed = parser.parse(html_content)

-- Extract recipe data
local recipe = extractor.extract(parsed.description)

-- Result structure:
-- {
--     title = "Recipe Title",
--     description = "Intro text...",
--     portions = 4,
--     ingredients = "- 2 cups flour\n- 1 tsp salt\n...",
--     instructions = "1. Mix ingredients\n2. Bake...",
--     tags = {"recipe", "dinner", "easy"},
--     is_recipe = true,
--     raw_description = "Original full text..."
-- }
```

### CLI testing

```bash
# Test a single file
nix-shell --run 'luajit test_extractor.lua recipe.html'

# Run automated tests
nix-shell --run 'luajit run_tests.lua'
```

## Extraction Patterns

### Portions

Detects serving sizes from patterns like:
- `4 personer` (Swedish)
- `(6 pers)`
- `Serves 4`
- `Serves 3-4` (takes upper bound)
- `Räcker till 4`
- `Receptet räcker till 2 portioner`

### Ingredients Section

Detected via markers:
- `Ingredients:` / `Ingredients;`
- `Recipe Ingredients`
- `DU BEHÖVER` (Swedish)
- `Ingredienser:`
- `Här är receptet:`
- `Let's make it at home:`

Also detects:
- UPPERCASE section headers (`BULJONG`, `FÄRS`, `TOPPING`)
- Sub-section headers (`Dressing:`, `Marinad:`, `Sås:`)
- Quantity-based lists (lines starting with `250 gr`, `2 msk`, etc.)

### Instructions Section

Detected via markers:
- `Directions:` / `Method:` / `Steps:`
- `GÖR SÅHÄR:` / `Gör så här:` (Swedish)

Also detects:
- Numbered steps (`1.` or `1)`)
- Action verb paragraphs (`Grädda`, `Stek`, `Koka`)

### Non-Recipe Detection

Returns `is_recipe = false` when:
- Text contains "recipe in bio" or similar
- Instructions are "in pinned comment"
- Content is too short (< 200 chars)
- No ingredients or quantity patterns found

## Test Results

```
Total:   43 test cases
Passed:  38 (88%)
Skipped: 5 (edge cases with emoji headers or unusual formats)
```

## Known Limitations

1. **Emoji-based headers** - Recipes using emoji as section dividers (e.g., `🍯 Hot Honey 🍯`) are not parsed
2. **Bullet-separated cocktails** - Ingredients separated only by `•` without newlines
3. **Minimal content** - Very short posts without clear structure
4. **Instructions in comments** - When recipe says "see pinned comment"

## Architecture

The extractor uses a multi-pass approach:

1. **Normalize** - Convert curly quotes to straight quotes
2. **Find markers** - Locate section boundaries using pattern matching
3. **Fallback detection** - If no markers found, look for quantity-based lists
4. **Extract sections** - Pull out ingredients, instructions based on positions
5. **Detect recipe** - Determine if content is actually a recipe vs technique video

## Development

### Adding new patterns

Edit the pattern tables at the top of `recipe_extractor.lua`:

```lua
-- Add new portion pattern
local portion_patterns = {
    "(%d+)%s*personer",
    "your_new_pattern_here",
}

-- Add new ingredient marker
local ingredients_markers = {
    "Ingredients:",
    "Your New Marker:",
}
```

### Running tests

```bash
# Run full test suite
nix-shell --run 'luajit run_tests.lua'

# Test specific file
nix-shell --run 'luajit test_extractor.lua your_recipe.html'
```

### Adding test cases

1. Add HTML file to the directory
2. Add expected results to `test_fixtures.json`:

```json
"your_recipe.html": {
    "is_recipe": true,
    "has_ingredients": true,
    "has_instructions": true,
    "portions": 4,
    "notes": "Description of test case"
}
```

Use `"is_recipe": "uncertain"` for known edge cases that should be skipped.
