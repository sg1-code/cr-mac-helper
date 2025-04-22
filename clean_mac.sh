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
MAGENTA='\033[0;35m'
ORANGE='\033[0;33m'
NC='\033[0m' # No Color

# Force color output even in non-interactive terminals
export CLICOLOR_FORCE=1
# Make sure to use true colors (24-bit colors)
export COLORTERM=truecolor

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
source "$MODULES_DIR/swift_package_management.sh"
source "$MODULES_DIR/docker_management.sh"
source "$MODULES_DIR/cloud_storage_management.sh"

# --- Main Menu ---
show_main_menu() {
  clear
  echo -e "${GREEN}=== CR - Mac Helper ===${NC}"
  echo -e "${BLUE}Version 1.1 - 2025 Edition${NC}"
  echo
  echo -e "${YELLOW}=== System Management ===${NC}"
  echo "1. App Cleanup and Management"
  echo "2. Path Management"
  echo "3. Cache and Temp File Management"
  echo "4. Login Items Management"
  echo "5. System Maintenance"
  echo "6. System Optimization"
  
  echo -e "\n${YELLOW}=== Network & Power ===${NC}"
  echo "7. Network Optimization"
  echo "8. Battery Optimization (MacBooks)"
  
  echo -e "\n${YELLOW}=== Security & Privacy ===${NC}"
  echo "9. Security Cleanup"
  echo "10. Privacy Permissions Management"
  
  echo -e "\n${YELLOW}=== Storage & Cleanup ===${NC}"
  echo "11. Hidden Folders Cleanup"
  echo "12. System Audit and Reports"
  echo "13. Cloud Storage Management"
  
  echo -e "\n${YELLOW}=== Developer Tools ===${NC}"
  echo "14. Swift & Xcode Management"
  echo "15. Docker Management"
  
  echo -e "\n${YELLOW}=== Settings ===${NC}"
  echo "16. Set Dry Run Mode (Currently: $DRY_RUN)"
  echo "17. Toggle Verbose Mode (Currently: $VERBOSE)"
  echo "18. Exit"
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
    10) check_privacy_permissions ;;
    11) hidden_cleanup ;;
    12) system_audit ;;
    13) cloud_storage_management ;;
    14) swift_package_management ;;
    15) docker_management ;;
    16)
      DRY_RUN=$((1 - DRY_RUN))
      log "Dry Run set to $DRY_RUN ($([ $DRY_RUN -eq 1 ] && echo 'Simulation' || echo 'Execution'))"
      ;;
    17)
      VERBOSE=$((1 - VERBOSE))
      log "Verbose Mode set to $VERBOSE ($([ $VERBOSE -eq 1 ] && echo 'Detailed' || echo 'Minimal'))"
      ;;
    18) 
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
echo -e "${BLUE}Version 1.1 - 2025 Edition${NC}"
echo
echo "This comprehensive utility helps manage and optimize your macOS system."
echo "It includes tools for application management, cache cleanup, security,"
echo "cloud storage optimization, developer tools, and much more."
echo
echo -e "${YELLOW}IMPORTANT:${NC} This tool makes changes to your system."
echo "Always ensure you have current backups before proceeding."
echo
echo -e "${CYAN}NEW FEATURES IN VERSION 1.1:${NC}"
echo "• Enhanced privacy and security management"
echo "• Cloud storage optimization (iCloud, Dropbox, Google Drive, OneDrive)"
echo "• Developer tools management (Swift, Xcode, Docker)"
echo "• Improved system auditing and reporting"
echo "• Updated for compatibility with macOS through 2025"
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