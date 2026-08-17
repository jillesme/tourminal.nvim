# tourminal.nvim

Follow [Microsoft CodeTour](https://github.com/microsoft/codetour) walkthroughs in Neovim. Tourminal opens real source buffers, moves to each resolved location, highlights the active line or selection, and shows the Markdown explanation beside the code.

Tour discovery and resolution come from the [`tour`](https://github.com/jillesme/tourminal) executable, so the terminal and Neovim players agree on patterns, platform conditions, Git refs, marker-based steps, linked tours, and workspace safety.

## Requirements

- Neovim 0.10+
- Tourminal 0.1.4+ installed and available as `tour`

On macOS or Linux:

```sh
brew install jillesme/tap/tourminal
```

After installation, run `:checkhealth tourminal` in Neovim.

## Install

With lazy.nvim:

```lua
{
  "jillesme/tourminal.nvim",
  version = "*",
  cmd = { "Tour", "TourNext", "TourPrev", "TourSteps", "TourResume", "TourReload", "TourStop" },
  opts = {},
}
```

Defaults work without calling `setup()`. To customize the player:

```lua
require("tourminal").setup({
  tour_command = "tour",
  note = {
    width = 72,
    max_height = 18,
    border = "rounded",
    winblend = 0,
  },
})
```

## Follow a tour

Run `:Tour` from a repository containing CodeTours. If more than one tour is available, the plugin uses `vim.ui.select`, so Telescope, snacks.nvim, dressing.nvim, and other UI replacements can provide the picker.

| Command | Action |
| --- | --- |
| `:Tour [path]` | Start a tour in the current workspace or at a path |
| `:TourNext` | Move to the next step |
| `:TourPrev` | Move to the previous step |
| `:TourSteps` | Choose a step |
| `:TourResume` | Return to the current step |
| `:TourReload` | Reload tours from disk |
| `:TourStop` | End the tour |

The Markdown window has buffer-local `n`, `p`, `g`, `r`, and `q` mappings for these actions. On a URI step, `o` explicitly opens the URI. The plugin does not install global mappings.

For a statusline component:

```lua
require("tourminal").statusline()
```

## Safety

Tour-provided commands and VS Code views are informational and are never executed. URIs only open after pressing `o`. File paths and pattern anchors are resolved by Tourminal with the same containment and input-size checks used by the terminal player.

## Scope

This first version follows tours. Recording and editing tours, remote tour fetching, interactive CodeTour-flavored links, and automatic project prompts are intentionally out of scope.

## License

MIT
