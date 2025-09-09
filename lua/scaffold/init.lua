local M = {}

local CURSOR_PLACEHOLDER = "${CURSOR}"

local default_config = {
	templates_dir = vim.fn.stdpath("config") .. "/templates",
	startinsert = true,
	placeholder_providers = {
		["JAVA_PACKAGE_NAME"] = function(args)
			local os_separator = package.config:sub(1, 1)
			local buf_name = vim.api.nvim_buf_get_name(args.buf)
			local absolute_path = vim.fn.fnamemodify(buf_name, ":p:h")

			local _, end_of_java_root =
				absolute_path:find("src" .. os_separator .. "main" .. os_separator .. "java" .. os_separator)

			if not end_of_java_root then
				vim.notify("Cannot specify package name for current Java class", vim.log.levels.WARN)
				return ""
			end

			local package_name = absolute_path:sub(end_of_java_root + 1):gsub("/", ".")

			return "package " .. package_name .. ";"
		end,
		["FILE_NAME_NO_EXT"] = function(args)
			local buf_name = vim.api.nvim_buf_get_name(args.buf)
			local file_name = vim.fn.fnamemodify(buf_name, ":t:r")
			return file_name
		end,
		["FILE_NAME"] = function(args)
			local buf_name = vim.api.nvim_buf_get_name(args.buf)
			local file_name = vim.fn.fnamemodify(buf_name, ":t")
			return file_name
		end,
		["YEAR"] = function(_)
			return os.date("%Y")
		end,
		["MONTH"] = function(_)
			return os.date("%m")
		end,
		["DAY"] = function(_)
			return os.date("%d")
		end,
	},
}

local function populate_template(args, template, placeholder_providers)
	local function replace(str, placeholder, func)
		local placeholder_start, placeholder_end = str:find(placeholder)
		if placeholder_start then
			local replacement = func(args)
			return str:gsub(placeholder, replacement)
		end
		return str
	end

	for placeholder_name, func in pairs(placeholder_providers) do
		template = replace(template, "${" .. placeholder_name .. "}", func)
	end
	return template
end

local function get_template(config, filetype)
	local template_file_path = vim.fs.joinpath(config.templates_dir, filetype .. ".template")
	local f = io.open(template_file_path, "r")
	if f then
		local template = f:read("*all")
		f:close()
		return template
	end
	return nil
end

local function maybe_move_cursor()
	local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	for index, line in ipairs(lines) do
		local start = line:find(CURSOR_PLACEHOLDER)
		if start then
			local removed_placeholder_line = line:gsub(CURSOR_PLACEHOLDER, "")
			vim.api.nvim_win_set_cursor(0, { index, start - 1 })
			vim.api.nvim_set_current_line(removed_placeholder_line)
			return
		end
	end
end

M.setup = function(config)
	config = config or {}
	config = vim.tbl_deep_extend("force", default_config, config)

	local augroup = vim.api.nvim_create_augroup("scaffold.nvim", { clear = true })
	vim.api.nvim_create_autocmd({ "BufRead", "BufEnter" }, {
		group = augroup,
		pattern = "*",
		callback = function(args)
			local lines = vim.api.nvim_buf_get_lines(args.buf, 0, -1, false)
			if #lines > 1 or lines[1] ~= "" then
				return
			end

			local filetype = vim.bo[args.buf].filetype
			if not filetype then
				return
			end
			local template = get_template(config, filetype)
			if not template then
				return
			end
			local content = populate_template(args, template, config.placeholder_providers)
			if content then
				vim.api.nvim_buf_set_lines(args.buf, 0, -1, false, vim.split(content, "\n"))
			end
			maybe_move_cursor()
			if config.startinsert then
				vim.cmd("startinsert")
			end
		end,
	})
end

return M
