-- TorGuard.net

module("luci.controller.easymesh", package.seeall)

function index()
	if not nixio.fs.access("/etc/config/easymesh") then
		return
	end

	local page

	page = entry({"admin", "network", "easymesh"}, cbi("easymesh"), _("Easy Mesh"), 60)
	page.dependent = true
	page.acl_depends = { "luci-app-easymesh" }
end
