# UI

- Use the local Liquid Glass facade at `lib/src/ui/` (barrel `package:pinboard_wizard/src/ui/ui.dart`) for widgets, colors, and typography. It wraps `liquid_glass_widgets` and provides local shims (window shell, sidebar, tabs, radio, checkbox, tooltip, alert dialog, sheet) for controls the library lacks. Glass is for chrome; content lists stay opaque.

# State Management

- For simple state handling , local state in a stateful wdiget is ok, for anything more complex, extract out into a cubit. Cubits are tested in the test foler.
