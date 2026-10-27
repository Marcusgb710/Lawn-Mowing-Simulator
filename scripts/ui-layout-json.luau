-- Prints where everything on the play screen goes (src/client/UiLayout.luau) as JSON, with the
-- elements' names as keys, for the layout editor to start from:
--   lune run scripts/ui-layout-json > ui-layout.json
-- `__screen` is how the screens work (the ScreenGuis, touch, what scales to fit), not an element.

local serde = require("@lune/serde")

local UiLayout = require("../src/client/UiLayout")

print(serde.encode("json", UiLayout, true))
