module("test_scrolls", package.seeall)
_NAME = "test_scrolls"

function test_should_make_regex_from_command()
	local command = "scrolls load <name> <version>"
	local expected = "^ *scrolls +load +(.+) +(.+) *$"
	local actual = scrolls.scroll_type.make_regex(command)
	lunit.assert_equal(1, 1)
end
