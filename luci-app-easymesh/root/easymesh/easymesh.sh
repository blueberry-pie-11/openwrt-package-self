#!/bin/bash

# Dumb AP Mode Block
set_apmode() {
    # Backup our configs
    rm /etc/config/*.meshbak
    cp /etc/config/wireless /etc/config/wireless.meshbak
    cp /etc/config/network /etc/config/network.meshbak
    cp /etc/config/dhcp /etc/config/dhcp.meshbak
    cp /etc/config/system /etc/config/system.meshbak
    cp /etc/config/firewall /etc/config/firewall.meshbak

    uci set easymesh.config.ap_mode_enabled=1

    # Disabling and stopping services not needed
    for service in firewall dnsmasq odhcpd; do
        if /etc/init.d/$service enabled; then
            echo "Disabling and stopping $service..."
            /etc/init.d/$service disable >/dev/null 2>&1
            /etc/init.d/$service stop >/dev/null 2>&1
        else
            echo "$service is not enabled, skipping..."
        fi
    done

    if [ "$(uci -q get easymesh.config.ipmode)" == "static" ]; then
        # Set static IP
        uci set network.lan.proto='static'
        uci set network.lan.ipaddr=$(uci -q get easymesh.config.ipaddr)
        uci set network.lan.netmask=$(uci -q get easymesh.config.netmask)
        uci set network.lan.gateway=$(uci -q get easymesh.config.gateway)
        uci set network.lan.dns=$(uci -q get easymesh.config.dns)
    else
        # Set LAN interface to DHCP client
        uci del network.lan.ipaddr
        uci del network.lan.netmask
        uci set network.lan.proto='dhcp'
    fi

    # Delete wan interfaces
    uci del network.wan
    uci del network.wan6

    # Set firewall disabled
    uci del firewall.lan.network
    uci del firewall.wan.network

    # Just in case, set lan to be ignored by dhcp
    uci set dhcp.lan.ignore='1'
    uci del dhcp.wan

    # Fix this for proper variable name
    HOSTNAME=$(uci -q get easymesh.config.hostname)
    # Set netmask and gateway (assuming $netmask and $dns didn't break more stuff)
    uci set system.@system[0].hostname=$HOSTNAME

    # Retrieve the list of ports for network.@device[0]
    LAN_PORTS=$(uci get network.@device[0].ports)

    # Check if 'wan' is already in the list of ports
    if echo "$LAN_PORTS" | grep -q -w 'wan'; then
        echo "'wan' is already in the list of ports for lan."
    else
        echo "'wan' is not in the list. Adding it to lan ports..."
        uci add_list network.@device[0].ports='wan'
    fi

    # Get the radio to be used for mesh from the config
    AP_RADIO=$(uci -q get easymesh.config.apRadio)

    # Our config set mesh_id that we are looking for
    MESH_ID=$(uci -q get easymesh.config.mesh_id)

    # Check if MESH_NAME and AP_RADIO are set, if so find set our network
    if [ ! -z "$AP_RADIO" ] && [ ! -z "$MESH_ID" ]; then
        # Loop through the radios and update the network settings
        for radio in $AP_RADIO; do
            # Get the number from the radio name
            radio_num="${radio#radio}"
            echo "Checking wireless networks on radio${radio_num} for ssid '$MESH_ID'"

            # Loop through all the wireless interfaces associated with the current radio
            uci show wireless | grep "wireless\.wifinet${radio_num}" | grep '\.ssid=' | while read -r ssid_line; do
                # Extract the interface identifier
                wifinet=$(echo "$ssid_line" | cut -d'.' -f2)
                # Extract the ssid value
                interface_ssid=$(echo "$ssid_line" | cut -d'=' -f2 | tr -d "'")

                if [ "$interface_ssid" = "$MESH_ID" ]; then
                    echo "Found target SSID '$MESH_ID' on wireless wifinet ${wifinet} on radio ${radio}"

                    # Get the current network setting for this wifinet
                    current_network=$(uci get "wireless.${wifinet}.network")
                    echo "Current network setting for ${wifinet}: ${current_network}"

                    # Check if 'mesh_batman' is part of the current network setting
                    if echo "$current_network" | grep -qv 'mesh_batman'; then
                        # 'mesh_batman' is not in the network setting, so we add it
                        new_network="${current_network} mesh_batman"
                        uci set "wireless.${wifinet}.network=${new_network}"
                        echo "Added 'mesh_batman' to the network setting for ${wifinet}."
                        uci commit wireless
                    else
                        echo "'mesh_batman' is already in the network setting for ${wifinet}."
                    fi
                else
                    echo "SSID '$interface_ssid' on wireless wifinet ${wifinet} does not match target SSID '$MESH_ID'. Skipping..."
                fi
            done
        done
    fi

    # Commit changes to make sure the wireless configuration is updated
    uci commit

    # Restart wireless
    wifi reload

    # Tell openwrt to reload the configs
    reload_config
    /etc/init.d/network reload
}

disable_apmode() {
    # Config Count Must Match 5
    local CONFIG_COUNT=0

    # Check our configs exist, then restore them
    [ -f /etc/config/wireless.meshbak ] && {
        CONFIG_COUNT=$((CONFIG_COUNT+1))
    }
    [ -f /etc/config/network.meshbak ] && {
        CONFIG_COUNT=$((CONFIG_COUNT+1))
    }
    [ -f /etc/config/dhcp.meshbak ] && {
        CONFIG_COUNT=$((CONFIG_COUNT+1))
    }
    [ -f /etc/config/system.meshbak ] && {
        CONFIG_COUNT=$((CONFIG_COUNT+1))
    }
    [ -f /etc/config/firewall.meshbak ] && {
        CONFIG_COUNT=$((CONFIG_COUNT+1))
    }

    # Check if we have 5 configs to restore
    if [ $CONFIG_COUNT -eq 5 ]; then
        echo "Restoring configs from backup..."
        echo "Existing configs will be moved to /etc/config/*.dumbap for reference."
        rm /etc/config/*.dumbap
        mv /etc/config/dhcp /etc/config/dhcp.dumbap
        mv /etc/config/network /etc/config/network.dumbap
        mv /etc/config/wireless /etc/config/wireless.dumbap
        mv /etc/config/system /etc/config/system.dumbap
        mv /etc/config/firewall /etc/config/firewall.dumbap
        mv /etc/config/dhcp.meshbak /etc/config/dhcp
        mv /etc/config/network.meshbak /etc/config/network
        mv /etc/config/wireless.meshbak /etc/config/wireless
        mv /etc/config/system.meshbak /etc/config/system
        mv /etc/config/firewall.meshbak /etc/config/firewall

        # Enable and start services not needed
        for service in firewall dnsmasq odhcpd; do
            if /etc/init.d/$service disabled; then
                echo "Enabling and starting $service..."
                /etc/init.d/$service enable
                /etc/init.d/$service start
            else
                echo "$service is not disabled, skipping..."
            fi
        done

        # Reload all the system configs
        reload_config
        /etc/init.d/network reload
        wifi reload
    else
        echo "Unable to restore configs as none were found."
    fi
}

clear_by_mesh_id() {
    # Passed mesh_id to clear, allows us to multipurpose this function
    MESH_ID_TO_CLEAR=$1

    # Get the radio to be used for mesh from the config
    AP_RADIO=$(uci -q get easymesh.config.apRadio)

    # Check if MESH_NAME is not empty
    if [ -z "$MESH_ID_TO_CLEAR" ]; then
        echo "No mesh_id passed to remove from wireless."
        return;
    fi

    # Get the output from uci show wireless
    uci_output=$(uci show wireless)

    # Find the mesh network with the matching mesh_id and delete it
    mesh_id=$(echo "$uci_output" | grep -o "wireless\.mesh_radio[0-9]*\.mesh_id='$MESH_ID_TO_CLEAR'")
    if [ ! -z "$mesh_id" ]; then
        # Extract the number from the interface name
        mesh_radio=$(echo "$mesh_id" | grep -o "radio[0-9]*")
        # Loop through radios and delete the mesh networks
        for radio in $AP_RADIO; do
            # Delete the network
            uci del wireless.mesh_$radio
            echo "Deleted mesh network with mesh_id '$MESH_ID_TO_CLEAR' on $radio"
        done
    fi

    # Find the wireless network with the matching ssid and delete it
    ssid=$(echo "$uci_output" | grep -o "wireless\.wifinet[0-9]*\.ssid='$MESH_ID_TO_CLEAR'")
    if [ ! -z "$ssid" ]; then
        # Loop through  radios and delete the wireless networks
        for radio in $AP_RADIO; do
            # Get the number from the radio name
            radio_num="${radio#radio}"
            # Delete the network
            uci del wireless.wifinet$radio_num
            echo "Deleted wireless network with ssid '$MESH_ID_TO_CLEAR' on radio$radio_num"
        done
    fi

    # Commit changes to make sure the wireless configuration is updated
    uci commit wireless

    # Restart wireless to apply changes
    wifi reload
    echo "Wireless interfaces reloaded."
}

create_batman_network() {
    echo "Setting up Batman network..."

    # Ensure bat0 exists
    if uci -q get network.bat0 >/dev/null; then
        echo "bat0 interface already exists."
    else
        uci set network.bat0=interface
        uci set network.bat0.proto='batadv'
        uci set network.bat0.routing_algo='BATMAN_V'
        uci set network.bat0.aggregated_ogms='1'
        uci set network.bat0.ap_isolation='0'
        uci set network.bat0.bonding='1'
        uci set network.bat0.bridge_loop_avoidance='1'
        uci set network.bat0.distributed_arp_table='1'
        uci set network.bat0.fragmentation='1'
        uci set network.bat0.hop_penalty='30'
        uci set network.bat0.isolation_mark='0x00000000/0x00000000'
        uci set network.bat0.log_level='0'
        uci set network.bat0.multicast_fanout='16'
        uci set network.bat0.multicast_mode='1'
        uci set network.bat0.network_coding='0'
        uci set network.bat0.orig_interval='1000'
        echo "bat0 interface has been created."
    fi

    # Set the bat0 role
    BAT_ROLE=$(uci -q get easymesh.config.role)
    if [ "${BAT_ROLE}" == "server" ]; then
        uci set network.bat0.gw_mode='server'
        echo "Setting bat0 as a server."

        # Remove bat0 from Batman to act as a bridge
        if uci -q get network.mesh_batman.master | grep -q 'bat0'; then
            uci del network.mesh_batman.master
            echo "Removed bat0 from Batman mesh."
        fi

        # Ensure bat0 is part of br-lan bridge
        if ! uci -q get network.@device[0].ports | grep -q 'bat0'; then
            uci add_list network.@device[0].ports='bat0'
            echo "Added bat0 to br-lan for mesh bridging."
        fi

        # Firewall updates: Add bat0 to LAN, add batman to WAN
        uci set firewall.@zone[0].network="lan bat0"
        uci set firewall.@zone[1].network="wan mesh_batman"
        uci commit firewall

    elif [ "${BAT_ROLE}" == "client" ] || [ "${BAT_ROLE}" == "off" ]; then
        uci set network.bat0.gw_mode='off'
        echo "Disabling bat0 gateway mode."

        # Delete all firewall zones
        echo "Deleting all firewall zones..."
        uci delete firewall.@zone[0]
        uci delete firewall.@zone[1]
        uci delete firewall.@zone[2]
        uci commit firewall

        # Add bat0 and wan to br-lan
        if ! uci -q get network.@device[0].ports | grep -q 'bat0'; then
            uci add_list network.@device[0].ports='bat0'
        fi
        if ! uci -q get network.@device[0].ports | grep -q 'wan'; then
            uci add_list network.@device[0].ports='wan'
        fi
        uci commit network
        echo "Added bat0 and wan to br-lan for client/none mode."

        # Disable unnecessary services
        echo "Disabling unwanted services..."
        for service in dnsmasq firewall odhcpd; do
            if /etc/init.d/$service enabled; then
                /etc/init.d/$service disable >/dev/null 2>&1
                /etc/init.d/$service stop >/dev/null 2>&1
                echo "Disabled and stopped $service"
            else
                echo "$service was already disabled."
            fi
        done
    fi

    # Ensure Batman interface does not have a device specified
    if uci -q get network.mesh_batman.device; then
        uci del network.mesh_batman.device
        echo "Removed device assignment from mesh_batman to keep it unspecified."
    fi

    # Check if network.mesh_batman already exists
    if uci -q get network.mesh_batman >/dev/null; then
        echo "network.mesh_batman interface already exists."
    else
        uci set network.mesh_batman=interface
        uci set network.mesh_batman.proto='batadv_hardif'
        uci set network.mesh_batman.master='bat0'
        uci set network.mesh_batman.mtu='1536'
        echo "Configured mesh_batman interface."
    fi

    # Commit network changes
    uci commit network
    echo "Network settings updated."
}

process_radios() {
    # Get the radio to be used for mesh from the config
    AP_RADIO=$(uci -q get easymesh.config.apRadio)

    # Check if AP_RADIO is empty, if so exit
    if [ -z "$AP_RADIO" ]; then
        echo "No radio specified in the config, exiting."
        exit 1
    fi

    # Loop through the selected radios
    for CURRENT_RADIO in $AP_RADIO; do
        echo "Setting up mesh networks for: $CURRENT_RADIO"
        setup_mesh_radio $CURRENT_RADIO
    done     
}

# This is called from the process_radios function and is passed the radio to be used for mesh
setup_mesh_radio() {
    echo "Setting up radios for Mesh and Regular WiFi"

    # Get the regular WiFi SSID and radio from the config
    WIFI_ID=$(uci -q get easymesh.config.wifi_id)
    WIFI_RADIO=$(uci -q get easymesh.config.wifi_radio)

    # Get the mesh name and radio from the config
    MESH_ID=$(uci -q get easymesh.config.mesh_id)
    AP_RADIO=$(uci -q get easymesh.config.apRadio)

    # Ensure both SSIDs are set
    if [ -z "$WIFI_ID" ]; then
        echo "Regular WiFi SSID is empty. Using default."
        WIFI_ID="easymesh_AC"
    fi
    if [ -z "$MESH_ID" ]; then
        echo "Error: Mesh SSID is empty. Cannot configure mesh."
        return
    fi

    # Generate Mesh AP SSID by appending '-mesh'
    MESH_SSID="${MESH_ID}-mesh"

    echo "Regular AP SSID: $WIFI_ID on $WIFI_RADIO"
    echo "Mesh SSID: $MESH_SSID on $AP_RADIO"

    # Get the mobility domain from the config
    MOBILITY_DOMAIN=$(uci -q get easymesh.config.mobility_domain)

    # If mobility domain is empty, generate a random 4-digit hex
    if [ -z "$MOBILITY_DOMAIN" ]; then
        MOBILITY_DOMAIN=$(hexdump -n 2 -e '2/1 "%02x"' /dev/urandom)
        uci set easymesh.config.mobility_domain=$MOBILITY_DOMAIN
        uci commit easymesh
    fi

    # Get encryption settings
    ENCRYPTION_ENABLED=$(uci -q get easymesh.config.encryption)
    NETWORK_KEY=$(uci -q get easymesh.config.key)

    ###### Regular WiFi AP Configuration (Set first, then apply WiFi) ######
    if [ ! -z "$WIFI_RADIO" ]; then
        echo "Configuring regular WiFi AP on $WIFI_RADIO"

        uci set wireless.wifi_ap_$WIFI_RADIO='wifi-iface'
        uci set wireless.wifi_ap_$WIFI_RADIO.device="$WIFI_RADIO"
        uci set wireless.wifi_ap_$WIFI_RADIO.mode='ap'
        uci set wireless.wifi_ap_$WIFI_RADIO.ssid="$WIFI_ID"
        uci set wireless.wifi_ap_$WIFI_RADIO.network='lan'
        uci set wireless.wifi_ap_$WIFI_RADIO.ieee80211r='1'
        uci set wireless.wifi_ap_$WIFI_RADIO.mobility_domain=$MOBILITY_DOMAIN
        uci set wireless.wifi_ap_$WIFI_RADIO.ft_over_ds='0'
        uci set wireless.wifi_ap_$WIFI_RADIO.ft_psk_generate_local='0'
        uci set wireless.wifi_ap_$WIFI_RADIO.disabled=0  # ?? Force-enable AP

        # Apply encryption settings for regular WiFi
        if [ "$ENCRYPTION_ENABLED" = 1 ] && [ ! -z "$NETWORK_KEY" ]; then
            uci set wireless.wifi_ap_$WIFI_RADIO.encryption='sae-mixed'
            uci set wireless.wifi_ap_$WIFI_RADIO.key=$NETWORK_KEY
        else
            uci set wireless.wifi_ap_$WIFI_RADIO.encryption='none'
            [ -z "$NETWORK_KEY" ] && echo "Encryption key is empty, so encryption was disabled."
        fi

        # ?? Apply WiFi settings immediately
        uci commit wireless
        wifi reload
        sleep 2
    fi

    ###### Mesh AP Configuration (Set after regular AP is applied) ######
    if [ ! -z "$AP_RADIO" ]; then
        echo "Configuring Mesh AP on $AP_RADIO"

        uci set wireless.mesh_$AP_RADIO='wifi-iface'
        uci set wireless.mesh_$AP_RADIO.device="$AP_RADIO"
        uci set wireless.mesh_$AP_RADIO.ifname="mesh_$AP_RADIO"
        uci set wireless.mesh_$AP_RADIO.network='mesh_batman'
        uci set wireless.mesh_$AP_RADIO.mode='mesh'
        uci set wireless.mesh_$AP_RADIO.mesh_id="$MESH_SSID"
        uci set wireless.mesh_$AP_RADIO.mesh_fwding='0'
        uci set wireless.mesh_$AP_RADIO.mesh_rssi_threshold='0'
        uci set wireless.mesh_$AP_RADIO.mesh_ttl='1'
        uci set wireless.mesh_$AP_RADIO.mcast_rate='24000'
        uci set wireless.mesh_$AP_RADIO.disabled='0'  # ?? Force-enable mesh AP

        # Apply encryption settings for mesh
        if [ "$ENCRYPTION_ENABLED" = 1 ] && [ ! -z "$NETWORK_KEY" ]; then
            uci set wireless.mesh_$AP_RADIO.encryption='sae'
            uci set wireless.mesh_$AP_RADIO.key=$NETWORK_KEY
        else
            uci set wireless.mesh_$AP_RADIO.encryption='none'
        fi

        # ?? Apply WiFi settings after Mesh AP is set
        uci commit wireless
        wifi reload
        sleep 2
    fi

    ###### Final Restart of Network & Wireless ######
    echo "Restarting WiFi and Network Services..."
    /etc/init.d/network restart
    /etc/init.d/wireless restart
}

restart_and_reload() {
    # Get the radio to be used for mesh from the config
    AP_RADIO=$(uci -q get easymesh.config.apRadio)

    # Check if AP_RADIO is empty, if so exit
    if [ -z "$AP_RADIO" ]; then
        echo "No radio specified in the config, exiting."
        exit 1
    fi

    # Enable radios
    for radio in $AP_RADIO; do
        echo "Enabling $radio..."
        uci set wireless.$radio.disabled=0
    done

    uci commit wireless

    # Reload wifi to apply changes without restarting all interfaces
    wifi up
    echo "Wireless interfaces reloaded."

    # Apply network configuration changes
    reload_config
    echo "Network configuration reloaded."

    /etc/init.d/network reload
}

disable_batman_interfaces() {
    # Delete the bat0 interface
    if [ "$(uci -q get network.bat0)" = "interface" ]; then
        uci del network.bat0
    fi

    # Delete the mesh_batman network interface
    if [ "$(uci -q get network.mesh_batman)" = "interface" ]; then
        uci del network.mesh_batman
    fi

    uci commit network

    reload_config
    /etc/init.d/network reload
    echo "Network configuration reloaded."
}

# Enable easymesh
enable_easymesh() {
    # Clear old radios then set "old values"
    clear_by_mesh_id "$(uci -q get easymesh.config.mesh_id)"
    clear_by_mesh_id "$(uci -q get easymesh.config.old_mesh_id)"
    uci set easymesh.config.old_mesh_id="$(uci -q get easymesh.config.mesh_id)"
    create_batman_network
    process_radios
    restart_and_reload
    # Set at end to be sure it worked
    uci set easymesh.config.running=1
}

# Disable easymesh
disable_easymesh() {
    # Clear old radios then set "old values"
    clear_by_mesh_id "$(uci -q get easymesh.config.mesh_id)"
    clear_by_mesh_id "$(uci -q get easymesh.config.old_mesh_id)"
    uci del easymesh.config.old_mesh_id
    disable_batman_interfaces
    # Set at end to be sure it worked
    uci del easymesh.config.running
}

if [ "$1" = "dumbap" ]; then
    set_apmode
    exit 0
elif [ "$1" = "undumb" ]; then
    disable_apmode
    exit 0
# If no params passed, we disable or enable easymesh based on config
else
    # Check if easymesh is enabled
    if [ "$(uci -q get easymesh.config.enabled)" = 1 ]; then
        enable_easymesh
    else
        disable_easymesh
    fi
fi