# FiraCode font drop

The app renders with `Font.phosphor()` (see `App/Theme.swift`), which
prefers FiraCode and falls back to SF Mono if the font isn't
registered. To activate real FiraCode:

1. Download `FiraCode-Regular.ttf` from
   <https://github.com/tonsky/FiraCode/releases> (or use the variable
   `FiraCode-VF.ttf`).
2. Drop the file into this directory.
3. Add the file to `project.yml` under the `SlothIOS` target's
   `info.properties.UIAppFonts` array:

   ```yaml
   UIAppFonts:
     - FiraCode-Regular.ttf
   ```

4. `make generate` (or `xcodegen generate`) to rebuild the project,
   then `make build`.

`Font.phosphor()` auto-detects the registration via `UIFont(name:
"FiraCode-Regular", size:)` — no code change needed.

We don't ship the TTF in this repo to keep the source tree binary-free.
