local m
local s
local http = require "luci.http"

m = Map("nfqws2", translate("NFQWS2"),
	translate("Web interface for managing nfqws2 DPI bypass utility. " ..
		"Settings are stored in UCI and auto-generated into nfqws2.conf on service start."))

-- Service status & control widget
s = m:section(SimpleSection)
s.template = "nfqws2/status"

-- General settings — named section for "general"
s = m:section(NamedSection, "general", "nfqws2", translate("General Settings"))
s.addremove = false

s:option(Flag, "enabled", translate("Enabled"),
	translate("Enable nfqws2 service"))

s:option(Value, "isp_interface", translate("Network Interface"),
	translate("Provider network interface, e.g. eth3 or ppp0. " ..
		"Can specify multiple interfaces separated by space."))

s:option(Value, "tcp_ports", translate("TCP Ports"),
	translate("TCP ports for iptables rules. Leave empty to disable TCP processing."))

s:option(Value, "udp_ports", translate("UDP Ports"),
	translate("UDP ports for iptables rules. Leave empty to disable UDP processing."))

s:option(Flag, "ipv6_enabled", translate("IPv6 Enabled"),
	translate("Process IPv6 connections"))

s:option(Value, "policy_name", translate("Policy Name"),
	translate("Keenetic access policy name. Only devices in this policy will be processed."))

s:option(Flag, "policy_exclude", translate("Policy Exclude Mode"),
	translate("When enabled, all devices EXCEPT those in the policy will be processed."))

s:option(Value, "nfqueue_num", translate("NFQueue Number"),
	translate("Netfilter NFQUEUE queue number"))

s:option(Value, "user", translate("Run As User"),
	translate("User to run nfqws2 process as"))

s:option(Flag, "log_level", translate("Debug Logging"),
	translate("Enable debug-level syslog logging"))

local mode = s:option(ListValue, "nfqws_mode", translate("Working Mode"),
	translate("How nfqws2 selects which domains to process"))
mode:value("MODE_AUTO", translate("Auto") .. " \u2014 " .. translate("Automatically detects blocked resources"))
mode:value("MODE_LIST", translate("List") .. " \u2014 " .. translate("Only processes domains from user.list"))
mode:value("MODE_ALL",  translate("All") .. " \u2014 " .. translate("Processes all traffic except exclude.list"))

-- Strategies — named section for "strategies"
s = m:section(NamedSection, "strategies", "nfqws2", translate("Strategies"))
s.addremove = false

local tv
tv = s:option(TextValue, "nfqws_base_args", translate("Startup Arguments"),
	translate("Lua init scripts, blob definitions, and other base arguments"))
tv.rows = 6

tv = s:option(TextValue, "nfqws_args", translate("Base Strategy (HTTPS/HTTP)"),
	translate("Main DPI bypass strategy for HTTPS and HTTP traffic"))
tv.rows = 10

tv = s:option(TextValue, "nfqws_args_quic", translate("QUIC Strategy"),
	translate("DPI bypass strategy for QUIC/UDP traffic"))
tv.rows = 5

tv = s:option(TextValue, "nfqws_args_udp", translate("UDP Strategy"),
	translate("Strategy for UDP traffic (WireGuard, STUN, etc.). Does not use domain lists."))
tv.rows = 8

tv = s:option(TextValue, "nfqws_args_custom", translate("Custom Strategy"),
	translate("Additional custom strategies. Use --new to separate multiple strategies."))
tv.rows = 4

tv = s:option(TextValue, "nfqws_args_ipset", translate("IPSET Arguments"),
	translate("IP list paths for include/exclude"))
tv.rows = 2

return m
