local M = {}

local uv = vim.uv or vim.loop

local nord = {
	background = "#2E3440",
	foreground = "#D8DEE9",
	colors = {
		"#3B4252",
		"#BF616A",
		"#A3BE8C",
		"#EBCB8B",
		"#81A1C1",
		"#B48EAD",
		"#88C0D0",
		"#E5E9F0",
		"#4C566A",
		"#BF616A",
		"#A3BE8C",
		"#EBCB8B",
		"#81A1C1",
		"#B48EAD",
		"#8FBCBB",
		"#ECEFF4",
	},
	source = "nord",
}

M.palette = nord
M.source = "nord"
M._timer = nil
M._last_signature = nil

local function valid_hex(value)
	return type(value) == "string" and value:match("^#%x%x%x%x%x%x$") ~= nil
end

local function to_rgb(color)
	return {
		tonumber(color:sub(2, 3), 16),
		tonumber(color:sub(4, 5), 16),
		tonumber(color:sub(6, 7), 16),
	}
end

local function to_hex(rgb)
	return string.format("#%02X%02X%02X", math.floor(rgb[1] + 0.5), math.floor(rgb[2] + 0.5), math.floor(rgb[3] + 0.5))
end

local function mix(first, second, amount)
	local a = to_rgb(first)
	local b = to_rgb(second)
	return to_hex({
		a[1] + (b[1] - a[1]) * amount,
		a[2] + (b[2] - a[2]) * amount,
		a[3] + (b[3] - a[3]) * amount,
	})
end

local function linear_channel(value)
	value = value / 255
	if value <= 0.03928 then
		return value / 12.92
	end
	return ((value + 0.055) / 1.055) ^ 2.4
end

local function luminance(color)
	local rgb = to_rgb(color)
	return 0.2126 * linear_channel(rgb[1]) + 0.7152 * linear_channel(rgb[2]) + 0.0722 * linear_channel(rgb[3])
end

local function contrast(first, second)
	local lighter = math.max(luminance(first), luminance(second))
	local darker = math.min(luminance(first), luminance(second))
	return (lighter + 0.05) / (darker + 0.05)
end

local function readable(color, background, minimum)
	if contrast(color, background) >= minimum then
		return color
	end

	local target = luminance(background) < 0.45 and "#FFFFFF" or "#000000"
	for step = 1, 10 do
		local candidate = mix(color, target, step / 10)
		if contrast(candidate, background) >= minimum then
			return candidate
		end
	end
	return target
end

local function cache_path()
	local cache_home = vim.env.XDG_CACHE_HOME
	if not cache_home or cache_home == "" then
		cache_home = vim.fn.expand("~/.cache")
	end
	return cache_home .. "/wal/colors.json"
end

local function read_pywal_palette()
	local file = io.open(cache_path(), "r")
	if not file then
		return nil, "cache is missing"
	end

	local contents = file:read("*a")
	file:close()
	local ok, decoded = pcall(vim.json.decode, contents)
	if not ok or type(decoded) ~= "table" then
		return nil, "cache is not valid JSON"
	end
	if type(decoded.special) ~= "table" or type(decoded.colors) ~= "table" then
		return nil, "cache does not contain Pywal colors"
	end
	if not valid_hex(decoded.special.background) or not valid_hex(decoded.special.foreground) then
		return nil, "cache contains invalid special colors"
	end

	local colors = {}
	for index = 0, 15 do
		local color = decoded.colors["color" .. index]
		if not valid_hex(color) then
			return nil, "cache contains an invalid terminal color"
		end
		colors[index + 1] = color
	end

	return {
		background = decoded.special.background,
		foreground = decoded.special.foreground,
		colors = colors,
		checksum = decoded.checksum,
		source = decoded.wallpaper or "pywal",
	}
end

local function derived(palette)
	local background = palette.background
	local foreground = readable(palette.foreground, background, 7)
	local colors = palette.colors

	return {
		bg = background,
		bg_alt = mix(background, foreground, 0.07),
		surface = mix(background, foreground, 0.11),
		surface_high = mix(background, foreground, 0.17),
		fg = foreground,
		muted = readable(mix(foreground, background, 0.38), background, 4.5),
		faint = readable(mix(foreground, background, 0.55), background, 3),
		accent = readable(colors[13], background, 4.5),
		accent_alt = readable(colors[15], background, 4.5),
		red = readable(colors[10], background, 4.5),
		green = readable(colors[11], background, 4.5),
		yellow = readable(colors[12], background, 4.5),
		blue = readable(colors[13], background, 4.5),
		magenta = readable(colors[14], background, 4.5),
		cyan = readable(colors[15], background, 4.5),
		selection = mix(background, readable(colors[13], background, 4.5), 0.24),
	}
end

local function apply_terminal_colors(palette)
	for index, color in ipairs(palette.colors) do
		vim.g["terminal_color_" .. (index - 1)] = color
	end
end

local function apply_highlights(palette)
	local color = derived(palette)
	local highlight = vim.api.nvim_set_hl

	vim.o.background = "dark"
	vim.cmd("highlight clear")
	if vim.fn.exists("syntax_on") == 1 then
		vim.cmd("syntax reset")
	end
	vim.g.colors_name = "pywal"
	apply_terminal_colors(palette)

	local groups = {
		Normal = { fg = color.fg, bg = color.bg },
		NormalNC = { fg = color.muted, bg = color.bg },
		NormalFloat = { fg = color.fg, bg = color.surface },
		FloatBorder = { fg = color.accent, bg = color.surface },
		FloatTitle = { fg = color.accent, bg = color.surface, bold = true },
		Cursor = { fg = color.bg, bg = color.fg },
		CursorLine = { bg = color.bg_alt },
		CursorColumn = { bg = color.bg_alt },
		CursorLineNr = { fg = color.accent, bg = color.bg_alt, bold = true },
		LineNr = { fg = color.faint, bg = color.bg },
		SignColumn = { fg = color.muted, bg = color.bg },
		FoldColumn = { fg = color.faint, bg = color.bg },
		Folded = { fg = color.muted, bg = color.bg_alt, italic = true },
		WinSeparator = { fg = color.surface_high, bg = color.bg },
		StatusLine = { fg = color.fg, bg = color.surface, bold = true },
		StatusLineNC = { fg = color.faint, bg = color.bg_alt },
		TabLine = { fg = color.muted, bg = color.bg_alt },
		TabLineFill = { fg = color.faint, bg = color.bg },
		TabLineSel = { fg = color.bg, bg = color.accent, bold = true },
		WinBar = { fg = color.fg, bg = color.bg, bold = true },
		WinBarNC = { fg = color.faint, bg = color.bg },
		Pmenu = { fg = color.fg, bg = color.surface },
		PmenuSel = { fg = color.fg, bg = color.selection, bold = true },
		PmenuSbar = { bg = color.bg_alt },
		PmenuThumb = { bg = color.accent },
		Visual = { bg = color.selection },
		Search = { fg = color.bg, bg = color.yellow, bold = true },
		IncSearch = { fg = color.bg, bg = color.accent, bold = true },
		CurSearch = { fg = color.bg, bg = color.accent_alt, bold = true },
		MatchParen = { fg = color.accent_alt, bg = color.surface_high, bold = true },
		ColorColumn = { bg = color.bg_alt },
		NonText = { fg = color.faint },
		Whitespace = { fg = color.surface_high },
		EndOfBuffer = { fg = color.bg },
		SpecialKey = { fg = color.faint },
		Directory = { fg = color.accent, bold = true },
		Title = { fg = color.accent, bold = true },
		Question = { fg = color.green },
		MoreMsg = { fg = color.green },
		ModeMsg = { fg = color.accent, bold = true },
		MsgArea = { fg = color.fg, bg = color.bg },
		ErrorMsg = { fg = color.red, bold = true },
		WarningMsg = { fg = color.yellow, bold = true },
		QuickFixLine = { bg = color.selection, bold = true },
		Conceal = { fg = color.faint },

		Comment = { fg = color.muted, italic = true },
		Constant = { fg = color.magenta },
		String = { fg = color.green },
		Character = { fg = color.green },
		Number = { fg = color.magenta },
		Boolean = { fg = color.magenta, bold = true },
		Float = { fg = color.magenta },
		Identifier = { fg = color.fg },
		Function = { fg = color.blue, bold = true },
		Statement = { fg = color.accent, bold = true },
		Conditional = { fg = color.accent, bold = true },
		Repeat = { fg = color.accent, bold = true },
		Label = { fg = color.cyan },
		Operator = { fg = color.cyan },
		Keyword = { fg = color.accent, italic = true },
		Exception = { fg = color.red, bold = true },
		PreProc = { fg = color.cyan },
		Include = { fg = color.cyan },
		Define = { fg = color.cyan },
		Macro = { fg = color.cyan },
		PreCondit = { fg = color.cyan },
		Type = { fg = color.yellow },
		StorageClass = { fg = color.yellow },
		Structure = { fg = color.yellow },
		Typedef = { fg = color.yellow },
		Special = { fg = color.accent_alt },
		SpecialChar = { fg = color.accent_alt },
		Tag = { fg = color.accent },
		Delimiter = { fg = color.muted },
		SpecialComment = { fg = color.cyan, italic = true },
		Debug = { fg = color.red },
		Underlined = { fg = color.blue, underline = true },
		Ignore = { fg = color.faint },
		Error = { fg = color.red, bold = true },
		Todo = { fg = color.bg, bg = color.yellow, bold = true },

		DiagnosticError = { fg = color.red },
		DiagnosticWarn = { fg = color.yellow },
		DiagnosticInfo = { fg = color.blue },
		DiagnosticHint = { fg = color.cyan },
		DiagnosticOk = { fg = color.green },
		DiagnosticUnderlineError = { undercurl = true, sp = color.red },
		DiagnosticUnderlineWarn = { undercurl = true, sp = color.yellow },
		DiagnosticUnderlineInfo = { undercurl = true, sp = color.blue },
		DiagnosticUnderlineHint = { undercurl = true, sp = color.cyan },

		DiffAdd = { fg = color.green, bg = mix(color.bg, color.green, 0.12) },
		DiffChange = { fg = color.blue, bg = mix(color.bg, color.blue, 0.12) },
		DiffDelete = { fg = color.red, bg = mix(color.bg, color.red, 0.12) },
		DiffText = { fg = color.fg, bg = mix(color.bg, color.accent, 0.24), bold = true },
		GitSignsAdd = { fg = color.green },
		GitSignsChange = { fg = color.blue },
		GitSignsDelete = { fg = color.red },

		TelescopeNormal = { fg = color.fg, bg = color.surface },
		TelescopeBorder = { fg = color.accent, bg = color.surface },
		TelescopePromptNormal = { fg = color.fg, bg = color.surface_high },
		TelescopePromptBorder = { fg = color.accent, bg = color.surface_high },
		TelescopePromptTitle = { fg = color.bg, bg = color.accent, bold = true },
		TelescopePreviewTitle = { fg = color.bg, bg = color.green, bold = true },
		TelescopeResultsTitle = { fg = color.bg, bg = color.blue, bold = true },
		TelescopeSelection = { bg = color.selection, bold = true },
		TelescopeMatching = { fg = color.accent_alt, bold = true },

		NvimTreeNormal = { fg = color.fg, bg = color.bg_alt },
		NvimTreeNormalNC = { fg = color.muted, bg = color.bg_alt },
		NvimTreeRootFolder = { fg = color.accent, bold = true },
		NvimTreeFolderIcon = { fg = color.accent },
		NvimTreeGitDirty = { fg = color.yellow },
		NvimTreeGitNew = { fg = color.green },
		NvimTreeGitDeleted = { fg = color.red },
		WhichKey = { fg = color.accent },
		WhichKeyGroup = { fg = color.cyan },
		WhichKeyDesc = { fg = color.fg },
		WhichKeySeparator = { fg = color.faint },
		WhichKeyFloat = { bg = color.surface },
	}

	for group, spec in pairs(groups) do
		highlight(0, group, spec)
	end

	local links = {
		["@annotation"] = "PreProc",
		["@attribute"] = "PreProc",
		["@boolean"] = "Boolean",
		["@character"] = "Character",
		["@comment"] = "Comment",
		["@comment.todo"] = "Todo",
		["@constant"] = "Constant",
		["@constant.builtin"] = "Special",
		["@constructor"] = "Special",
		["@diff.delta"] = "DiffChange",
		["@diff.minus"] = "DiffDelete",
		["@diff.plus"] = "DiffAdd",
		["@function"] = "Function",
		["@function.builtin"] = "Special",
		["@function.call"] = "Function",
		["@keyword"] = "Keyword",
		["@keyword.exception"] = "Exception",
		["@label"] = "Label",
		["@markup.heading"] = "Title",
		["@markup.link"] = "Underlined",
		["@markup.list"] = "Special",
		["@markup.raw"] = "String",
		["@module"] = "Include",
		["@number"] = "Number",
		["@operator"] = "Operator",
		["@property"] = "Identifier",
		["@punctuation.bracket"] = "Delimiter",
		["@punctuation.delimiter"] = "Delimiter",
		["@punctuation.special"] = "Special",
		["@string"] = "String",
		["@string.escape"] = "SpecialChar",
		["@tag"] = "Tag",
		["@tag.attribute"] = "Identifier",
		["@tag.delimiter"] = "Delimiter",
		["@type"] = "Type",
		["@type.builtin"] = "Special",
		["@variable"] = "Identifier",
		["@variable.builtin"] = "Special",
		["@variable.parameter"] = "Identifier",
		["@lsp.type.class"] = "Type",
		["@lsp.type.comment"] = "Comment",
		["@lsp.type.decorator"] = "PreProc",
		["@lsp.type.enum"] = "Type",
		["@lsp.type.enumMember"] = "Constant",
		["@lsp.type.function"] = "Function",
		["@lsp.type.interface"] = "Type",
		["@lsp.type.keyword"] = "Keyword",
		["@lsp.type.macro"] = "Macro",
		["@lsp.type.method"] = "Function",
		["@lsp.type.namespace"] = "Include",
		["@lsp.type.number"] = "Number",
		["@lsp.type.operator"] = "Operator",
		["@lsp.type.parameter"] = "Identifier",
		["@lsp.type.property"] = "Identifier",
		["@lsp.type.string"] = "String",
		["@lsp.type.struct"] = "Structure",
		["@lsp.type.type"] = "Type",
		["@lsp.type.typeParameter"] = "Typedef",
		["@lsp.type.variable"] = "Identifier",
	}

	for group, target in pairs(links) do
		highlight(0, group, { link = target })
	end
end

local function emit_theme_changed(pattern)
	vim.api.nvim_exec_autocmds("ColorScheme", {
		pattern = pattern,
		modeline = false,
	})
	vim.api.nvim_exec_autocmds("User", {
		pattern = "WallpaperThemeChanged",
		modeline = false,
	})

	-- This also upgrades a Neovim instance that was already open when the
	-- dotfiles changed and therefore loaded Lualine's former fixed Nord theme.
	if package.loaded["lualine"] then
		local ok, lualine = pcall(require, "lualine")
		if ok then
			lualine.setup({
				options = {
					theme = function()
						return M.lualine_theme()
					end,
				},
			})
			lualine.refresh()
		end
	end
	vim.cmd("redrawstatus")
end

local function apply_nord()
	M.palette = nord
	M.source = "nord"
	vim.g.nord_contrast = true
	vim.g.nord_borders = true
	if not pcall(vim.cmd.colorscheme, "nord") then
		apply_highlights(nord)
		emit_theme_changed("pywal")
	end
end

function M.reload(options)
	options = options or {}
	local palette, error_message = read_pywal_palette()
	if not palette then
		if options.fallback then
			apply_nord()
		end
		return false, error_message
	end

	M.palette = palette
	M.source = palette.source
	apply_highlights(palette)
	emit_theme_changed("pywal")
	return true
end

function M.lualine_theme()
	local color = derived(M.palette)
	return {
		normal = {
			a = { fg = color.bg, bg = color.accent, gui = "bold" },
			b = { fg = color.fg, bg = color.surface_high },
			c = { fg = color.muted, bg = color.bg_alt },
		},
		insert = {
			a = { fg = color.bg, bg = color.green, gui = "bold" },
		},
		visual = {
			a = { fg = color.bg, bg = color.magenta, gui = "bold" },
		},
		replace = {
			a = { fg = color.bg, bg = color.red, gui = "bold" },
		},
		command = {
			a = { fg = color.bg, bg = color.yellow, gui = "bold" },
		},
		inactive = {
			a = { fg = color.faint, bg = color.bg_alt },
			b = { fg = color.faint, bg = color.bg_alt },
			c = { fg = color.faint, bg = color.bg },
		},
	}
end

local function cache_signature()
	local stat = uv.fs_stat(cache_path())
	if not stat then
		return "missing"
	end
	local modified = stat.mtime or {}
	return table.concat({
		tostring(modified.sec or 0),
		tostring(modified.nsec or 0),
		tostring(stat.size or 0),
	}, ":")
end

local function stop_watcher()
	if M._timer and not M._timer:is_closing() then
		M._timer:stop()
		M._timer:close()
	end
	M._timer = nil
end

local function start_watcher()
	stop_watcher()
	M._last_signature = cache_signature()
	M._timer = uv.new_timer()
	if not M._timer then
		return
	end

	M._timer:start(
		1500,
		1500,
		vim.schedule_wrap(function()
			local signature = cache_signature()
			if signature == M._last_signature then
				return
			end
			M._last_signature = signature

			if signature == "missing" then
				if M.source ~= "nord" then
					apply_nord()
				end
				return
			end

			-- Pywal replaces its cache files in quick succession. A short debounce
			-- keeps Neovim from reading a partially published JSON file.
			vim.defer_fn(function()
				M.reload({ fallback = false })
			end, 150)
		end)
	)
end

function M.setup()
	M.reload({ fallback = true })

	pcall(vim.api.nvim_del_user_command, "WallpaperThemeReload")
	vim.api.nvim_create_user_command("WallpaperThemeReload", function()
		local ok, error_message = M.reload({ fallback = true })
		if ok then
			vim.notify("Reloaded Neovim colors from Pywal", vim.log.levels.INFO)
		else
			vim.notify("Using Nord fallback: " .. error_message, vim.log.levels.WARN)
		end
	end, { desc = "Reload Neovim colors from the Pywal cache" })

	local group = vim.api.nvim_create_augroup("WallpaperThemeWatcher", { clear = true })
	vim.api.nvim_create_autocmd("VimLeavePre", {
		group = group,
		callback = stop_watcher,
	})
	start_watcher()
end

return M
