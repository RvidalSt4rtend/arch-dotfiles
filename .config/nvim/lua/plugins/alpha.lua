return {
  'goolord/alpha-nvim',
  dependencies = {
    'nvim-tree/nvim-web-devicons',
  },

  config = function()
    local alpha = require 'alpha'
    local dashboard = require 'alpha.themes.startify'
    dashboard.section.header.val = {
      [[                                                                    ]],
      [[      _____ __             __  ______           __                 ]],
      [[     / ___// /_____ ______/ /_/ ____/___  ____/ /                 ]],
      [[     \__ \/ __/ __ `/ ___/ __/ __/ / __ \/ __  /                  ]],
      [[    ___/ / /_/ /_/ / /  / /_/ /___/ / / / /_/ /                   ]],
      [[   /____/\__/\__,_/_/   \__/_____/_/ /_/\__,_/                    ]],
      [[                                                                    ]],
    }

    alpha.setup(dashboard.opts)
  end,
}
