#!/bin/bash

# clean_mac.sh - Enhanced macOS Application Management and Cleanup Suite

# --- Base Configuration ---
LOGFILE="$HOME/Library/Logs/clean_script.log"
BACKUP_DIR="$HOME/Documents/clean_script_backups/$(date +%Y%m%d_%H%M%S)"
DRY_RUN=0  # 0 for actual execution, 1 for simulation
VERBOSE=1  # 0 for minimal output, 1 for detailed logs

# --- Colors for better readability ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# --- Path to modules ---
MODULES_DIR="$(dirname "$0")/modules"

# Source all modules
source "$MODULES_DIR/helpers.sh"
source "$MODULES_DIR/app_cleanup.sh"
source "$MODULES_DIR/path_management.sh"
source "$MODULES_DIR/cache_cleanup.sh"
source "$MODULES_DIR/login_items.sh"
source "$MODULES_DIR/system_maintenance.sh"
source "$MODULES_DIR/system_optimization.sh"
source "$MODULES_DIR/network_optimization.sh"
source "$MODULES_DIR/battery_optimization.sh"
source "$MODULES_DIR/security_cleanup.sh"
source "$MODULES_DIR/hidden_cleanup.sh"
source "$MODULES_DIR/system_audit.sh"

# --- Main Menu ---
show_main_menu() {
  clear
  echo -e "${GREEN}=== CR - Mac Helper ===${NC}"
  echo
  echo "1. App Cleanup and Management"
  echo "2. Path Management"
  echo "3. Cache and Temp File Management"
  echo "4. Login Items Management"
  echo "5. System Maintenance"
  echo "6. System Optimization"
  echo "7. Network Optimization"
  echo "8. Battery Optimization (MacBooks)"
  echo "9. Security Cleanup"
  echo "10. Hidden Folders Cleanup"
  echo "11. System Audit and Reports"
  echo "12. Set Dry Run Mode (Currently: $DRY_RUN)"
  echo "13. Toggle Verbose Mode (Currently: $VERBOSE)"
  echo "14. Exit"
  echo
  echo -n "Enter your choice: "
  read -r choice

  case "$choice" in
    1) app_cleanup ;;
    2) path_management ;;
    3) cache_temp_cleanup ;;
    4) login_items_management ;;
    5) system_maintenance ;;
    6) system_optimization ;;
    7) network_optimization ;;
    8) battery_optimization ;;
    9) security_cleanup ;;
    10) hidden_cleanup ;;
    11) system_audit ;;
    12)
      DRY_RUN=$((1 - DRY_RUN))
      log "Dry Run set to $DRY_RUN ($([ $DRY_RUN -eq 1 ] && echo 'Simulation' || echo 'Execution'))"
      ;;
    13)
      VERBOSE=$((1 - VERBOSE))
      log "Verbose Mode set to $VERBOSE ($([ $VERBOSE -eq 1 ] && echo 'Detailed' || echo 'Minimal'))"
      ;;
    14) 
      log "Exiting CR - Mac Helper."
      exit 0 
      ;;
    *) log --warn "Invalid choice." ;;
  esac

  echo
  read -n 1 -s -r -p "Press any key to continue..."
}

# --- Script Start ---

# Handle interrupts
trap 'echo; log --warn "Script interrupted."; exit 1' INT TERM

# Initialize log
init_log

# Check if script is run with sudo or as root
if [[ $EUID -eq 0 ]]; then
  log --warn "This script is running as root."
  log --warn "Some operations are safer when run as a normal user with sudo privileges."
  if ! confirm "Continue running as root?"; then
    exit 1
  fi
fi

# Welcome message
echo -e "${GREEN}=== CR - Mac Helper ===${NC}"
echo -e "${BLUE}Version 1.0${NC}"
echo
echo "This utility helps manage and clean up your macOS system."
echo "It includes tools for application management, cache cleanup,"
echo "system optimization, and more."
echo
echo -e "${YELLOW}IMPORTANT:${NC} This tool makes changes to your system."
echo "Always ensure you have current backups before proceeding."
echo

if confirm "Continue with CR - Mac Helper?"; then
  # Create backup directory
  mkdir -p "$BACKUP_DIR"
  log "Backup directory created at: $BACKUP_DIR"
  
  # Main program loop
  while true; do
    show_main_menu
  done
else
  log "Script canceled by user."
  exit 0
fi 