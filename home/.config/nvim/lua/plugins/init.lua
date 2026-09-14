return {
	{
		"shaunsingh/nord.nvim",
		priority = 1000,
		config = function()
			vim.g.nord_contrast = true
			vim.g.nord_borders = true
			vim.cmd.colorscheme("nord")
		end,
	},

	{
		"nvim-lualine/lualine.nvim",
		dependencies = { "nvim-tree/nvim-web-devicons" },
		config = function()
			require("lualine").setup({ options = { theme = "nord" } })
		end,
	},

	{
		"nvim-tree/nvim-tree.lua",
		dependencies = { "nvim-tree/nvim-web-devicons" },
		config = function()
			require("nvim-tree").setup()
		end,
	},

	{
		"nvim-telescope/telescope.nvim",
		dependencies = { "nvim-lua/plenary.nvim" },
		config = function()
			require("telescope").setup()
		end,
	},

	{
		"nvim-treesitter/nvim-treesitter",
		build = ":TSUpdate",
		config = function()
			local ok, treesitter = pcall(require, "nvim-treesitter.configs")
			if not ok then
				return
			end
			treesitter.setup({
				highlight = { enable = true },
				indent = { enable = true },
				ensure_installed = {
					"lua",
					"vim",
					"vimdoc",
					"bash",
					"fish",
					"python",
					"javascript",
					"typescript",
					"html",
					"css",
					"json",
					"yaml",
					"markdown",
					"java",
					"sql",
				},
			})
		end,
	},

	{
		"windwp/nvim-autopairs",
		event = "InsertEnter",
		config = true,
	},

	{
		"numToStr/Comment.nvim",
		config = true,
	},

	{
		"lewis6991/gitsigns.nvim",
		config = true,
	},
	{
		"folke/which-key.nvim",
		event = "VeryLazy",
		opts = {},
	},
	{
		"stevearc/conform.nvim",
		event = { "VeryLazy" },
		cmd = { "ConformInfo" },
		keys = {
			{
				"<leader>fm",
				function()
					require("conform").format({
						async = true,
						lsp_format = "fallback",
					})
				end,
				desc = "Format file",
			},
		},
		opts = {
			formatters_by_ft = {
				lua = { "stylua" },
				javascript = { "prettier" },
				typescript = { "prettier" },
				html = { "prettier" },
				css = { "prettier" },
				json = { "prettier" },
				yaml = { "prettier" },
				markdown = { "prettier" },
			},

			format_on_save = {
				timeout_ms = 500,
				lsp_format = "fallback",
			},
		},
	},
}
