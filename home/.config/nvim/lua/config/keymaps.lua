local keymap = vim.keymap.set
local opts = { noremap = true, silent = true }

keymap("n", "<leader>w", "<cmd>w<CR>", { desc = "Save File" })
keymap("n", "<leader>q", "<cmd>q<CR>", { desc = "Quit Window" })
keymap("n", "<leader>x", "<cmd>x<CR>", { desc = "Save and Quit" })
keymap("n", "<Esc>", "<cmd>nohlsearch<CR>", { desc = "Clear search highlight" })

keymap("n", "<leader>sv", "<C-w>v", { desc = "Vertical Split" })
keymap("n", "<leader>sh", "<C-w>s", { desc = "Horizontal Split" })
keymap("n", "<leader>se", "<C-w>=", { desc = "Equalize Splits" })
keymap("n", "<leader>sx", "<cmd>close<CR>", { desc = "Close Split" })

keymap("n", "<C-h>", "<C-w>h", opts)
keymap("n", "<C-j>", "<C-w>j", opts)
keymap("n", "<C-k>", "<C-w>k", opts)
keymap("n", "<C-l>", "<C-w>l", opts)

keymap("v", "<", "<gv", opts)
keymap("v", ">", ">gv", opts)

keymap("n", "<leader>e", "<cmd>NvimTreeToggle<CR>", { desc = "Toggle File Explorer" })
keymap("n", "<leader>ff", "<cmd>Telescope find_files<CR>", { desc = "Find Files" })
keymap("n", "<leader>fg", "<cmd>Telescope live_grep<CR>", { desc = "Search text in project" })
keymap("n", "<leader>fb", "<cmd>Telescope buffers<CR>", { desc = "Find open buffers" })
keymap("n", "<leader>fh", "<cmd>Telescope help_tags<CR>", { desc = "Search Help docs" })

local ok, wk = pcall(require, "which-key")

if ok then
	wk.add({
		{ "<leader>f", group = "Find/Search" },
		{ "<leader>s", group = "Splits/Windows" },
		{ "<leader>e", desc = "Toggle file explorer" },
		{ "<leader>w", desc = "Save File" },
		{ "<leader>q", desc = "Quit Window" },
		{ "<leader>x", desc = "Save and Quit" },
	})
end
