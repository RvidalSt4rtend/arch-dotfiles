return {
  'olimorris/onedarkpro.nvim',
  priority = 1000,
  config = function()
    require('onedarkpro').setup {
      highlights = {
        ['@include.python'] = { fg = '${yellow}', style = 'NONE' }, -- Sets yellow color, no italic/bold
      },
      -- Other options here if needed
    }
    vim.cmd 'colorscheme onedark'
  end,
}
