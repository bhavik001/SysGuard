#!/bin/bash
# SysGuard: Automated System Health Monitor
# This script monitors CPU, memory, and disk usage and prints an alert
# if any metric exceeds its defined threshold.

# ----- Configuration -----
CPU_THRESHOLD=80      # Alert if combined CPU usage (user+sys) ≥ 80%
MEM_THRESHOLD=80      # Alert if memory usage ≥ 80%
DISK_THRESHOLD=80     # Alert if disk usage on / ≥ 80%

LOGFILE="/tmp/sysguard.log"  # Log file location

# ----- Functions -----

# get_cpu_usage: Retrieves CPU usage (user + sys percentage) using top.
get_cpu_usage() {
    cpu_line=$(top -l 1 | grep "CPU usage")
    user=$(echo "$cpu_line" | awk '{print $3}' | sed 's/%//')
    sys=$(echo "$cpu_line" | awk '{print $5}' | sed 's/%//')
    cpu_sum=$(echo "$user + $sys" | bc -l)
    printf "%.0f" "$cpu_sum"
}

# get_disk_usage: Retrieves disk usage percentage for the root partition.
get_disk_usage() {
    df -h / | awk 'NR==2 {gsub(/%/,"",$5); print $5}'
}

# get_mem_usage: Calculates memory usage percentage using vm_stat.
get_mem_usage() {
    # Get page size in bytes
    page_size=$(vm_stat | grep "page size of" | awk '{print $8}')
    
    # Get various page counts
    pages_free=$(vm_stat | grep "Pages free" | awk '{print $3}' | sed 's/\.//')
    pages_active=$(vm_stat | grep "Pages active" | awk '{print $3}' | sed 's/\.//')
    pages_inactive=$(vm_stat | grep "Pages inactive" | awk '{print $3}' | sed 's/\.//')
    pages_speculative=$(vm_stat | grep "Pages speculative" | awk '{print $3}' | sed 's/\.//')
    pages_wired=$(vm_stat | grep "Pages wired down" | awk '{print $4}' | sed 's/\.//')
    pages_purgeable=$(vm_stat | grep "Pages purgeable" | awk '{print $3}' | sed 's/\.//')
    
    # Calculate total used and total free memory
    total_used=$((pages_active + pages_inactive + pages_wired + pages_speculative - pages_purgeable))
    total_free=$((pages_free + pages_purgeable))
    total_memory=$((total_used + total_free))
    
    # Calculate used memory percentage
    mem_usage=$(echo "scale=2; ($total_used * $page_size) / ($total_memory * $page_size) * 100" | bc)
    printf "%.0f" "$mem_usage"
}

# ----- Main Monitoring Loop -----
while true; do
    cpu=$(get_cpu_usage)
    disk=$(get_disk_usage)
    mem=$(get_mem_usage)
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    
    # Log and display current stats
    echo "$timestamp - CPU: ${cpu}%, Mem: ${mem}%, Disk: ${disk}%" | tee -a "$LOGFILE"
    
    # Check thresholds and display alerts
    if [ "$cpu" -ge "$CPU_THRESHOLD" ]; then
        echo "ALERT: CPU usage is at ${cpu}% (Threshold: ${CPU_THRESHOLD}%)"
    fi
    if [ "$mem" -ge "$MEM_THRESHOLD" ]; then
        echo "ALERT: Memory usage is at ${mem}% (Threshold: ${MEM_THRESHOLD}%)"
    fi
    if [ "$disk" -ge "$DISK_THRESHOLD" ]; then
        echo "ALERT: Disk usage is at ${disk}% (Threshold: ${DISK_THRESHOLD}%)"
    fi

    sleep 10
done
