local m, s, o
local sys = require "luci.sys"
local uci = require "luci.model.uci".cursor()
local iwinfo = require "iwinfo"

m = Map("easymesh",
    translate("Easy Mesh WiFi Setup"),
    translate("Powered by Batman-adv (Better Approach To Mobile Adhoc Networking - Advanced). First setup your Mesh Gateway Server then setup the nodes. When configuring a Mesh Node, first activate your mesh WiFi on the radio device and establish a connection. Then enable it as a DHCP node. The default settings are typically adequate for most Mesh WiFi configurations.")
    .. "<br/>" .. translate("Official website:") .. ' <a href="https://www.open-mesh.org/projects/batman-adv/wiki" target="_blank">https://www.open-mesh.org/projects/batman-adv/wiki</a>'
)

-- ? Ensure get_verbose_hw_info() is declared first
local function get_verbose_hw_info(iface)
    local type = iwinfo.type(iface)
    if not type then return "Generic" end

    local driver = iwinfo[type]
    if not driver then return "Driver not supported" end

    local hw_name = driver.hardware_name and driver.hardware_name(iface) or "Unknown hardware"
    local hw_modes = driver.hwmodelist and driver.hwmodelist(iface) or {}

    local supported_modes = {}
    for mode, supported in pairs(hw_modes) do
        if supported then
            table.insert(supported_modes, mode)
        end
    end

    return hw_name .. " (" .. (#supported_modes > 0 and table.concat(supported_modes, "/") or "No mode information") .. ")"
end

-- ? Fixed Neighbor Detection Function
function detect_Node()
    local data = {}

    -- Run batctl to list neighbor nodes
    local lps = luci.util.execi("batctl n 2>/dev/null | tail -n +3")  -- Skip headers

    for line in lps do
        -- Print each raw line for debugging
        print("DEBUG: Raw line -> [" .. line .. "]")

        -- Skip invalid lines (headers)
        if string.match(line, "Neighbor%s+last%-seen%s+speed%s+IF") then
            print("DEBUG: Skipping header line -> [" .. line .. "]")
        else
            -- Normalize spacing
            line = string.gsub(line, "%s+", " ")

            -- Extract fields
            local neighbor, lastseen, interface = line:match("(%S+)%s+(%S+)%s+%(.+%)%s+%[(%S+)%]")

            -- Debugging: Show extracted values
            if neighbor and lastseen and interface then
                print(string.format("DEBUG: Parsed -> Interface: %s, Neighbor: %s, Last Seen: %s", interface, neighbor, lastseen))
                
                table.insert(data, {
                    ["IF"] = interface,
                    ["Neighbor"] = neighbor,
                    ["lastseen"] = lastseen
                })
            else
                print("DEBUG: Skipped line due to incorrect format -> [" .. line .. "]")
            end
        end
    end
    return data
end

-- ? Get Active Node Count Correctly
local Nodes = luci.sys.exec("batctl n 2>/dev/null | grep -E '^[0-9a-fA-F]{2}:' | wc -l")

-- ? Display Mesh Status Table
local Node = detect_Node()
v = m:section(Table, Node, translate("Mesh Status"), "<b>" .. translate("Number of Active Nodes: ") .. Nodes .. "</b>")
v:option(DummyValue, "IF", translate("Interface"))
v:option(DummyValue, "Neighbor", translate("Neighbor Nodes"))
v:option(DummyValue, "lastseen", translate("Last Seen Timestamp"))

s = m:section(TypedSection, "easymesh", translate("Mesh Settings"))
s.anonymous = true

s:tab("setup", translate("Basic Setup"))
s:tab("apmode", translate("AP Mode"))
s:tab("advanced", translate("Advanced Settings"))

-- Enable EasyMesh
o = s:taboption("setup", Flag, "enabled", translate("Enable Mesh Networking"),
    translate("Toggle this switch to activate or deactivate the Mesh Network on this device according to the settings specified in this configuration."))
o.default = 0

-- Mesh Mode Selection
o = s:taboption("setup", ListValue, "role", translate("Mesh Mode"),
    translate("Choose whether this device is a <b>Server</b>, <b>Client</b>, or <b>Node</b> in the mesh network."))
o:value("server", translate("Server"))
o:value("off", translate("Node"))
o:value("client", translate("Client"))
o.default = "server"

-- Regular WiFi Network SSID
o = s:taboption("setup", Value, "wifi_id", translate("WiFi Network SSID"),
    translate("SSID for the regular WiFi network."))
o.default = "easymesh_AC"

-- Select the WiFi radio for the regular AP
wifiRadio = s:taboption("setup", ListValue, "wifi_radio", translate("Regular AP Radio"),
    translate("Select the radio to be used for the regular WiFi access point."))

uci:foreach("wireless", "wifi-device",
    function(s)
        local iface = s['.name']
        local hw_modes = get_verbose_hw_info(iface)
        local desc = string.format("%s (%s)", iface, hw_modes)
        wifiRadio:value(iface, desc)
    end)
wifiRadio.default = "radio1"
wifiRadio.widget = "select"

-- Select the WiFi radio for mesh backhaul
apRadio = s:taboption("setup", MultiValue, "apRadio", translate("Mesh Radio(s)"),
    translate("Select a radio interface for mesh backhaul traffic."))

uci:foreach("wireless", "wifi-device",
    function(s)
        local iface = s['.name']
        local hw_modes = get_verbose_hw_info(iface)
        local desc = string.format("%s (%s)", iface, hw_modes)
        apRadio:value(iface, desc)
    end)
apRadio.default = "radio0"
apRadio.widget = "select"

o = s:taboption("setup", Value, "mesh_id", translate("Mesh Network SSID"), translate('<p style="text-align: justify; padding: 0;"><strong>Ensure that the SSID is the same across all the servers/nodes in your mesh network.</strong></p>'))
o.default = "easymesh_AC"

encryption = s:taboption("setup", Flag, "encryption", translate("Password Protection"), translate('<p style="text-align: justify; padding: 0;"><strong>Enable this switch to require a password to join your Mesh Network.</strong></p>'))
encryption.default = 0

o = s:taboption("setup", Value, "key", translate("Mesh Password"))
o.default = "easymesh"
o:depends("encryption", 1)
o.password = true
o.datatype = "minlength(8)"

btnReapply = s:taboption("setup", Button, "_btn_reapply", translate("Reapply EasyMesh Settings"), translate('<p style="text-align: justify; padding: 0;"><strong>Use this button to apply/reapply EasyMesh configuration after you Save & Apply.</p></strong>'))
function btnReapply.write()
    io.popen("/easymesh/easymesh.sh &")
end

enable_kvr = s:taboption("advanced", Flag, "kvr", translate("K/V/R"), translate('<p style="text-align: justify; padding: 0;"><strong>Leave these settings as default unless you know what you\'re doing</p></strong>'))
enable_kvr.default = 1

mobility_domain = s:taboption("advanced", Value, "mobility_domain", translate("Mobility Domain"))
mobility_domain.default = "4f57"
mobility_domain.datatype = "and(hexstring,rangelength(4,4))"

rssi_val = s:taboption("advanced", Value, "rssi_val", translate("Good RSSI Threshold"))
rssi_val.default = "-60"
rssi_val.datatype = "range(-120,-1)"

low_rssi_val = s:taboption("advanced", Value, "low_rssi_val", translate("Bad RSSI Threshold"))
low_rssi_val.default = "-88"
low_rssi_val.datatype = "range(-120,-1)"

---- ap_mode
o = s:taboption("apmode", Value, "hostname", translate("Node Hostname"))
o.default = "node2"
o:value("node2", "node2")
o:value("node3", "node3")
o:value("node4", "node4")
o:value("node5", "node5")
o:value("node6", "node6")
o:value("node7", "node7")
o:value("node8", "node8")
o:value("node9", "node9")
o.datatype = "string"
o:depends({role="off",role="client"})

-- IP Mode (DHCP or Static)
ipmode = s:taboption("apmode", ListValue, "ipmode", translate("IP Mode"), translate("Choose if the node uses DHCP or a Static IP"))
ipmode:value("dhcp", translate("DHCP"))
ipmode:value("static", translate("Static"))
ipmode.default = "dhcp"
ipmode:depends({role="off",role="client"})

-- Static IP address
o = s:taboption("apmode", Value, "ipaddr", translate("Static IP Address"))
o.default = "192.168.8.3"
o.datatype = "ip4addr"
o:depends({ipmode="static",role="off",role="client"})

-- DNS (Mesh Gateway IP Address)
o = s:taboption("apmode", Value, "gateway", translate("Mesh Gateway IP Address"))
o.default = "192.168.8.1"
o.datatype = "ip4addr"
o:depends({ipmode="static",role="off",role="client"})

-- IPv4 netmask
o = s:taboption("apmode", Value, "netmask", translate("IPv4 netmask"))
o.default = "255.255.255.0"
o.datatype = "ip4addr"
o:depends({ipmode="static",role="off",role="client"})

-- IPv4 netmask
o = s:taboption("apmode", Value, "dns", translate("DNS Server"))
o.default = "192.168.8.1"
o.datatype = "ip4addr"
o:depends({ipmode="static",role="off",role="client"})

btnAPMode = s:taboption("apmode", Button, "_btn_apmode", translate("Enable Dumb AP Mode"), translate("WARNING: THIS WILL CHANGE THIS NODE'S IP ADDRESS, YOU WILL LOOSE ACCESS TO THIS UI"))
function btnAPMode.write()
    io.popen("/easymesh/easymesh.sh dumbap &")
end
btnAPMode:depends({role="off",role="client"})

return m