---@type MappingsTable
local M = {}

local search_with_prefix = function()
	-- Get the current word under the cursor
	local word = vim.fn.expand("<cword>")
	-- Modify the word by adding a prefix
	local modified_word = "<" .. word .. "($|\\s)"
	-- Invoke Telescope with the modified word
	-- Assuming you want to use the `live_grep` function to search
	require("telescope.builtin").live_grep({ default_text = modified_word })
end

M.general = {
	n = {
		[";"] = { ":", "enter command mode", opts = { nowait = true } },
		["<A-j>"] = { "5j", "Go down faster", opts = { nowait = true } },
		["<A-k>"] = { "5k", "Go up faster", opts = { nowait = true } },
		["<A-l>"] = { "$", "Go to the end of line", opts = { nowait = true } },
		["<A-h>"] = { "^", "Go to the beginning of line", opts = { nowait = true } },
		["<C-s>"] = { "<cmd> NvimTreeToggle <CR>", "Toggle nvimtree" },

		-- Search with Spectre -----------------------------------------------------------------

		["<C-x>"] = {
			function()
				vim.cmd("bd")
			end,
			"Close buffer",
		},
		["<leader>se"] = { "<cmd>lua vim.diagnostic.open_float()<CR>", "Show error in floater" },

		["<S-l>"] = {
			function()
				require("nvchad.tabufline").tabuflineNext()
			end,
			"Goto next buffer",
		},

		["<S-h>"] = {
			function()
				require("nvchad.tabufline").tabuflinePrev()
			end,
			"Goto prev buffer",
		},
		--
		-- find files using Spectre -----------------------------------------------------------------
		--
		["<leader>S"] = {
			function()
				require("spectre").toggle()
			end,
			"Toggle Spectre",
		},
		["<leader>sW"] = {
			function()
				require("spectre").open_visual({ select_word = true })
			end,
			"Search current word",
		},
		["<leader>sc"] = {
			function()
				require("spectre").open_file_search({ select_word = true })
			end,
			"Search on current file",
		},

		--
		-- find files using Telescope -----------------------------------------------------------------
		--
		["<C-f>f"] = {
			function()
				require("telescope.builtin").find_files()
			end,
			"Find String",
		},
		["<Tab>"] = {
			function()
				require("telescope.builtin").buffers()
			end,
			"Find buffer",
		},
		["<C-f>g"] = {
			function()
				require("telescope.builtin").live_grep()
			end,
			"Find String",
		},
		["<C-f>w"] = {
			function()
				require("telescope.builtin").grep_string()
			end,
			"Find Current Word",
		},
		["<C-f>d"] = {
			function()
				require("telescope.builtin").lsp_definitions()
			end,
			"Find Definitions",
		},
		["<C-f>i"] = {
			function()
				require("telescope.builtin").lsp_implementations()
			end,
			"Find Implementations",
		},
		["<C-f>r"] = {
			function()
				require("telescope.builtin").lsp_references()
			end,
			"Find References",
		},
		["<C-f>l"] = {
			function()
				require("telescope.builtin").resume()
			end,
			"Last search",
		},
		["<C-f>rr"] = {
			"",
			"Find React References",
			opts = { noremap = true, callback = search_with_prefix },
		},
		["<C-f>c"] = { 'yiw/<C-r>"', "Show word in current buffer" },

		-- Copilot --------------------------------------------------------------------------------

		["<C-P>"] = {
			"<cmd>CopilotChatToggle<CR>",
			"Toggle CopilotChat",
		},

		["<C-p>q"] = {
			function()
				local input = vim.fn.input("Quick Chat: ")
				if input ~= "" then
					require("CopilotChat").ask(input, { selection = require("CopilotChat.select").buffer })
				end
			end,
			"Opn CopilotChat",
		},
	},

	-- ==========================================================================================

	v = {
		[">"] = { ">gv", "indent" },
		["<C-f>w"] = { '<esc><cmd>lua require("spectre").open_visual()<CR>', "Search current word" },
		["<leader>fw"] = {
			'<cmd>require("telescope.builtin").grep_string({ search =  _G.get_visual_selection() })<CR>',
			"Find Selected Word",
		},
		["<C-p>q"] = {
			function()
				local input = vim.fn.input("Quick Chat: ")
				if input ~= "" then
					require("CopilotChat").ask(input, { selection = require("CopilotChat.select").buffer })
				end
			end,
			"Opn CopilotChat",
		},
	},
	x = {},
}

return M
