from pathlib import Path
import re

path = Path("JEI-Crafting-Tree/src/main/java/com/lhy/jeict/client/RecipeTreeOverviewScreen.java")
src = path.read_text(encoding="utf-8")

# In the v0.0.3 tag a mojibake comment swallowed this declaration onto the end of a // line.
# Restore it as executable Java if there is no active declaration.
active_decl = re.search(
    r'^\s*Map<String, List<ItemTopMaterialAccumulator>> normalizedItemGroups = new LinkedHashMap<>\(\);\s*$',
    src,
    flags=re.M,
)
if not active_decl:
    needle = '        for (Map.Entry<String, ItemTopMaterialAccumulator> entry : itemMaterials.entrySet()) {'
    replacement = (
        '        Map<String, List<ItemTopMaterialAccumulator>> normalizedItemGroups = new LinkedHashMap<>();\n'
        + needle
    )
    if needle not in src:
        raise SystemExit("Could not locate itemMaterials loop for normalizedItemGroups repair")
    src = src.replace(needle, replacement, 1)

path.write_text(src, encoding="utf-8")
print("v0.0.3 swallowed declaration repair applied")
