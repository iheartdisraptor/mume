module("scrolls", package.seeall)

reliquary_type = {
	scrolls = {}
}

function reliquary_type:set(name, scroll)
	name = string.lower(name)
	self.scrolls[name] = scroll
end

function reliquary_type:exists(name)
	name = string.lower(name)
	local scroll = self.scrolls[name]

	return scroll ~= nil
end

function reliquary_type:get(name)
	name = string.lower(name)
	if self:exists(name) then
		return self.scrolls[name]
	end

	return nil
end

function reliquary_type:for_each(functor)
	for name, scroll in pairs(self.scrolls) do
		functor(scroll)
	end
end

function reliquary_type:clear()
	self.scrolls = {}
end

function reliquary_type:make(name)
	local search_name = string.lower(name)
	if self:exists(search_name) then
		return self:get(search_name)
	end

	-- Create a new scroll and initialize it
	local scroll = scroll_type.make(name)
	self:set(name, scroll)

	-- Ensure the scroll is initialized or loaded
	enableTimer("Load Scrolls")

	scroll.owner = _G[scroll.table_name]

	return scroll
end

function reliquary_type:remove(name)
	name = string.lower(name)
	if not self:exists(name) then
		return
	end

	self.scrolls[name] = nil
end

reliquary = table.deepcopy(reliquary_type)

function reliquary.save()
	reliquary:for_each(function (scroll) scroll:save() end)
end

function reliquary.load()
	reliquary:for_each(function (scroll) scroll:load() end)
end

registerAnonymousEventHandler("sysExitEvent", "scrolls.reliquary.save")
registerAnonymousEventHandler("sysLoadEvent", "scrolls.reliquary.load")

codex_type = {
	scrolls = {}
}

function codex_type.parse_version(version)
	local result = {}
	for number in string.match(str, "(%d+)") do
		result:insert(number)
	end
	result:insert(string.match("(%a)"))
	return result
end

function codex_type.version_greater_than(left, right)
	local left_version = codex_type.parse_version(left)
	local right_version = codex_type.parse_version(right)
	local size = math.max(#left_version, #right_version)

	for index = 1, size do
		if left_version[index] < right_version[index] then
			return true
		end
	end

	if #left_version > #right_version then
		return true
	elseif #left_version < #right_version then
		return false
	end

	return false
end

function codex_type:add(scroll)
	local name = string.lower(scroll.name)
	local entry = {
		name = scroll.name,
		subtitle = scroll.subtitle,
		version = scroll.version,
		url = scroll.url,
		help = scroll.help[1],
		authors = scroll.authors,
		depends = scroll.depends,
	}

	if self.scrolls[name] ~= nil then
		local existing = self.scrolls[name]
		if self.version_greater_than(entry.version, existing.version) then
			self.scrolls[name] = entry
			echo("Added " .. entry.name .. " to the codex.\n")
		end
	else
		self.scrolls[name] = entry
		echo("Added " .. entry.name .. " to the codex.\n")
	end
end

function codex_type:exists(name)
	name = string.lower(name)
	return self.scrolls[name] ~= nil
end

function codex_type:get(name)
	name = string.lower(name)
	if codex_type.exists(self, name) then
		return self.scrolls[name]
	end
	return nil
end

function codex_type:merge(other_codex)
	for name, scroll in pairs(other_codex) do
		codex_type:add(other_codex.scrolls[name])
	end
end

function codex_type.search_string(str, query)
	if type(str) == "table" then
		local result = true
		for key, value in pairs(str) do
			result = result and codex_type.search_string(value, query)
		end
		return result
	end

	query = string.lower(query)
	str = string.lower(str)
	if str:match(query) ~= nil then
		return true
	end
	return false
end

function codex_type:search(query)
	if query == nil then
		echo("Cannot search without query string.\n")
		return
	end
	local results = {}
	for name, scroll in pairs(self.scrolls) do
		if codex_type.search_string(scroll.name, query) or
			codex_type.search_string(scroll.subtitle, query) or
			codex_type.search_string(scroll.version, query) or
			codex_type.search_string(scroll.help, query) or
			codex_type.search_string(scroll.authors, query) then
			table.insert(results, scroll)
		end
	end
	return results
end

function codex_type:clear()
	self.scrolls = {}
end

scroll_type = {
	initialized = false,
	loaded = false,
	name = "",
	version = "",
	table_name = "",
	command_prefix = "",
	folder = "",
	filename = "",
	url = "",
	data = {},
	aliases = {},
	subtitle = "",
	help = {},
	commands = {},
	changes = {},
	depends = {},
	authors = {},
	thanks = {},
}

function scroll_type:add_help(help)
	table.insert(self.help, help)
end

function scroll_type:add_command(command, text, code, regex)
	table.insert(self.commands, { command, text, code, regex })
end

function scroll_type:add_change(date, changes)
	local container = { date }

	for index, change in pairs(changes) do
		table.insert(container, change)
	end

	table.insert(self.changes, container)
end

function scroll_type:add_depend(name)
	table.insert(self.depends, name)
end

function scroll_type:add_author(author)
	table.insert(self.authors, author)
end

function scroll_type:add_thanks(thanks)
	table.insert(self.thanks, thanks)
end

function scroll_type.make_table_name(name)
	local result = string.trim(name)

	result = string.lower(result)
	result = string.gsub(result, " ", "_")

	return result
end

function scroll_type.standardize_path(path)
	path = path:gsub("\\", "/")
	return path
end

function scroll_type.get_folder(name)
	return scroll_type.standardize_path(getMudletHomeDir() .. "/" .. name)
end

function scroll_type.get_filename(name)
	return scroll_type.get_folder(name) .. "/table.lua"
end

function scroll_type:mkdir()
	local replace = string.gsub(self.folder, "\\", "/")
	local split = string.split(replace, "/")

	local path = ""	
	for index, dir in ipairs(split) do
		path = path .. dir .. "/"
		if not io.exists(path) then
			lfs.mkdir(path)
		end
	end
end

function scroll_type.make(name)
	local scroll = table.deepcopy(scroll_type)

	-- Get paths
	local folder = scroll.get_folder(name)
	local filename = scroll.get_filename(name)

	-- Initialize the scroll's table
	scroll.name = name
	scroll.table_name = scroll.make_table_name(name) 
	scroll.command_prefix = string.lower(name)
	scroll.folder = folder
	scroll.filename = filename

	-- Make the scroll's folder in the user's profile
	scroll:mkdir()

	-- Register the folder so you can load modules from there
	bootstrap.register(name)

	scroll.initialized = true

	return scroll
end

function scroll_type:save()
	cecho("<cyan>[ USER ]  - <brown>Saving " .. self.name .. " ...<grey>\n")
	self:mkdir()
	local owner = self.owner
	self.owner = nil
	table.save(self.filename, self)
	self.owner = owner
end

function scroll_type:load()
	if self.loaded then
		return
	end

	if not io.exists(self.filename) then
		cecho("<cyan>[ USER ]  - <brown>Initializing " .. self.name .. " ...<grey>\n")

		self:mkdir()

		if self.initialize ~= nil then
			self:initialize()
		end
	else
		cecho("<cyan>[ USER ]  - <brown>Loading " .. self.name .. " ...<grey>\n")

		local owner = self.owner
		table.load(self.filename, self)
		self.owner = owner

		if self.on_load ~= nil then
			self:on_load()
		end
	end

	self:make_aliases()

	self.loaded = true
end

function scroll_type.make_regex(command)
	local regex = "^ *"
	local code = ""

	local split = command:split(" ")

	local count = 2
	for index, word in pairs(split) do
		if index ~= 1 then
			regex = regex .. " +"
		end

		local argument = word:match("<(%a[%a%d]+)>")
		if argument ~= nil then
			regex = regex .. "(.+)"
			code = code .. "local " .. argument .. " = string.trim(matches[" .. count .. "])\n"
			count = count + 1
		else
			regex = regex .. word
		end
	end

	regex = regex .. " *$"

	return regex, code
end

function scroll_type:make_aliases()
	for index, command in pairs(self.commands) do
		local name = self.command_prefix .. " " .. command[1]

		if exists(name, "alias") == 0 then
			local parent = self.name

			local regex, code = ""
			if command[4] ~= nil then
				regex = command[4]
			else
				regex, code = self.make_regex(name)
			end

			if command[3] ~= nil then
				if code == nil then code = "" end
				code = code .. command[3]
			end

			permAlias(name, parent, regex, code)
		end
	end
end

function scroll_type.echo_compact_break(compact)
	if compact then
		echo("\n")
	end
end

function scroll_type.echo_uncompact_break(compact)
	if not compact then
		echo("\n")
	end
end

function scroll_type:show_title(compact, color)
	self.echo_uncompact_break(compact)

	cecho(color.title .. self.name .. ": " .. self.subtitle .. "\n")

	self.echo_uncompact_break(compact)
end

function scroll_type:show_help_text(compact, color)
	for index, help in pairs(self.help) do
		cecho(color.default .. help .. "\n\n")
	end
end

function scroll_type:show_commands(compact, color)
	if table.size(self.commands) == 0 then
		return
	end

	cecho(color.section .. "Commands: " .. color.default .. "(prefix with \"" .. self.command_prefix .. "\", e.g. \"" .. self.command_prefix .. " help\")\n")

	self.echo_uncompact_break(compact)

	for index, command in pairs(self.commands) do
		cecho(color.data .. "- " .. command[1] .. " : " .. color.default .. command[2] .. "\n")
		self.echo_uncompact_break(compact)
	end

	self.echo_compact_break(compact)
end

function scroll_type:show_version(compact, color)
	cecho(color.section .. "Version: " .. color.data .. self.version .. "\n\n")
end

function scroll_type:show_changes(compact, color)
	if table.size(self.changes) == 0 then
		return
	end

	cecho(color.section .. "Changes:\n")
	self.echo_uncompact_break(compact)

	for index, change in pairs(self.changes) do
		for index, text in ipairs(change) do
			if index == 1 then
				cecho(color.data .. "- " .. text .. "\n")
				self.echo_uncompact_break(compact)
			else
				cecho(color.default .. "  - " .. text .. "\n")
				self.echo_uncompact_break(compact)
			end
		end
	end

	self.echo_compact_break(compact)
end

function scroll_type:show_depends(compact, color)
	if table.size(self.depends) == 0 then
		return
	end

	cecho(color.section .. "Dependencies:\n")

	self.echo_uncompact_break(compact)

	for index, depend in pairs(self.depends) do
		cecho(color.data .. "- " .. depend .. "\n")

		self.echo_uncompact_break(compact)
	end

	self.echo_compact_break(compact)
end

function scroll_type:show_authors(compact, color)
	if table.size(self.authors) == 0 then
		return
	end

	cecho(color.section .. "Authors:\n")

	self.echo_uncompact_break(compact)

	for index, author in pairs(self.authors) do
		cecho(color.data .. "- " .. author .. "\n")

		self.echo_uncompact_break(compact)
	end

	self.echo_compact_break(compact)
end

function scroll_type:show_thanks(compact, color)
	if table.size(self.thanks) == 0 then
		return
	end

	cecho(color.section .. "Thanks to:\n")

	self.echo_uncompact_break(compact)

	for index, thank in pairs(self.thanks) do
		cecho(color.data .. "- " .. thank .. "\n")

		self.echo_uncompact_break(compact)
	end

	self.echo_compact_break(compact)
end

function scroll_type:show_help(compact, color)
	self:show_title(compact, color)
	self:show_help_text(compact, color)
	self:show_commands(compact, color)
	self:show_version(compact, color)
	self:show_changes(compact, color)
	self:show_depends(compact, color)
	self:show_authors(compact, color)
	self:show_thanks(compact, color)
end

function scroll_type:reset()
	-- Remove the scroll's table file
	os.remove(self.filename)

	-- Reinitialize the scroll table
	local initialize = self.initialize
	self = self.make(self.name)
	self.initialize = initialize
	self:initialize()
	self:make_aliases()

	-- Renitialize the table
	self.loaded = true
end

scroll = reliquary:make("Scrolls")

function scroll:initialize()
	self.version = "1.0"

	self.subtitle = "Mudlet Package Manager"

	self.url = "https://github.com/iheartdisraptor/mume/raw/master/mudlet/scrolls/Scrolls/1.0/Scrolls.zip"

	self:add_help("Create, install, update, save, load, and reload Mudlet packages (called scrolls).")

	self:add_command("help", "Show this message.", "scrolls:show_help()")
	self:add_command("help <name>", "Show the help message for the given scroll.", "scrolls:show_help(name)")
	self:add_command("list", "Show a list of all of the installed scrolls.", "scrolls:show_list()")
	self:add_command("search <query>", "Search for scrolls that can be installed.", "scrolls:search(query)")
	self:add_command("install <name>", "Install the given scroll.", "scrolls:install(name)")
	self:add_command("update", "Update all installed scrolls if there are updates available.", "scrolls:update_all()")
	self:add_command("update <name>", "Update the given scroll if there is an update available.", "scrolls:update(name)")
	self:add_command("remove <name>", "Uninstall the given scroll.", "scrolls:remove(name)")
	self:add_command("save", "Save all scrolls' data to disk.", "scrolls:save_all()")
	self:add_command("save <name>", "Save the given scrolls data to disk.", "scrolls:save(name)")
	self:add_command("load", "Load all scrolls data from disk, overwriting the current values.", "scrolls:load_all()")
	self:add_command("load <name>", "Load the given scrolls data from disk.", "scrolls:load(name)")
	self:add_command("reset", "Delete all scrolls data from disk and reinitialize them.", "scrolls:reset_all()")
	self:add_command("reset <name>", "Delete the given scrolls data from disk and reinitialize it.", "scrolls:reset(name)")
	self:add_command("alias <pattern> <command>", "Make an alias for a scroll command or MUD command.", "scrolls.make_alias(matches[2], matches[3], false)", "^ *scrolls alias +([^ ]+) +(.+)$")
	self:add_command("codex", "List all scrolls in the codex, the directory of scrolls to install.", "scrolls:show_codex()")
	self:add_command("codex add <url>", "Add a codex to download.", "scrolls:add_codex(url)")
	self:add_command("codex download", "Download all codexes.", "scrolls:download_codexes()")
	self:add_command("codex copy <name>", "Copy local information from a scroll to the codex.", "scrolls:copy_to_codex(name)")
	self:add_command("codex save", "Write the current codex to disk.", "scrolls:save_codex()")
	self:add_command("codex clear", "Clear all information in the local codex", "scrolls:clear_codex()")

	self:add_change("2015-2-14", { "Initial release" })

	self:add_author("Octavia")	

	local data = self.data

	data.options = {
		codex_urls = {
			"https://raw.githubusercontent.com/iheartdisraptor/mume/master/mudlet/scrolls/codex.lua",
		},
		compact = true,
		color = {
			title = "green",
			section = "yellow",
			data = "cyan",
			default = "grey",
		},
	}

	data.codex = table.deepcopy(codex_type)
end

function make(self, name)
	-- Create the parent table
	local owner = { scroll = self.reliquary:make(name) }
	owner.scroll.owner = owner

	return owner
end

function get(self, name)
	local scroll = self.reliquary:get(name) 

	return scroll.owner
end

function make_command(command)
	local result = "\""
	local split = command:split(" ")

	for index, word in pairs(split) do
		if index ~= 1 then
			result = result .. " "
		end

		local argument = word:match("%$%d")

		if argument ~= nil then
			local count = argument:match("%d") + 1

			result = result .. "\" .. string.trim(matches[" .. count .. "]) .. \""
		else
			result = result .. word
		end
	end

	result = result .. "\""

	return result
end

function make_alias(pattern, command, echo)
	local name = pattern .. " : " .. command
	local parent = ""
	local regex = "^ *" .. pattern .. "( +.+)*$"
	local command = make_command(command)

	local boolean = "false"
	if echo then
		boolean = "true"
	end

	local code = "expandAlias(" .. command .. ", " .. boolean .. ")"

	permAlias(name, parent, regex, code)
end

function get_color(self)
	local color = {}
	local options = self.scroll.data.options

	color.title = "<" .. options.color.title .. ">"
	color.section = "<" .. options.color.section .. ">"
	color.data = "<" .. options.color.data .. ">"
	color.default = "<" .. options.color.default .. ">"

	return color
end

function show_help(self, name, compact)
	if name == nil then
		name = "Scrolls"
	end

	if compact == nil then
		compact = self.scroll.data.options.compact
	end

	local scroll = self.reliquary:get(name)
	if scroll == nil then
		echo("Scroll \"" .. name .. "\" doesn't exist.\n")
		return
	end

	local color = self:get_color()

	scroll:show_help(compact, color)
end

function show_list(self)
	local color = self:get_color()
	local data = self.scroll.data
	cecho( color.section .. "Installed:\n")

	function show(scroll)
		cecho(color.data .. "- " .. scroll.name .. " " .. scroll.version .. "\n")
	end

	self.reliquary:for_each(show)
end

function reset(self, name)
	local scroll = self.reliquary:get(name)
	if scroll == nil then
		echo("Scroll \"" .. name .. "\" doesn't exist.\n")
		return
	end

	scroll:reset()
	echo("Reset scroll " .. scroll.name .. ".\n")
end

function reset_all(self)
	self.reliquary:for_each(function (scroll) scroll:reset() end)
	echo("All scrolls have been reset.\n")
end

function save(self, name)
	local scroll = self.reliquary:get(name)
	if scroll == nil then
		echo("Scroll \"" .. name .. "\" doesn't exist.\n")
		return
	end

	scroll:save()
end

function save_all(self)
	self.reliquary:save()
end

function load(self, name)
	local scroll = self.reliquary:get(name)
	if scroll == nil then
		echo("Scroll \"" .. name .. "\" doesn't exist.\n")
		return
	end

	scroll.loaded = false
	scroll:load()
end

function load_all(self)
	self.reliquary:for_each(function (scroll) scroll.loaded = false end)
	self.reliquary:load()
end

function remove(name)
	local scroll = self.reliquary:get(name)
	if scroll == nil then
		echo("Scroll \"" .. name .. "\" doesn't exist.\n")
		return
	end

	os.remove(scroll.filename)
	lfs.rmdir(scroll.folder)
	self.reliquary:remove(name)
	uninstallPackage(name)
end

function show_codex_entries(self, entries)
	local color = self:get_color()

	cecho(color.section .. "Showing " .. table.size(entries) .. " results:\n\n")

	for key, entry in pairs(entries) do
		cecho(color.title .. entry.name .. ": " .. entry.subtitle .. "\n")
		cecho(color.section .. "Version: " .. color.data .. entry.version .. "\n")
		cecho(color.section .. "Authors:\n")
		for index, author in pairs(scroll.authors) do
			cecho(color.data .. "- " .. author .. "\n")
		end
		cecho(entry.help .. "\n")
		cecho("\n")
	end
end

function search(self, query)
	local codex = self.scroll.data.codex
	local results = codex_type.search(codex, query)

	self:show_codex_entries(results)
end

downloaded_package_filenames = {}

function install(self, name)
	local codex = self.scroll.data.codex

	-- Check if it exists
	if not codex_type.exists(codex, name) then
		echo("Scroll \"" .. name .. "\" doesn't exist.\n")
		return
	end

	-- Check if its installed already
	if self.reliquary:exists(name) then
		local reliquary_scroll = self.reliquary:get(name)
		local codex_scroll = codex_type.get(codex, name)
		if not codex_type.version_greater_than(codex_scroll.version, reliquary_scroll.version) then
			echo("Codex version is less than installed version.\n")
			return
		end
	end

	local codex_scroll = codex_type.get(codex, name)
	for key, depend in pairs(codex_scroll.depends) do
		self:install(depend)
	end

	uninstallPackage(name)
	local filename = scroll.folder .. "/" .. codex_scroll.name .. ".zip"
	table.insert(self.downloaded_package_filenames, filename)
	downloadFile(filename, codex_scroll.url)
end

function download_and_install(event, filename)
	if table.index_of(downloaded_package_filenames, filename) == nil then
		return
	end

	installPackage(filename)
	os.remove(filename)
end

registerAnonymousEventHandler("sysDownloadDone", "scrolls.download_and_install")

function update(self, name)
	self:install(name)
end

function update_all(self)
	self.reliquary:for_each(function (scroll) self:install(scroll.name) end)
end

function show_codex(self)
	local codex = self.scroll.data.codex
	local results = codex.scrolls
	self:show_codex_entries(results)
end

function add_codex(self, url)
	local codex = self.scroll.data.codex
	if table.index_of(codex, url) == nil then
		codex_type.insert(codex, url)
		echo("Added codex URL.\n")
	else
		echo("Codex URL already exists.\n")
	end
end

downloaded_files = {}

function download_codexes(self)
	local folder = self.scroll.folder
	local data = self.scroll.data
	self.downloaded_files = {}
	for index, url in ipairs(data.options.codex_urls) do
		echo("Fetching " .. url .. " ...\n")
		local downloaded_file = folder .. "/codex_" .. index .. ".lua"
		table.insert(self.downloaded_files, downloaded_file)
		downloadFile(downloaded_file, url)
	end
end

function download(event, filename)
	if table.index_of(downloaded_files, filename) == nil then
		return
	end
	local codex = scroll.data.codex
	local new_codex = {}
	table.load(filename, new_codex)
	codex_type.merge(codex, new_codex)
	os.remove(filename)
end

function download_error(event, filename)
	echo("Could not download " .. filename .. "!\n")
end

registerAnonymousEventHandler("sysDownloadDone", "scrolls.download")

function copy_to_codex(self, name)
	local scroll = self.reliquary:get(name)
	if scroll == nil then
		echo("Scroll \"" .. name .. "\" doesn't exist.\n")
		return
	end

	local codex = self.scroll.data.codex
	codex_type.add(codex, scroll)
end

function save_codex(self)
	local target = self.scroll.folder .. "/codex.lua"
	local codex = self.scroll.data.codex
	table.save(target, codex)
	echo("Saved codex to " .. target .. ".\n")
end

function clear_codex(self)
	local codex = self.scroll.data.codex
	codex_type.clear(codex)
	echo("Cleared codex.\n")
end
