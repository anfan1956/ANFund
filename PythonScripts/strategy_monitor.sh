#!/bin/bash

# strategy_resources_fixed.sh
# Monitor resources for trading strategies

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CHECK_INTERVAL=10
PYTHON_PROCESS="python.exe"

print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  Trading System Resources Monitor     ${NC}"
    echo -e "${BLUE}  $(date '+%Y-%m-%d %H:%M:%S')         ${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

get_system_metrics() {
    echo -e "${YELLOW}=== SYSTEM METRICS ===${NC}"
    
    # CPU Usage - simplified
    CPU_USAGE=$(wmic cpu get loadpercentage 2>/dev/null | grep -E "^[0-9]+" | head -1)
    echo -e "CPU Total: ${CPU_USAGE}%"
    
    # Memory - simplified
    MEM_INFO=$(wmic OS get TotalVisibleMemorySize,FreePhysicalMemory /format:list 2>/dev/null)
    MEM_TOTAL=$(echo "$MEM_INFO" | grep "TotalVisibleMemorySize" | cut -d'=' -f2)
    MEM_FREE=$(echo "$MEM_INFO" | grep "FreePhysicalMemory" | cut -d'=' -f2)
    
    if [ ! -z "$MEM_TOTAL" ] && [ ! -z "$MEM_FREE" ]; then
        MEM_TOTAL_MB=$((MEM_TOTAL / 1024))
        MEM_FREE_MB=$((MEM_FREE / 1024))
        MEM_USED_MB=$((MEM_TOTAL_MB - MEM_FREE_MB))
        MEM_PERCENT=$((MEM_USED_MB * 100 / MEM_TOTAL_MB))
        
        echo -e "Memory: ${MEM_PERCENT}% (${MEM_USED_MB}MB / ${MEM_TOTAL_MB}MB)"
    else
        echo -e "Memory info unavailable"
    fi
}

get_python_metrics() {
    echo -e "\n${YELLOW}=== PYTHON STRATEGIES ===${NC}"
    
    # Get all python processes
    PYTHON_PROCS=$(wmic process where "name='$PYTHON_PROCESS'" get ProcessId,CommandLine 2>/dev/null)
    
    # Count strategies
    STRATEGY_COUNT=$(echo "$PYTHON_PROCS" | grep -c "mtf_rsi_ema_strategy")
    echo -e "Running strategies: ${STRATEGY_COUNT}"
    
    if [ $STRATEGY_COUNT -eq 0 ]; then
        echo -e "${RED}No strategies running${NC}"
        return
    fi
    
    # List strategies with config IDs
    echo "$PYTHON_PROCS" | grep "mtf_rsi_ema_strategy" | while read -r line; do
        if [ ! -z "$line" ]; then
            PID=$(echo "$line" | awk '{print $1}')
            CMD=$(echo "$line" | awk '{$1=""; print $0}' | xargs)
            
            # Extract config-id
            CONFIG_ID=$(echo "$CMD" | grep -o "config-id [0-9]*" | awk '{print $2}')
            if [ -z "$CONFIG_ID" ]; then
                CONFIG_ID="unknown"
            fi
            
            # Get memory for this PID
            MEM_KB=$(wmic process where "ProcessId=$PID" get WorkingSetSize 2>/dev/null | grep -E "^[0-9]+" | head -1)
            if [ ! -z "$MEM_KB" ]; then
                MEM_MB=$((MEM_KB / 1024 / 1024))
                echo -e "  Config ${CONFIG_ID}: PID ${PID}, Memory ${MEM_MB}MB"
            else
                echo -e "  Config ${CONFIG_ID}: PID ${PID}"
            fi
        fi
    done
}

get_quick_metrics() {
    echo -e "\n${YELLOW}=== QUICK METRICS ===${NC}"
    
    # Total Python processes
    TOTAL_PYTHON=$(tasklist | grep -c "python.exe")
    echo -e "Total Python processes: ${TOTAL_PYTHON}"
    
    # SQL connections
    SQL_CONNS=$(netstat -an | findstr ":1433" | findstr "ESTABLISHED" | wc -l)
    echo -e "SQL Server connections: ${SQL_CONNS}"
    
    # Excel
    EXCEL_COUNT=$(tasklist | grep -c "EXCEL.EXE")
    echo -e "Excel processes: ${EXCEL_COUNT}"
}

main() {
    while true; do
        clear
        print_header
        
        get_system_metrics
        get_python_metrics
        get_quick_metrics
        
        echo -e "\n${BLUE}========================================${NC}"
        echo -e "Updated: $(date '+%H:%M:%S')"
        echo -e "Press Ctrl+C to exit"
        echo -e "${BLUE}========================================${NC}"
        
        # Wait for interval
        for i in $(seq 1 $CHECK_INTERVAL); do
            sleep 1
            echo -ne "\rNext update in $((CHECK_INTERVAL - i)) seconds..."
        done
        echo
    done
}

# Run main function
main