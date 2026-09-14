-- ~/.config/nvim/lua/config/lsp.lua

vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(event)
    local map = function(mode, lhs, rhs, desc)
      vim.keymap.set(mode, lhs, rhs, {
        buffer = event.buf,
        silent = true,
        desc = desc,
      })
    end

    map("n", "gd", vim.lsp.buf.definition, "Go to definition")
    map("n", "gr", vim.lsp.buf.references, "Show references")
    map("n", "gi", vim.lsp.buf.implementation, "Go to implementation")
    map("n", "K", vim.lsp.buf.hover, "Hover documentation")
    map("n", "<leader>rn", vim.lsp.buf.rename, "Rename symbol")
    map("n", "<leader>ca", vim.lsp.buf.code_action, "Code action")
    map("n", "<leader>d", vim.diagnostic.open_float, "Show diagnostic")
    map("n", "[d", vim.diagnostic.goto_prev, "Previous diagnostic")
    map("n", "]d", vim.diagnostic.goto_next, "Next diagnostic")
  end,
})

vim.diagnostic.config({
  virtual_text = true,
  signs = true,
  underline = true,
  update_in_insert = false,
  severity_sort = true,
})

vim.lsp.config("jdtls", {
  cmd = { "jdtls" },

  filetypes = { "java" },

  root_markers = {
    "gradlew",
    "mvnw",
    "pom.xml",
    "build.gradle",
    "settings.gradle",
    ".git",
  },
})

vim.lsp.enable("jdtls")
