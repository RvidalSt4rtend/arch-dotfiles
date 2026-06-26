return {
  'rebelot/kanagawa.nvim',
  name = 'kanagawa',
  priority = 1000, -- Para que cargue primero
  config = function()
    require('kanagawa').setup {
      compile = false,
      undercurl = true,
      commentStyle = { italic = true },
      keywordStyle = { italic = false },
      transparent = false,
      dimInactive = false,
      terminalColors = true,
      colors = {},
      overrides = function(colors)
        return {}
      end,
    }
    -- Para activar el tema:
    vim.cmd 'colorscheme kanagawa-dragon'
    -- Puedes usar: kanagawa-wave, kanagawa-dragon, kanagawa-lotus
  end,
}
