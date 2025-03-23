#!/bin/bash

# system_maintenance.sh - System maintenance functions

# Main system maintenance function
system_maintenance() {
  echo -e "\n${BLUE}=== System Maintenance ===${NC}"
  check_privileges 1  # Recommend elevated privileges
  
  echo "1. Verify and repair disk permissions"
  echo "2. Run periodic maintenance scripts"
  echo "3. Rebuild Spotlight index"
  echo "4. Rebuild Launch Services database"
  echo "5. Check system status"
  echo "6. Return to main menu"
  echo -n "Select an option: "
  read -r maint_choice
  
  case "$maint_choice" in
    1) repair_permissions ;;
    2) run_periodic_scripts ;;
    3) rebuild_spotlight ;;
    4) rebuild_launchservices ;;
    5) check_system_status ;;
    6) return ;;
    *) log --warn "Invalid choice. Returning to main menu."; return ;;
  esac
}

# Verify and repair disk permissions
repair_permissions() {
  echo -e "\n${BLUE}--- Disk Permission Repair ---${NC}"
  
  # Check if running as root
  if [[ $EUID -ne 0 ]]; then
    log --warn "This operation requires root privileges."
    if ! confirm "Attempt to run with sudo?"; then
      return
    fi
  fi
  
  log "Checking disk permissions..."
  
  # Get the disk identifier for the startup disk
  local system_disk=$(df / | awk 'NR==2 {print $1}')
  log "System disk: $system_disk"
  
  # For newer macOS versions, use 'diskutil resetUserPermissions'
  if [[ -x "/usr/sbin/diskutil" ]]; then
    log "Using diskutil to reset user permissions..."
    
    if [[ $DRY_RUN -eq 1 ]]; then
      log "DRY RUN: Would execute: sudo diskutil resetUserPermissions / $(id -u)"
    else
      log "Resetting user permissions. This may take a while..."
      run_command sudo diskutil resetUserPermissions / $(id -u)
      
      if [[ $? -eq 0 ]]; then
        log "User permissions reset successfully."
      else
        log --error "Error resetting user permissions."
      fi
    fi
    
    # Check and repair the disk structure
    log "Verifying disk structure..."
    if [[ $DRY_RUN -eq 1 ]]; then
      log "DRY RUN: Would execute: sudo diskutil verifyVolume $system_disk"
    else
      run_command sudo diskutil verifyVolume $system_disk
      
      if [[ $? -ne 0 ]]; then
        log --warn "Disk verification found issues. Attempting repair..."
        if confirm "Repair disk? This may require a restart."; then
          run_command sudo diskutil repairVolume $system_disk
        fi
      else
        log "Disk structure verification completed successfully."
      fi
    fi
  else
    log --error "diskutil command not found. Unable to repair permissions."
  fi
  
  echo
  read -n 1 -s -r -p "Press any key to continue..."
}

# Run periodic maintenance scripts
run_periodic_scripts() {
  echo -e "\n${BLUE}--- Running Periodic Maintenance Scripts ---${NC}"
  
  # Check if running as root
  if [[ $EUID -ne 0 ]]; then
    log --warn "This operation requires root privileges."
    if ! confirm "Attempt to run with sudo?"; then
      return
    fi
  fi
  
  log "This will run the daily, weekly, and monthly maintenance scripts."
  log "These scripts clean temporary files, rotate logs, and perform other system maintenance tasks."
  
  if ! confirm "Continue with running maintenance scripts?"; then
    return
  fi
  
  # Run the periodic scripts
  if [[ $DRY_RUN -eq 1 ]]; then
    log "DRY RUN: Would execute periodic scripts..."
  else
    log "Running daily maintenance scripts..."
    run_command sudo periodic daily
    
    log "Running weekly maintenance scripts..."
    run_command sudo periodic weekly
    
    log "Running monthly maintenance scripts..."
    run_command sudo periodic monthly
    
    log "Maintenance scripts completed."
  fi
  
  echo
  read -n 1 -s -r -p "Press any key to continue..."
}

# Rebuild Spotlight index
rebuild_spotlight() {
  echo -e "\n${BLUE}--- Rebuilding Spotlight Index ---${NC}"
  
  log "This will rebuild the Spotlight search index."
  log "This can help if Spotlight search is not working correctly or is missing items."
  log "Note: Rebuilding can take a significant amount of time and CPU resources."
  
  if ! confirm "Continue with rebuilding Spotlight index?"; then
    return
  fi
  
  # Options for index rebuilding
  echo "1. Rebuild the entire Spotlight index"
  echo "2. Rebuild index for a specific volume"
  echo -n "Select an option: "
  read -r spotlight_choice
  
  case "$spotlight_choice" in
    1)
      log "Rebuilding the entire Spotlight index..."
      if [[ $DRY_RUN -eq 1 ]]; then
        log "DRY RUN: Would execute: sudo mdutil -E /"
      else
        run_command sudo mdutil -E /
        
        if [[ $? -eq 0 ]]; then
          log "Spotlight indexing has been reset. Indexing will begin shortly."
          log "The indexing process runs in the background and may take several hours to complete."
        else
          log --error "Error resetting Spotlight index."
        fi
      fi
      ;;
    2)
      # List available volumes
      log "Available volumes:"
      df -h | grep "/Volumes" | awk '{print NR". "$9}'
      
      echo -n "Enter the number of the volume to rebuild, or 0 to cancel: "
      read -r volume_num
      
      if [[ "$volume_num" == "0" ]]; then
        return
      fi
      
      local volume=$(df -h | grep "/Volumes" | awk 'NR=='"$volume_num"' {print $9}')
      
      if [[ -z "$volume" ]]; then
        log --warn "Invalid selection."
        return
      fi
      
      log "Rebuilding Spotlight index for $volume..."
      if [[ $DRY_RUN -eq 1 ]]; then
        log "DRY RUN: Would execute: sudo mdutil -E \"$volume\""
      else
        run_command sudo mdutil -E "$volume"
        
        if [[ $? -eq 0 ]]; then
          log "Spotlight indexing has been reset for $volume."
          log "The indexing process runs in the background and may take several hours to complete."
        else
          log --error "Error resetting Spotlight index for $volume."
        fi
      fi
      ;;
    *)
      log --warn "Invalid choice."
      ;;
  esac
  
  echo
  read -n 1 -s -r -p "Press any key to continue..."
}

# Rebuild Launch Services database
rebuild_launchservices() {
  echo -e "\n${BLUE}--- Rebuilding Launch Services Database ---${NC}"
  
  log "This will rebuild the Launch Services database which manages application associations."
  log "This can fix issues with file associations, duplicate 'Open With' menu items, and app icons."
  
  if ! confirm "Continue with rebuilding the Launch Services database?"; then
    return
  fi
  
  if [[ $DRY_RUN -eq 1 ]]; then
    log "DRY RUN: Would execute launch services database rebuild..."
  else
    log "Rebuilding the Launch Services database..."
    
    # Kill cfprefsd which handles preferences
    run_command killall -u $USER cfprefsd 2>/dev/null
    
    # Rebuild the Launch Services database
    run_command /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user
    
    if [[ $? -eq 0 ]]; then
      log "Launch Services database has been rebuilt."
      log "You may need to restart some applications for changes to take effect."
    else
      log --error "Error rebuilding Launch Services database."
    fi
  fi
  
  echo
  read -n 1 -s -r -p "Press any key to continue..."
}

# Check system status
check_system_status() {
  echo -e "\n${BLUE}--- System Status Check ---${NC}"
  
  log "Performing comprehensive system status check..."
  
  # Create a temporary file for the report
  local report_file=$(mktemp)
  echo "System Status Report - $(date)" > "$report_file"
  echo "----------------------------------" >> "$report_file"
  echo "" >> "$report_file"
  
  # System version information
  echo "### System Information ###" >> "$report_file"
  echo "macOS Version:" >> "$report_file"
  sw_vers >> "$report_file"
  echo "" >> "$report_file"
  
  # Hardware information
  echo "### Hardware Overview ###" >> "$report_file"
  system_profiler SPHardwareDataType | grep -v "UUID" >> "$report_file"
  echo "" >> "$report_file"
  
  # Disk usage
  echo "### Disk Usage ###" >> "$report_file"
  df -h >> "$report_file"
  echo "" >> "$report_file"
  
  # Memory usage
  echo "### Memory Usage ###" >> "$report_file"
  vm_stat | perl -ne '/page size of (\d+)/ and $size=$1; /Pages\s+([^:]+)[^\d]+(\d+)/ and printf("%-16s % 16.2f MB\n", "$1:", $2 * $size / 1048576);' >> "$report_file"
  echo "" >> "$report_file"
  
  # Top processes by CPU
  echo "### Top Processes by CPU ###" >> "$report_file"
  top -l 1 -o cpu -n 10 -stats pid,command,cpu,mem >> "$report_file"
  echo "" >> "$report_file"
  
  # Network information
  echo "### Network Interfaces ###" >> "$report_file"
  ifconfig | grep -e "^[a-z]" -e "inet " >> "$report_file"
  echo "" >> "$report_file"
  
  # System load
  echo "### System Load ###" >> "$report_file"
  uptime >> "$report_file"
  echo "" >> "$report_file"
  
  # Boot time
  echo "### System Uptime ###" >> "$report_file"
  who -b >> "$report_file"
  echo "" >> "$report_file"
  
  # Check for updates
  echo "### Software Updates ###" >> "$report_file"
  softwareupdate -l >> "$report_file" 2>&1
  echo "" >> "$report_file"
  
  # SMART status for physical disks
  echo "### Disk SMART Status ###" >> "$report_file"
  system_profiler SPStorageDataType | grep -A4 "Physical Drives:" >> "$report_file"
  echo "" >> "$report_file"
  
  # Display the report
  less "$report_file"
  
  # Offer to save the report
  if confirm "Would you like to save this report to your Desktop?"; then
    local report_path="$HOME/Desktop/system_status_report_$(date +%Y%m%d_%H%M%S).txt"
    cp "$report_file" "$report_path"
    log "Report saved to: $report_path"
  fi
  
  # Clean up the temporary file
  rm "$report_file"
  
  echo
  read -n 1 -s -r -p "Press any key to continue..."
} 