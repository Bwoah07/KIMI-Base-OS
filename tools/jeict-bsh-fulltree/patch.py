from pathlib import Path
import re

ROOT = Path("JEI-Crafting-Tree")
screen_path = ROOT / "src/main/java/com/lhy/jeict/client/RecipeTreeOverviewScreen.java"
lang_path = ROOT / "src/main/resources/assets/jeict/lang/en_us.json"
props_path = ROOT / "gradle.properties"

src = screen_path.read_text(encoding="utf-8")

# The upstream v0.0.3 tag contains several mojibake glyph literals that break javac when
# checked out on the Linux builder. Normalize only those known UI-only lines to ASCII.
ui_literal_fixes = [
    (
        r'^\s*this\.zoomOutButton = chromeButton\(this\.width - 180, 8, 22, 20, Component\.literal\(.*$',
        '        this.zoomOutButton = chromeButton(this.width - 180, 8, 22, 20, Component.literal("-"), btn -> zoomAtCenter(-0.1D));',
        'zoom-out',
    ),
    (
        r'^\s*this\.settingsButton = chromeButton\(this\.width - 34, 8, 26, 20, Component\.literal\(.*$',
        '        this.settingsButton = chromeButton(this.width - 34, 8, 26, 20, Component.literal("..."), btn -> {',
        'settings',
    ),
    (
        r'^\s*graphics\.drawCenteredString\(this\.font, .*endX, Math\.max\(midY, endY - 11\), theme\.danger\(\)\);$',
        '                    graphics.drawCenteredString(this.font, "!", endX, Math.max(midY, endY - 11), theme.danger());',
        'cycle-marker-edge',
    ),
    (
        r'^\s*graphics\.drawCenteredString\(this\.font, .*centerX, rowY - 14, theme\.danger\(\)\);$',
        '                    graphics.drawCenteredString(this.font, "!", centerX, rowY - 14, theme.danger());',
        'cycle-marker-row',
    ),
    (
        r'^\s*graphics\.drawString\(this\.font, .*currentX \+ width - 9, y \+ 2, theme\.danger\(\), false\);$',
        '                    graphics.drawString(this.font, "!", currentX + width - 9, y + 2, theme.danger(), false);',
        'cycle-marker-material',
    ),
    (
        r'^\s*graphics\.drawString\(this\.font, .*x \+ width - 9, y \+ 2, theme\.danger\(\), false\);$',
        '            graphics.drawString(this.font, "!", x + width - 9, y + 2, theme.danger(), false);',
        'cycle-marker-generic',
    ),
    (
        r'^\s*String ellipsis = .*;$',
        '        String ellipsis = "...";',
        'ellipsis',
    ),
]
for regex, replacement_line, label in ui_literal_fixes:
    src, fixed = re.subn(regex, replacement_line, src, count=1, flags=re.M)
    if fixed != 1:
        raise SystemExit(f"Could not normalize upstream UI literal: {label} count={fixed}")

# We use the registry id of an item for safe terminal/base-material rules.
needle = "import net.minecraft.ChatFormatting;\n"
if "import net.minecraft.core.registries.BuiltInRegistries;" not in src:
    src = src.replace(needle, needle + "import net.minecraft.core.registries.BuiltInRegistries;\n", 1)

pattern = re.compile(
    r"    private Optional<RecipeTreeRecipeViewModel> resolveUniqueEncodableRecipe\(String focusSignature, ITypedIngredient<\?> focus\) \{.*?\n    \}\n\n    private record CachedInputSignature",
    re.S,
)

replacement = r'''    /**
     * BSH Full Tree resolver.
     *
     * The upstream resolver only expands when JEI exposes exactly one encodable recipe. In large
     * modpacks that stops almost immediately because the same component often has several valid
     * routes. This resolver keeps the existing recursive engine, but chooses a conservative sane
     * route automatically:
     *  - raw/base materials are terminal leaves;
     *  - obvious compression/decompression/storage conversions are rejected;
     *  - structured crafting recipes are preferred over machine processing;
     *  - recipes from the output item's own namespace are preferred;
     *  - ambiguous equal-best choices are left unresolved instead of guessing.
     */
    private Optional<RecipeTreeRecipeViewModel> resolveUniqueEncodableRecipe(String focusSignature, ITypedIngredient<?> focus) {
        if (focusSignature == null || focusSignature.isBlank()) {
            return Optional.empty();
        }
        Optional<RecipeTreeRecipeViewModel> cached = autoExpandUniqueCandidateCache.get(focusSignature);
        if (cached != null) {
            return cached;
        }

        if (isBshTerminalMaterial(focus)) {
            autoExpandUniqueCandidateCache.put(focusSignature, Optional.empty());
            return Optional.empty();
        }

        List<RecipeTreeRecipeViewModel> recipes = RecipeTreeJeiLookup.findRecipesByOutput(focus);
        RecipeTreeRecipeViewModel best = null;
        int bestScore = Integer.MIN_VALUE;
        boolean tied = false;

        for (RecipeTreeRecipeViewModel recipe : recipes) {
            if (recipe.inputs().isEmpty() || !isRecipeSnapshotStrictEncodable(recipe)
                    || isBshBadConversionRecipe(recipe)) {
                continue;
            }
            int score = scoreBshRecipe(recipe, focus);
            if (score > bestScore) {
                best = recipe;
                bestScore = score;
                tied = false;
            } else if (score == bestScore && best != null && !best.sameRecipeAs(recipe)) {
                tied = true;
            }
        }

        // Never make a random choice when two genuinely different routes are equally plausible.
        Optional<RecipeTreeRecipeViewModel> resolved = tied ? Optional.empty() : Optional.ofNullable(best);
        autoExpandUniqueCandidateCache.put(focusSignature, resolved);
        return resolved;
    }

    private boolean isBshTerminalMaterial(ITypedIngredient<?> focus) {
        Object raw = focus == null ? null : focus.getIngredient();
        if (!(raw instanceof ItemStack stack) || stack.isEmpty()) {
            return false;
        }
        ResourceLocation id = BuiltInRegistries.ITEM.getKey(stack.getItem());
        if (id == null) {
            return false;
        }
        String path = id.getPath().toLowerCase(java.util.Locale.ROOT);

        // Things we normally acquire/grow/mine/process in bulk rather than recursively craft from
        // reversible storage recipes. This is deliberately conservative; anything not matched here
        // can still expand normally.
        if (path.startsWith("raw_") || path.endsWith("_ore") || path.endsWith("_ingot")
                || path.endsWith("_nugget") || path.endsWith("_dust") || path.endsWith("_gem")
                || path.endsWith("_crystal") || path.endsWith("_shard") || path.endsWith("_log")
                || path.endsWith("_wood") || path.endsWith("_stem") || path.endsWith("_hyphae")) {
            return true;
        }

        return switch (path) {
            case "redstone", "coal", "charcoal", "diamond", "emerald", "lapis_lazuli",
                    "quartz", "amethyst_shard", "flint", "clay_ball", "sand", "red_sand",
                    "gravel", "cobblestone", "stone", "deepslate", "dirt", "obsidian",
                    "glass", "silicon" -> true;
            default -> false;
        };
    }

    private boolean isBshBadConversionRecipe(RecipeTreeRecipeViewModel recipe) {
        ResourceLocation id = recipe.recipeId();
        if (id != null) {
            String ns = id.getNamespace().toLowerCase(java.util.Locale.ROOT);
            String path = id.getPath().toLowerCase(java.util.Locale.ROOT);
            if (ns.equals("allthecompressed") || ns.contains("compressed")
                    || path.contains("decompress") || path.contains("uncompress")
                    || path.contains("decompact") || path.contains("unpack")
                    || path.contains("compressed") || path.contains("compression")
                    || path.contains("from_storage_block") || path.contains("storage_block_to")
                    || path.contains("ingot_from_block") || path.contains("nugget_from_ingot")
                    || path.endsWith("_from_block")) {
                return true;
            }
        }

        // Generic fallback: one block/compressed input exploding into many outputs is almost always
        // a reverse-storage recipe, not a dependency we want in an autocrafting tree.
        if (recipe.inputs().size() == 1 && recipe.primaryOutputAmount() > 1L) {
            ItemStack input = recipe.inputs().getFirst().displayStack();
            if (!input.isEmpty()) {
                ResourceLocation inputId = BuiltInRegistries.ITEM.getKey(input.getItem());
                if (inputId != null) {
                    String p = inputId.getPath().toLowerCase(java.util.Locale.ROOT);
                    if (p.contains("compressed") || p.endsWith("_block") || p.contains("storage_block")) {
                        return true;
                    }
                }
            }
        }
        return false;
    }

    private int scoreBshRecipe(RecipeTreeRecipeViewModel recipe, ITypedIngredient<?> focus) {
        int score = 0;
        CraftingTreeBackend backend = CraftingTreeBackends.get();
        PatternEncodingMode mode = backend == null ? PatternEncodingMode.PROCESSING : backend.patternMode(recipe);
        score += switch (mode) {
            case CRAFTING -> 1000;
            case SMITHING_TABLE -> 850;
            case STONECUTTING -> 750;
            case PROCESSING -> 200;
        };

        if (recipe.primaryOutputAmount() == 1L) score += 40;
        if (recipe.inputs().size() > 1) score += 30 + Math.min(20, recipe.inputs().size());
        else score -= 10;

        ResourceLocation recipeId = recipe.recipeId();
        ResourceLocation focusId = bshItemId(focus);
        if (recipeId != null && focusId != null && recipeId.getNamespace().equals(focusId.getNamespace())) {
            score += 80;
        }
        return score;
    }

    private @Nullable ResourceLocation bshItemId(@Nullable ITypedIngredient<?> ingredient) {
        Object raw = ingredient == null ? null : ingredient.getIngredient();
        if (!(raw instanceof ItemStack stack) || stack.isEmpty()) return null;
        return BuiltInRegistries.ITEM.getKey(stack.getItem());
    }

    private record CachedInputSignature'''

new_src, count = pattern.subn(replacement, src, count=1)
if count != 1:
    raise SystemExit("Could not locate resolveUniqueEncodableRecipe in v0.0.3 source")
screen_path.write_text(new_src, encoding="utf-8")

# Rename the existing Unique toggle in English so the custom behavior is obvious in game.
lang = lang_path.read_text(encoding="utf-8")
replacements = {
    '"gui.jeict.recipe_tree.overview_auto_unique_short_enabled": "Unique: On"':
        '"gui.jeict.recipe_tree.overview_auto_unique_short_enabled": "Full: On"',
    '"gui.jeict.recipe_tree.overview_auto_unique_short_disabled": "Unique: Off"':
        '"gui.jeict.recipe_tree.overview_auto_unique_short_disabled": "Full: Off"',
    '"gui.jeict.recipe_tree.overview_auto_unique_enabled": "Unique recipe: On"':
        '"gui.jeict.recipe_tree.overview_auto_unique_enabled": "Full recursive: On"',
    '"gui.jeict.recipe_tree.overview_auto_unique_disabled": "Unique recipe: Off"':
        '"gui.jeict.recipe_tree.overview_auto_unique_disabled": "Full recursive: Off"',
    '"gui.jeict.recipe_tree.overview_auto_unique_tooltip": "When enabled, unresolved branches that have exactly one usable JEI recipe expand automatically."':
        '"gui.jeict.recipe_tree.overview_auto_unique_tooltip": "BSH Full Tree: recursively expands sane missing dependencies, stops at base materials/existing patterns, rejects compression/storage reversals, and leaves true ambiguities for manual choice."',
}
for old, new in replacements.items():
    if old not in lang:
        raise SystemExit(f"Missing expected language string: {old}")
    lang = lang.replace(old, new, 1)
lang_path.write_text(lang, encoding="utf-8")

props = props_path.read_text(encoding="utf-8")
props = props.replace("mod_version=0.0.3", "mod_version=0.0.3-bsh1", 1)
props = props.replace("mod_name=JEI Crafting Tree", "mod_name=JEI Crafting Tree BSH Full Tree", 1)
props_path.write_text(props, encoding="utf-8")

print("BSH Full Tree patch applied")
