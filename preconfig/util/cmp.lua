local M = {}
function M.snippet_replace(snippet, fn)
	return snippet:gsub("%$%b{}", function(m)
		local n, name = m:match("^%${(%d+):(.+)}$")
		return n and fn({ n = n, text = name }) or m
	end) or snippet
end
function M.snippet_preview(snippet)
	local ok, parsed = pcall(function()
		return vim.lsp._snippet_grammar.parse(snippet)
	end)
	return ok and tostring(parsed)
		or M.snippet_replace(snippet, function(placeholder)
			return M.snippet_preview(placeholder.text)
		end):gsub("%$0", "")
end

function M.add_missing_snippet_docs(window)
	local cmp = require("cmp")
	local Kind = cmp.lsp.CompletionItemKind
	local entries = window:get_entries()
	for _, entry in ipairs(entries) do
		if entry:get_kind() == Kind.Snippet then
			local item = entry:get_completion_item()
			if not item.documentation and item.insertText then
				item.documentation = {
					kind = cmp.lsp.MarkupKind.Markdown,
					value = string.format("```%s\n%s\n```", vim.bo.filetype, M.snippet_preview(item.insertText)),
				}
			end
		end
	end
end
function M.setup(opts)
	for _, source in ipairs(opts.sources) do
		source.group_index = source.group_index or 1
	end

	local parse = require("cmp.utils.snippet").parse
	require("cmp.utils.snippet").parse = function(input)
		local ok, ret = pcall(parse, input)
		if ok then
			return ret
		end
		return M.snippet_preview(input)
	end

	local cmp = require("cmp")
	cmp.setup(opts)
	cmp.event:on("confirm_done", function(event)
		if vim.tbl_contains(opts.auto_brackets or {}, vim.bo.filetype) then
			M.auto_brackets(event.entry)
		end
	end)
	cmp.event:on("menu_opened", function(event)
		M.add_missing_snippet_docs(event.window)
	end)
end
return M
