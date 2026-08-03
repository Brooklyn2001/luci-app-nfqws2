#!/bin/sh

# Generates /etc/nfqws2/nfqws2.conf from UCI config nfqws2.general + nfqws2.strategies

CFGFILE=/etc/config/nfqws2
CONFDEST=/etc/nfqws2/nfqws2.conf

uci_get() {
	uci get "nfqws2.$1.$2" 2>/dev/null
}

uci_get_default() {
	local val
	val=$(uci get "nfqws2.$1.$2" 2>/dev/null)
	[ -n "$val" ] && echo "$val" || echo "$3"
}

mkdir -p /etc/nfqws2
mkdir -p /etc/nfqws2/lists
mkdir -p /etc/nfqws2/lua
mkdir -p /var/log

ISP_INTERFACE=$(uci_get_default general isp_interface eth3)
NFQWS_BASE_ARGS=$(uci_get strategies nfqws_base_args)
NFQWS_ARGS=$(uci_get strategies nfqws_args)
NFQWS_ARGS_QUIC=$(uci_get strategies nfqws_args_quic)
NFQWS_ARGS_UDP=$(uci_get strategies nfqws_args_udp)
NFQWS_ARGS_CUSTOM=$(uci_get strategies nfqws_args_custom)
NFQWS_ARGS_IPSET=$(uci_get_default strategies nfqws_args_ipset '--ipset=/etc/nfqws2/lists/ipset.list --ipset-exclude=/etc/nfqws2/lists/ipset_exclude.list')
NFQWS_MODE=$(uci_get_default general nfqws_mode MODE_AUTO)
IPV6_ENABLED=$(uci_get_default general ipv6_enabled 1)
TCP_PORTS=$(uci_get_default general tcp_ports '80,443,1984,2053,2083,2087,2096,5222,8443')
UDP_PORTS=$(uci_get_default general udp_ports '443,590:600,1400,3478:3481,5349,19294:19344,49152:65535')
POLICY_NAME=$(uci_get_default general policy_name nfqws)
POLICY_EXCLUDE=$(uci_get_default general policy_exclude 0)
LOG_LEVEL=$(uci_get_default general log_level 0)
NFQUEUE_NUM=$(uci_get_default general nfqueue_num 300)
USER_VAL=$(uci_get_default general user nobody)

MODE_LIST="--hostlist=/etc/nfqws2/lists/user.list"
MODE_ALL="--hostlist-exclude=/etc/nfqws2/lists/exclude.list"
MODE_AUTO="$MODE_LIST --hostlist-auto=/etc/nfqws2/lists/auto.list --hostlist-auto-debug=/var/log/nfqws2.log $MODE_ALL"

case "$NFQWS_MODE" in
	MODE_LIST)  NFQWS_EXTRA_ARGS="$MODE_LIST" ;;
	MODE_ALL)   NFQWS_EXTRA_ARGS="$MODE_ALL" ;;
	MODE_AUTO)  NFQWS_EXTRA_ARGS="$MODE_AUTO" ;;
esac

cat > "$CONFDEST" <<CONF
ISP_INTERFACE="$ISP_INTERFACE"
NFQWS_BASE_ARGS="$NFQWS_BASE_ARGS"
NFQWS_ARGS="$NFQWS_ARGS"
NFQWS_ARGS_QUIC="$NFQWS_ARGS_QUIC"
NFQWS_ARGS_UDP="$NFQWS_ARGS_UDP"
NFQWS_EXTRA_ARGS="$NFQWS_EXTRA_ARGS"
NFQWS_ARGS_IPSET="$NFQWS_ARGS_IPSET"
NFQWS_ARGS_CUSTOM="$NFQWS_ARGS_CUSTOM"
IPV6_ENABLED=$IPV6_ENABLED
TCP_PORTS=$TCP_PORTS
UDP_PORTS=$UDP_PORTS
POLICY_NAME="$POLICY_NAME"
POLICY_EXCLUDE=$POLICY_EXCLUDE
LOG_LEVEL=$LOG_LEVEL
LOG_DEBUG_PATH="@/var/log/nfqws2-debug.log"
NFQUEUE_NUM=$NFQUEUE_NUM
USER=$USER_VAL
CONF
