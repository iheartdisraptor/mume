module("clock", package.seeall)

scroll = scrolls.reliquary:make("Clock")

--- Initialize Clock and its scroll metadata.
-- This is called automatically by Scrolls.
function scroll:initialize()
	self.subtitle = "Advanced MUME Time"

	self.url = "https://github.com/iheartdisraptor/mume/raw/master/mudlet/scrolls/Clock.zip"

	self:add_help("This script tracks the MUME time as well as the MUME date, allowing it to report, in addition to the current time, the dawn and dusk times, the real time to dawn and dusk, the date, and the season. In addition, the clock will optionally let you know every time a minute has passed and keep you informed as to the date and season every 24 minutes.")
	self:add_help("To use this script, simply look at any clock in game. You can then check the time with either 'cc' (check clock) or 'ct' (check time). You may change these aliases as needed in Script Editor > Aliases > Clock.")

	self:add_command("help", "Show this message.", "clock:show_help()")
	self:add_command("time", "Display the current time, dawn, and dusk if the clock is set.", "clock:show_time()")
	self:add_command("date", "Display the current date and season if the clock is set.", "clock:show_date()")
	self:add_command("time say", "Say the time out loud.", "clock:say_time()")
	self:add_command("time narrate", "Narrate the time.", "clock:narrate_time()")
	self:add_command("time tell <player>", "Tell the time to another player.", "clock:tell_time(player)")
	self:add_command("date say", "Say the date out loud.", "clock:say_date()")
	self:add_command("date narrate", "Narrate the date.", "clock:narrate_date()")
	self:add_command("date tell <player>", "Tell the date to another player.", "clock:tell_date(player)")
	self:add_command("unset", "Unset the clock:", "clock:unset()")
	self:add_command("toggle show time", "Toggle whether to display the time every MUME hour (1 minute).", "clock:toggle_show_time()")
	self:add_command("toggle show date", "Toggle whether to display the date every MUME day (24 minutes).", "clock:toggle_show_date()")
	self:add_command("highlight <color>", "Set the highlight color for data. Use \"grey\" for no highlight.", "clock:set_highlight(color)")
	self:add_command("colors", "Display a list of colors for use with the highlight option.", "showColors()")

	self:add_change("2015-2-12", { "Added aliases to say date, narrate date, and tell date to another player." })
	self:add_change("2015-2-10", { "Automatic loading/saving of clock data. May you never have to look at another clock again!" })
	self:add_change("2015-2-7", { "Improved the way options are set" })
	self:add_change("2015-2-3", { "Initial release" })

	self:add_depend("Time")
	self:add_author("Octavia")
	self:add_thanks("Cahal for testing")

	self.data.options = {
		show_time = true,
		show_date = true,
		highlight = "cyan",
	}

	self.data.is_set = false
end

function show_help(self)
	self.scroll:show_help()
end

function show_time(self)
	local mume_moment = self.get_mume_moment()

	cecho(self.display_time(mume_moment, true) .. "\n")
end

function show_date(self)
	local mume_moment = self.get_mume_moment()

	cecho(self.display_date(mume_moment, true) .. "\n")
end

function say_time(self)
	local mume_moment = self.get_mume_moment()
	local text = self.display_time(mume_moment, false)

	local data = self.scroll.data

	if data.is_set then
		send("say " .. text)
	else
		echo(text)
	end
end

function narrate_time(self)
	local mume_moment = self.get_mume_moment()
	local text = self.display_time(mume_moment, false)

	local data = self.scroll.data

	if data.is_set then
		send("narrate " .. text)
	else
		echo(text)
	end
end

function tell_time(self, player)
	local player = string.trim(matches[2])
	local mume_moment = self.get_mume_moment()
	local text = self.display_time(mume_moment, false)

	local data = self.scroll.data

	if data.is_set then
		send("tell " .. player .. " " .. text)
	else
		echo(text)
	end
end

function say_date(self)
	local mume_moment = self.get_mume_moment()
	local text = self.display_date(mume_moment, false)

	local data = self.scroll.data

	if data.is_set then
		send("say " .. text)
	else
		echo(text)
	end
end

function narrate_date(self)
	local mume_moment = self.get_mume_moment()
	local text = self.display_date(mume_moment, false)

	local data = self.scroll.data

	if data.is_set then
		send("narrate " .. text)
	else
		echo(text)
	end
end

function tell_date(self, player)
	local player = string.trim(matches[2])
	local mume_moment = self.get_mume_moment()
	local text = self.display_date(mume_moment, false)

	local data = self.scroll.data

	if data.is_set then
		send("tell " .. player .. " " .. text)
	else
		echo(text)
	end
end

function unset(self)
	echo("CLICK! You unset your self.\n")

	local data = self.scroll.data

	data.is_set = false
	data.start_mume_moment = nil
	data.start_time = nil

	disableTimer("Display Time and Date")
end

function toggle_show_time(self)
	local data = self.scroll.data

	data.show_time = not data.show_time

	if data.show_time then
		echo("Clock will now show time every minute.\n")
	else
		echo("Clock will NOT show time every minute.\n")
	end
end

function toggle_show_date(self)
	local data = self.scroll.data

	data.show_date = not data.show_date

	if data.show_date then
		echo("Clock will now show time every minute.\n")
	else
		echo("Clock will NOT show time every minute.\n")
	end
end

function set_highlight(self, color)
	local color = string.trim(matches[2])

	local data = self.scroll.data

	data.options.highlight = color

	cecho("Set highlight color to <" .. data.options.highlight .. ">" .. data.options.highlight .. ".\n")
end

mume_start_year = 2850

months_per_year = 12

days_per_month = 30
days_per_year = days_per_month * months_per_year

hours_per_day = 24

minutes_per_hour = 60
minutes_per_year = days_per_year * hours_per_day * minutes_per_hour
minutes_per_month = days_per_month * hours_per_day * minutes_per_hour
minutes_per_day = hours_per_day * minutes_per_hour

-- MUME TIME

function convert_mume_moment_to_mume_time(mume_moment)
	-- Calculate years since the start of MUME time
	local years_since = mume_moment.year - mume_start_year

	-- Convert year to MUME minutes
	local year_as_mume_minutes = years_since * minutes_per_year

	-- Convert month to MUME minutes
	local month_as_mume_minutes = (mume_moment.month - 1) * minutes_per_month

	-- Convert day to MUME minutes
	local day_as_mume_minutes = (mume_moment.day - 1) * minutes_per_day

	-- Convert time to MUME minutes
	local time_as_mume_minutes = convert_mume_time_to_mume_minutes(mume_moment.hour, mume_moment.minute, mume_moment.period)

	return year_as_mume_minutes + month_as_mume_minutes + day_as_mume_minutes + time_as_mume_minutes 
end

function convert_mume_time_to_mume_minutes(hour, minute, period)
	-- Convert hour to 24-hour
	local hour24
	if period == "pm" and hour == 12 then
		hour24 = 12	
	elseif period == "am" and hour == 12 then
		hour24 = 0
	elseif period == "pm" then
		hour24 = hour + 12
	else
		hour24 = hour
	end

	return hour24 * minutes_per_hour + minute
end

function convert_mume_time_to_mume_moment(mume_time)
	local mume_moment = {}

	-- Year
	local mume_time_in_years = math.floor(mume_time / minutes_per_year)
	mume_moment.year = mume_start_year + mume_time_in_years

	-- Month
	local mume_time_wo_years = mume_time - mume_time_in_years * minutes_per_year
	mume_moment.month = math.floor(mume_time_wo_years / minutes_per_month) + 1

	-- Day
	local mume_time_wo_years_months = mume_time_wo_years - (mume_moment.month - 1) * minutes_per_month
	mume_moment.day = math.floor(mume_time_wo_years_months / minutes_per_day) + 1

	-- Hour and period
	local mume_time_wo_years_months_days = mume_time_wo_years_months - (mume_moment.day - 1) * minutes_per_day
	local hour24 = math.floor(mume_time_wo_years_months_days / minutes_per_hour)

	if hour24 == 0 then
		mume_moment.hour = 12
		mume_moment.period = "am"
	elseif hour24 == 12 then
		mume_moment.hour = 12
		mume_moment.period = "pm"
	elseif hour24 > 12 then
		mume_moment.hour = hour24 - 12
		mume_moment.period = "pm"
	else
		mume_moment.hour = hour24
		mume_moment.period = "am"
	end

	-- Minute
	mume_moment.minute = mume_time_wo_years_months_days - hour24 * minutes_per_hour

	return mume_moment
end

function get_mume_moment()
	local data = scroll.data

	if not data.is_set then
		return nil
	end

	-- Get the number of real seconds since the clock was set
	local elapsed_seconds = time.get_time() - data.start_time

	-- Add the elapsed seconds to the start MUME time as MUME minutes
	local mume_time = data.start_mume_time + elapsed_seconds

	-- Convert MUME time to MUME moment
	local mume_moment = convert_mume_time_to_mume_moment(mume_time)

	return mume_moment
end

-- MONTH

westron_month_names = {
	[1] = "Afteryule",
	[2] = "Solmath",
	[3] = "Rethe",
	[4] = "Astron",
	[5] = "Thrimidge",
	[6] = "Forelithe",
	[7] = "Afterlithe",
	[8] = "Wedmath",
	[9] = "Halimath",
	[10] = "Winterfilth",
	[11] = "Blotmath",
	[12] = "Foreyule",
}

sindarin_month_names = {
	[1] = "Narwain",
	[2] = "Ninui",
	[3] = "Gwaeron",
	[4] = "Gwirith",
	[5] = "Lothron",
	[6] = "Norui",
	[7] = "Cerveth",
	[8] = "Urui",
	[9] = "Ivanneth",
	[10] = "Narbeleth",
	[11] = "Hithui",
	[12] = "Girithron",
}

westron_month_numbers = {
	["Afteryule"] = 1,
	["Solmath"] = 2,
	["Rethe"] = 3,
	["Astron"] = 4,
	["Thrimidge"] = 5,
	["Forelithe"] = 6,
	["Afterlithe"] = 7,
	["Wedmath"] = 8,
	["Halimath"] = 9,
	["Winterfilth"] = 10,
	["Blotmath"] = 11,
	["Foreyule"] = 12,
}

sindarin_month_numbers = {
	["Narwain"] = 1,
	["Ninui"] = 2,
	["Gwaeron"] = 3,
	["Gwirith"] = 4,
	["Lothron"] = 5,
	["Norui"] = 6,
	["Cerveth"] = 7,
	["Urui"] = 8,
	["Ivanneth"] = 9,
	["Narbeleth"] = 10,
	["Hithui"] = 11,
	["Girithron"] = 12,
}

dawn = {
	[1] = "8 am",
	[2] = "9 am",
	[3] = "8 am",
	[4] = "7 am",
	[5] = "7 am",
	[6] = "6 am",
	[7] = "5 am",
	[8] = "4 am",
	[9] = "5 am",
	[10] = "6 am",
	[11] = "7 am",
	[12] = "7 am",
}

dusk = {
	[1] = "6 am",
	[2] = "5 am",
	[3] = "6 am",
	[4] = "7 am",
	[5] = "8 am",
	[6] = "8 am",
	[7] = "9 am",
	[8] = "10 am",
	[9] = "9 am",
	[10] = "8 am",
	[11] = "8 am",
	[12] = "7 am",
}

dawn_as_minutes = {
	[1] = 8 * 60,
	[2] = 9 * 60,
	[3] = 8 * 60,
	[4] = 7 * 60,
	[5] = 7 * 60,
	[6] = 6 * 60,
	[7] = 5 * 60,
	[8] = 4 * 60,
	[9] = 5 * 60,
	[10] = 6 * 60,
	[11] = 7 * 60,
	[12] = 7 * 60,
}

dusk_as_minutes = {
	[1] = 6 * 60 + 12 * 60,
	[2] = 5 * 60 + 12 * 60,
	[3] = 6 * 60 + 12 * 60,
	[4] = 7 * 60 + 12 * 60,
	[5] = 8 * 60 + 12 * 60,
	[6] = 8 * 60 + 12 * 60,
	[7] = 9 * 60 + 12 * 60,
	[8] = 10 * 60 + 12 * 60,
	[9] = 9 * 60 + 12 * 60,
	[10] = 8 * 60 + 12 * 60,
	[11] = 8 * 60 + 12 * 60,
	[12] = 7 * 60 + 12 * 60,
}

function convert_month_name_to_month_number(name)
	local number = westron_month_numbers[name]

	if number == nil then
		number = sindarin_month_numbers[name]
		use_westron_calendar = false
	else
		use_westron_calendar = true
	end

	return number
end

function convert_month_number_to_month_name(number)
	if use_westron_calendar then
		return westron_month_names[number]
	end

	return sindarin_month_names[number]
end

function is_last_day_of_month(mume_moment)
	return mume_moment.day == days_per_month
end

-- DAWN/DUSK

function get_dawn(mume_moment)
	local month = get_effective_month(mume_moment)

	return dawn[month]
end

function get_dusk(mume_moment)
	local month = get_effective_month(mume_moment)

	return dusk[month]
end

function get_time_to_dawn(mume_moment)
	local minutes_since_12am = convert_mume_time_to_mume_minutes(mume_moment.hour, mume_moment.minute, mume_moment.period)
	local month = get_effective_month(mume_moment)
	local dawn = dawn_as_minutes[month]

	if dawn_passed(mume_moment) then
		dawn = dawn + hours_per_day * minutes_per_hour
	end

	local time_to_dawn = dawn - minutes_since_12am

	return time.convert_seconds_to_hms(time_to_dawn)
end

function get_time_to_dusk(mume_moment)
	local minutes_since_12am = convert_mume_time_to_mume_minutes(mume_moment.hour, mume_moment.minute, mume_moment.period)
	local month = get_effective_month(mume_moment)
	local dusk = dusk_as_minutes[month]

	if dusk_passed(mume_moment) then
		dusk = dusk + hours_per_day * minutes_per_hour
	end

	local time_to_dusk = dusk - minutes_since_12am

	return time.convert_seconds_to_hms(time_to_dusk)
end

function dawn_passed(mume_moment)
	local minutes_since_12am = convert_mume_time_to_mume_minutes(mume_moment.hour, mume_moment.minute, mume_moment.period)
	local dawn_in_minutes = dawn_as_minutes[mume_moment.month]

	return minutes_since_12am > dawn_in_minutes
end

function dusk_passed(mume_moment)
	local minutes_since_12am = convert_mume_time_to_mume_minutes(mume_moment.hour, mume_moment.minute, mume_moment.period)
	local dusk_in_minutes = dusk_as_minutes[mume_moment.month]

	return minutes_since_12am > dusk_in_minutes
end

function get_effective_month(mume_moment)
	local month = mume_moment.month
	
	if dawn_passed(mume_moment) and
		is_last_day_of_month(mume_moment) then
		month = (month + 1) % 12
	end

	return month
end

-- SEASON

season = {
	"Winter",
	"Winter",
	"Winter",
	"Spring",
	"Spring",
	"Spring",
	"Summer",
	"Summer",
	"Summer",
	"Autumn",
	"Autumn",
	"Autumn",
}

month_of_season = {
	"first",
	"second",
	"third",
	"first",
	"second",
	"third",
	"first",
	"second",
	"third",
	"first",
	"second",
	"third",
}

function get_season(mume_moment)
	return season[mume_moment.month]
end

function get_month_of_season(mume_moment)
	return month_of_season[mume_moment.month]
end

-- DISPLAY

function display_time(mume_moment, use_color)
	local data = scroll.data

	if not data.is_set then
		return "Your clock is not set."
	end

	local highlight = ""
	local grey = ""
	if use_color then
		highlight = get_highlight()
		grey = "<grey>"
	end

	local month_name = convert_month_number_to_month_name(mume_moment.month)
	local dawn = get_dawn(mume_moment)
	local dusk = get_dusk(mume_moment)
	local time_to_dawn = get_time_to_dawn(mume_moment)
	local time_to_dusk = get_time_to_dusk(mume_moment)

	local padded_minute = mume_moment.minute
	if padded_minute < 10 then
		padded_minute = "0" .. padded_minute
	end

	local result = "Time: " .. highlight .. mume_moment.hour .. ":" .. padded_minute .. " " .. mume_moment.period .. grey .. "."
	result = result .. " Dawn: " .. highlight .. dawn .. grey .. " (" .. highlight .. time_to_dawn .. grey .. ")."
	result = result .. " Dusk: " .. highlight .. dusk .. grey .. " (" .. highlight .. time_to_dusk .. grey .. ")."

	return result
end

function display_date(mume_moment, use_color)
	local data = scroll.data

	if not data.is_set then
		return "Your clock is not set."
	end

	local highlight = ""
	local grey = ""
	if use_color then
		highlight = get_highlight()
		grey = "<grey>"
	end

	local month_name = convert_month_number_to_month_name(mume_moment.month)
	local season = get_season(mume_moment)
	local month_of_season = get_month_of_season(mume_moment)

	local result = "Date: " .. highlight .. mume_moment.year .. "-" .. mume_moment.month .. "-" .. mume_moment.day .. grey .. "."
	result = result .. " Season: The " .. highlight .. month_of_season .. grey .. " month of " .. highlight .. season .. grey .. " (" .. highlight .. month_name .. grey .. ")." 

	return result
end

function display_timer(mume_moment)
	local data = scroll.data

	if data.options.show_time then
		cecho(display_time(mume_moment, true) .. "\n")
	end

	if data.options.show_date and
	   mume_moment.hour == 12 and
		mume_moment.period == "am" then
		cecho(display_date(mume_moment, true) .. "\n")
	end
end

function adjust_timer(minute)
	-- Enable the timer to show the time and date, but offset it so it appears on the hour
	if minute ~= 0 then
		local time_offset = 60 - minute
		local timer = tempTimer(time_offset, [[ local mume_moment = clock.get_mume_moment() clock.display_timer(mume_moment) enableTimer("Display Time and Date") ]])
		enableTimer(timer)
	end
end

function get_highlight()
	local data = scroll.data
	return "<" .. data.options.highlight .. ">"
end
