# Basic info
:local routerName "home-router"
:local vps "http://<your vps ip>:9091"

# ===== System Resource =====
:local systemMetrics ""

:local cpus [/system/resource/cpu/print as-value]
:foreach cpu in=$cpus do={
  :local cpuid ($cpu->"cpu")
  :local load ($cpu->"load")
  :set systemMetrics ($systemMetrics . "routeros_per_cpu_load{cpu=\"$cpuid\"} $load\n")
}

:local sysRes [/system/resource/get]
:local uptime [:tonum ($sysRes->"uptime")]
:local cpuLoad ($sysRes->"cpu-load")
:local freeMem ($sysRes->"free-memory")
:local totalMem ($sysRes->"total-memory")
:local freeDisk ($sysRes->"free-hdd-space")
:local totalDisk ($sysRes->"total-hdd-space")

:set systemMetrics ($systemMetrics . "routeros_system_uptime_seconds $uptime\n")
:set systemMetrics ($systemMetrics . "routeros_cpu_load $cpuLoad\n")
:set systemMetrics ($systemMetrics . "routeros_memory_free_bytes $freeMem\n")
:set systemMetrics ($systemMetrics . "routeros_memory_total_bytes $totalMem\n")
:set systemMetrics ($systemMetrics . "routeros_disk_free_bytes $freeDisk\n")
:set systemMetrics ($systemMetrics . "routeros_disk_total_bytes $totalDisk\n")

# ===== Ping Latency =====
# Format Latency Number
:local pingLatency do={
  :local target $1
  :local result [/ping $target count=1 as-value] 
  :if ([:len  ($result->"time")] = 0 ) do={
    :return "NaN"
  }
  :local resultNum [:tonum  ( $result->"time" *1000000)]
  :return ($resultNum/1000 . "." . $resultNum%1000)
}

:local pingMetrics ""

# For Tag DNS
:local pingDNSTargets {"8.8.8.8";"1.1.1.1"}
:foreach t in=$pingDNSTargets do={
  :local latency [$pingLatency $t]
  :set pingMetrics ($pingMetrics . "routeros_ping_latency{target=\"$t\",tag=\"DNS\"} $latency\n")
}

# For Tag WEB
:local pingWEBTargets {"google.com"}
:foreach t in=$pingWEBTargets do={
  :local ip [:resolve $t]
  :local latency [$pingLatency $ip]
  :set pingMetrics ($pingMetrics . "routeros_ping_latency{target=\"$t\",tag=\"WEB\"} $latency\n")
}

# ===== Firewall Connections =====
:local connCount [/ip/firewall/connection/print count-only]

# ===== Interface =====
:local ifaces [/interface/print stats as-value]
:local ifaceMetrics ""
:foreach iface in=$ifaces do={
  :local name ($iface->"name")

  :local ifaceMeta [/interface/get $name]
  :local type ($ifaceMeta->"type")
  :local running 0
  :if ( ($ifaceMeta->"running") = true ) do={
    :set running 1
  }

  :local rx ($iface->"rx-byte")
  :local tx ($iface->"tx-byte")
  :local rxPackets ($iface->"rx-packet")
  :local txPackets ($iface->"tx-packet")
  :set ifaceMetrics ($ifaceMetrics . "routeros_interface_rx_bytes{interface=\"$name\",type=\"$type\"} $rx\n")
  :set ifaceMetrics ($ifaceMetrics . "routeros_interface_tx_bytes{interface=\"$name\",type=\"$type\"} $tx\n")
  :set ifaceMetrics ($ifaceMetrics . "routeros_interface_rx_packets{interface=\"$name\",type=\"$type\"} $rxPackets\n")
  :set ifaceMetrics ($ifaceMetrics . "routeros_interface_tx_packets{interface=\"$name\",type=\"$type\"} $txPackets\n")
  :set ifaceMetrics ($ifaceMetrics . "routeros_interface_running{interface=\"$name\",type=\"$type\"} $running\n")
}

:local ifMonitor [/interface/monitor-traffic [find] once as-value]
:foreach m in=$ifMonitor do={
  :local name ($m->"name")

  :local ifaceMeta [/interface/get $name]
  :local type ($ifaceMeta->"type")

  :local rxRate ($m->"rx-bits-per-second")
  :local txRate ($m->"tx-bits-per-second")
  :local rxPacketsRate ($m->"rx-packets-per-second")
  :local txPacketsRate ($m->"tx-packets-per-second")
  :set ifaceMetrics ($ifaceMetrics . "routeros_interface_rx_bps{interface=\"$name\",type=\"$type\"} $rxRate\n")
  :set ifaceMetrics ($ifaceMetrics . "routeros_interface_tx_bps{interface=\"$name\",type=\"$type\"} $txRate\n")
  :set ifaceMetrics ($ifaceMetrics . "routeros_interface_rx_pps{interface=\"$name\",type=\"$type\"} $rxPacketsRate\n")
  :set ifaceMetrics ($ifaceMetrics . "routeros_interface_tx_pps{interface=\"$name\",type=\"$type\"} $txPacketsRate\n")
}

# ===== BGP Peers =====
:local bgpMetrics ""
:local peers [/routing/bgp/connection/print as-value]
:local sessions [/routing/bgp/session/print as-value]

:foreach p in=$peers do={
  :local peerName ($p->"name")
  :local up 0

  :foreach s in=$sessions do={
    :if (($s->"name") = $peerName . "-1") do={
      :set up 1
    }
  }

    :set bgpMetrics ($bgpMetrics . "routeros_bgp_session_up{peer=\"$peerName\"} $up\n")
}

# ===== Combine Metrics =====
:local body ""
:set body ($body . $systemMetrics)
:set body ($body . $pingMetrics)
:set body ($body . "routeros_fw_connections $connCount\n")
:set body ($body . $ifaceMetrics)
:set body ($body . $bgpMetrics)

/tool fetch url=($vps . "/metrics/job/routeros/instance/" . $routerName) \
    http-method=post http-data=$body output=none
