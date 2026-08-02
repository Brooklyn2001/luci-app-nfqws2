module("luci.controller.nfqws2", package.seeall)

function index()
	entry({"admin", "services", "nfqws2"}, template("nfqws2/index"), _("NFQWS2"), 60)
		.dependent = true
end
