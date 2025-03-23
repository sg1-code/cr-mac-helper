#!/bin/bash

# battery_optimization.sh - Battery optimization functions for MacBooks

# Main battery optimization function
battery_optimization() {
  echo -e "\n${BLUE}=== Battery Optimization ===${NC}"
  
  # Check if this is a MacBook or other battery-powered device
  if ! system_profiler SPPowerDataType 2>/dev/null | grep -q "Battery Information"; then
    log --warn "This does not appear to be a battery-powered device. These optimizations may not be applicable."
    if ! confirm "Continue anyway?"; then
      return
    fi
  fi
  
  echo "1. Show battery status and health"
  echo "2. Identify power-hungry applications"
  echo "3. Optimize energy settings"
  echo "4. Battery maintenance tips"
  echo "5. Return to main menu"
  echo -n "Select an option: "
  read -r batt_choice
  
  case "$batt_choice" in
    1) battery_status ;;
    2) power_hungry_apps ;;
    3) optimize_energy_settings ;;
    4) battery_tips ;;
    5) return ;;
    *) log --warn "Invalid choice. Returning to main menu."; return ;;
  esac
}

# Display battery status and health
battery_status() {
  echo -e "\n${BLUE}--- Battery Status and Health ---${NC}"
  
  log "Gathering battery information..."
  
  # Check if we have a battery
  if ! system_profiler SPPowerDataType 2>/dev/null | grep -q "Battery Information"; then
    log --warn "No battery found on this system."
    return
  fi
  
  # Create a temporary file for the report
  local report_file=$(mktemp)
  echo "Battery Status Report - $(date)" > "$report_file"
  echo "---------------------------" >> "$report_file"
  echo "" >> "$report_file"
  
  # Get detailed battery information from system_profiler
  echo "### Battery Information ###" >> "$report_file"
  system_profiler SPPowerDataType >> "$report_file"
  echo "" >> "$report_file"
  
  # Get more detailed battery info using ioreg
  echo "### Battery Health Details ###" >> "$report_file"
  echo "Maximum Capacity: $(ioreg -r -c "AppleSmartBattery" | grep -i "MaxCapacity" | cut -d= -f2 | tr -d ' ')%" >> "$report_file"
  echo "Design Capacity: $(ioreg -r -c "AppleSmartBattery" | grep -i "DesignCapacity" | cut -d= -f2 | tr -d ' ')" >> "$report_file"
  echo "Cycle Count: $(ioreg -r -c "AppleSmartBattery" | grep -i "CycleCount" | cut -d= -f2 | tr -d ' ')" >> "$report_file"
  echo "Battery Temperature: $(ioreg -r -c "AppleSmartBattery" | grep -i "Temperature" | cut -d= -f2 | tr -d ' ' | awk '{printf "%.1f°C\n", $1/100}')" >> "$report_file"
  
  # Calculate battery health percentage
  local max_capacity=$(ioreg -r -c "AppleSmartBattery" | grep -i "MaxCapacity" | cut -d= -f2 | tr -d ' ')
  local design_capacity=$(ioreg -r -c "AppleSmartBattery" | grep -i "DesignCapacity" | cut -d= -f2 | tr -d ' ')
  
  if [[ -n "$max_capacity" && -n "$design_capacity" && "$design_capacity" -gt 0 ]]; then
    local health_percentage=$(echo "scale=2; ($max_capacity / $design_capacity) * 100" | bc)
    echo "Battery Health: ${health_percentage}%" >> "$report_file"
    
    # Provide a health assessment
    if (( $(echo "$health_percentage >= 80" | bc -l) )); then
      echo "Assessment: Good - Your battery is in good health." >> "$report_file"
    elif (( $(echo "$health_percentage >= 60" | bc -l) )); then
      echo "Assessment: Fair - Battery showing some degradation but still serviceable." >> "$report_file"
    else
      echo "Assessment: Poor - Battery shows significant degradation. Consider replacement." >> "$report_file"
    fi
  fi
  echo "" >> "$report_file"
  
  # Get current power consumption
  echo "### Current Power Consumption ###" >> "$report_file"
  local current_draw=$(ioreg -r -c "AppleSmartBattery" | grep -i "InstantAmperage" | cut -d= -f2 | tr -d ' ')
  local voltage=$(ioreg -r -c "AppleSmartBattery" | grep -i "Voltage" | cut -d= -f2 | tr -d ' ')
  
  if [[ -n "$current_draw" && -n "$voltage" ]]; then
    local power_draw=$(echo "scale=2; (($current_draw * $voltage) / 1000000) * -1" | bc)
    echo "Current Power Draw: ${power_draw}W" >> "$report_file"
  fi
  
  # Get time remaining estimate
  local time_remaining=$(pmset -g batt | grep -o '[0-9:]*' | tail -1)
  if [[ "$time_remaining" != "0:00" ]]; then
    echo "Estimated Time Remaining: $time_remaining" >> "$report_file"
  else
    echo "Estimated Time Remaining: Calculating..." >> "$report_file"
  fi
  echo "" >> "$report_file"
  
  # Display the report
  less "$report_file"
  
  # Offer to save the report
  if confirm "Would you like to save this report to your Desktop?"; then
    local report_path="$HOME/Desktop/battery_status_$(date +%Y%m%d_%H%M%S).txt"
    cp "$report_file" "$report_path"
    log "Report saved to: $report_path"
  fi
  
  # Clean up
  rm "$report_file"
  
  echo
  read -n 1 -s -r -p "Press any key to continue..."
}

# Identify power-hungry applications
power_hungry_apps() {
  echo -e "\n${BLUE}--- Power-Hungry Applications ---${NC}"
  
  log "Identifying applications that consume significant battery power..."
  
  # Check if running on battery
  local on_battery=0
  pmset -g ps | grep -q "Battery Power" && on_battery=1
  
  if [[ $on_battery -eq 0 ]]; then
    log --warn "Your Mac is currently on AC power. Results may not accurately reflect battery usage."
    if ! confirm "Continue anyway?"; then
      return
    fi
  fi
  
  # Use the Activity Monitor sorting by Energy tab equivalent
  log "Collecting power usage data. This will take about 10 seconds..."
  
  # Create a temporary file for results
  local results_file=$(mktemp)
  
  # Header for the file
  echo "Power Usage Report - $(date)" > "$results_file"
  echo "-------------------------" >> "$results_file"
  echo "" >> "$results_file"
  
  # Get initial process list
  log "Monitoring energy impact of running processes..."
  
  # Check if we have powermetrics
  if ! command -v powermetrics >/dev/null 2>&1; then
    log --warn "The 'powermetrics' command is required but not available."
    log "Using top command as a fallback (less accurate)..."
    
    echo "### CPU Intensive Processes ###" >> "$results_file"
    top -l 2 -o cpu -n 15 -stats pid,command,cpu,cpu_me | grep -v "PID" | tail -15 >> "$results_file"
  else
    # Need sudo for powermetrics
    if [[ $EUID -ne 0 ]]; then
      log --warn "This operation requires root privileges for detailed power metrics."
      if ! confirm "Attempt to run with sudo?"; then
        # Fallback to top
        echo "### CPU Intensive Processes ###" >> "$results_file"
        top -l 2 -o cpu -n 15 -stats pid,command,cpu,cpu_me | grep -v "PID" | tail -15 >> "$results_file"
      else
        # Collect 5 seconds of power metrics
        log "Collecting detailed power metrics (5 seconds)..."
        sudo powermetrics --show-process-energy --format text -u --interval 5000 -i 1 > "$results_file.power" 2>/dev/null
        
        # Extract process energy info
        echo "### Process Energy Impact ###" >> "$results_file"
        grep -A 30 "ENERGY IMPACT BY PROCESS" "$results_file.power" >> "$results_file"
        
        # Extract power information
        echo "" >> "$results_file"
        echo "### System Power Consumption ###" >> "$results_file"
        grep -A 15 "CPU Power" "$results_file.power" >> "$results_file"
        
        rm "$results_file.power"
      fi
    else
      # Collect 5 seconds of power metrics
      log "Collecting detailed power metrics (5 seconds)..."
      powermetrics --show-process-energy --format text -u --interval 5000 -i 1 > "$results_file.power" 2>/dev/null
      
      # Extract process energy info
      echo "### Process Energy Impact ###" >> "$results_file"
      grep -A 30 "ENERGY IMPACT BY PROCESS" "$results_file.power" >> "$results_file"
      
      # Extract power information
      echo "" >> "$results_file"
      echo "### System Power Consumption ###" >> "$results_file"
      grep -A 15 "CPU Power" "$results_file.power" >> "$results_file"
      
      rm "$results_file.power"
    fi
  fi
  
  # Add recommendations
  echo "" >> "$results_file"
  echo "### Battery Saving Recommendations ###" >> "$results_file"
  echo "1. Consider closing applications with high energy impact when on battery power." >> "$results_file"
  echo "2. Applications using significant CPU or GPU will drain your battery faster." >> "$results_file"
  echo "3. Background processes with high energy impact should be investigated." >> "$results_file"
  echo "4. Web browsers with many open tabs can consume significant power." >> "$results_file"
  echo "" >> "$results_file"
  
  # Display the results
  less "$results_file"
  
  # Offer to save the report
  if confirm "Would you like to save this report to your Desktop?"; then
    local report_path="$HOME/Desktop/power_usage_$(date +%Y%m%d_%H%M%S).txt"
    cp "$results_file" "$report_path"
    log "Report saved to: $report_path"
  fi
  
  # Clean up
  rm "$results_file"
  
  echo
  read -n 1 -s -r -p "Press any key to continue..."
}

# Optimize energy settings
optimize_energy_settings() {
  echo -e "\n${BLUE}--- Optimizing Energy Settings ---${NC}"
  
  log "This will optimize your Mac's energy settings for better battery life."
  
  # Check if we're running on a battery-powered Mac
  if ! system_profiler SPPowerDataType 2>/dev/null | grep -q "Battery Information"; then
    log --warn "This does not appear to be a battery-powered device."
    if ! confirm "Continue anyway?"; then
      return
    fi
  fi
  
  # Show optimization options
  echo "Select an optimization level:"
  echo "1. Balanced (recommended for daily use)"
  echo "2. Maximum Battery Life (aggressively saves power)"
  echo "3. Restore Default Settings"
  echo "4. Custom Settings"
  echo -n "Select an option: "
  read -r energy_choice
  
  # Need sudo for some operations
  local need_sudo=0
  
  case "$energy_choice" in
    1)  # Balanced
      log "Applying balanced energy optimization settings..."
      
      if [[ $DRY_RUN -eq 1 ]]; then
        log "DRY RUN: Would apply balanced energy optimization settings"
      else
        # Battery Power settings
        run_command sudo pmset -b displaysleep 5
        run_command sudo pmset -b sleep 15
        run_command sudo pmset -b disksleep 10
        run_command sudo pmset -b lessbright 1
        run_command sudo pmset -b halfdim 1
        
        # AC Power settings
        run_command sudo pmset -c displaysleep 15
        run_command sudo pmset -c sleep 30
        
        # Shared settings
        run_command sudo pmset -a lidwake 1
        run_command sudo pmset -a autorestart 0
        
        # Disable App Nap for selected apps
        for app in "Spotify" "Mail" "Messages"; do
          if [[ -d "/Applications/$app.app" ]]; then
            run_command defaults write com.apple.dock apps-nap-blacklist -array-add "<string>$(defaults read /Applications/$app.app/Contents/Info CFBundleIdentifier 2>/dev/null)</string>" 2>/dev/null
          fi
        done
        
        # Restart Dock to apply app nap settings
        run_command killall Dock
        
        log "Balanced energy optimization settings applied."
      fi
      ;;
      
    2)  # Maximum Battery Life
      log "Applying maximum battery life optimization settings..."
      
      if [[ $DRY_RUN -eq 1 ]]; then
        log "DRY RUN: Would apply maximum battery life optimization settings"
      else
        # Battery Power settings (aggressive)
        run_command sudo pmset -b displaysleep 2
        run_command sudo pmset -b sleep 5
        run_command sudo pmset -b disksleep 2
        run_command sudo pmset -b lessbright 1
        run_command sudo pmset -b halfdim 1
        run_command sudo pmset -b tcpkeepalive 0
        
        # AC Power settings (more balanced)
        run_command sudo pmset -c displaysleep 10
        run_command sudo pmset -c sleep 30
        
        # Enable auto-graphics switching
        run_command sudo pmset -a gpuswitch 2
        
        # Enable slightly lower processor speed to save power
        run_command sudo pmset -b lowpowermode 1
        
        # Disable Power Nap to save battery
        run_command sudo pmset -b powernap 0
        
        # Reduce brightness
        if [[ -x /usr/bin/brightness ]]; then
          run_command brightness 0.5
        fi
        
        # Disable Bluetooth if possible and user confirms
        if confirm "Would you like to disable Bluetooth to save power?"; then
          run_command sudo defaults write /Library/Preferences/com.apple.Bluetooth ControllerPowerState -int 0
          run_command sudo killall -HUP blued
        fi
        
        log "Maximum battery life optimization settings applied."
        log "Note: Your display will dim and sleep quickly to save power."
      fi
      ;;
      
    3)  # Restore Defaults
      log "Restoring default energy settings..."
      
      if [[ $DRY_RUN -eq 1 ]]; then
        log "DRY RUN: Would restore default energy settings"
      else
        # Restore to default power management settings
        run_command sudo pmset -a restoredefaults
        
        # Clear App Nap blacklist
        run_command defaults delete com.apple.dock apps-nap-blacklist 2>/dev/null
        
        # Restart Dock to apply changes
        run_command killall Dock
        
        log "Default energy settings restored."
      fi
      ;;
      
    4)  # Custom Settings
      log "Custom energy settings configuration..."
      
      echo "Enter display sleep time in minutes for battery power (default: 5):"
      read -r disp_sleep_batt
      
      echo "Enter system sleep time in minutes for battery power (default: 15):"
      read -r sleep_batt
      
      echo "Enable low power mode when on battery? (y/n):"
      read -r low_power
      
      echo "Disable Power Nap on battery? (y/n):"
      read -r power_nap
      
      # Apply custom settings
      if [[ $DRY_RUN -eq 1 ]]; then
        log "DRY RUN: Would apply custom energy settings"
      else
        [[ -n "$disp_sleep_batt" ]] && run_command sudo pmset -b displaysleep "${disp_sleep_batt}"
        [[ -n "$sleep_batt" ]] && run_command sudo pmset -b sleep "${sleep_batt}"
        
        if [[ "$low_power" == "y" ]]; then
          run_command sudo pmset -b lowpowermode 1
        else
          run_command sudo pmset -b lowpowermode 0
        fi
        
        if [[ "$power_nap" == "y" ]]; then
          run_command sudo pmset -b powernap 0
        else
          run_command sudo pmset -b powernap 1
        fi
        
        log "Custom energy settings applied."
      fi
      ;;
      
    *)
      log --warn "Invalid choice."
      ;;
  esac
  
  # Show current settings after changes
  log "Current power management settings:"
  run_command pmset -g
  
  echo
  read -n 1 -s -r -p "Press any key to continue..."
}

# Display battery maintenance tips
battery_tips() {
  echo -e "\n${BLUE}--- Battery Maintenance Tips ---${NC}"
  
  # Create a temporary file for the tips
  local tips_file=$(mktemp)
  
  cat > "$tips_file" << EOF
=== Battery Maintenance and Optimization Tips ===

General Battery Care:
--------------------
1. Keep your MacBook updated to the latest macOS version for battery optimizations.
2. Avoid extreme temperatures (both hot and cold) which can degrade battery capacity.
3. For long-term storage (>6 months), store with battery at ~50% charge, not full or empty.
4. Perform an occasional full charge cycle (0-100%) once a month to help calibrate the battery.

Daily Usage Tips:
----------------
1. Reduce screen brightness - display is a major power consumer.
2. Use automatic brightness adjustment (System Preferences → Displays).
3. Enable dark mode when using your Mac at night (System Preferences → General).
4. Close unused applications, especially those using significant CPU or GPU.
5. Disable keyboard backlighting when not needed.
6. Use Safari instead of Chrome when on battery (Safari is more energy-efficient).
7. Disconnect unused external devices (hard drives, USB devices, etc).
8. Turn off Bluetooth and Wi-Fi when not in use.
9. Use "Battery" symbol in the menu bar to quickly check which apps are using significant energy.

Battery-Draining Features to Manage:
----------------------------------
1. Location Services - disable for apps that don't need it
2. Spotlight Indexing - consider scheduling major file operations when plugged in
3. Background App Refresh - limit to essential apps
4. Reduce notifications to limit screen wake-ups
5. Disable unused connectivity features (AirDrop, Handoff, etc.) when not needed
6. Mail should fetch new messages less frequently or manually

Energy Saver/Battery Preferences:
-------------------------------
1. Enable automatic graphics switching to use integrated GPU when possible
2. Enable "Put hard disks to sleep when possible"
3. Consider using Power Nap only when connected to power
4. Set shorter display sleep time when on battery
5. Use Low Power Mode when needed for maximum battery life

Battery Health:
-------------
1. Modern MacBooks have battery health management enabled by default (System Preferences → Battery → Battery → Battery Health)
2. Consider disabling battery health management only if you frequently use your Mac in high-temperature environments
3. A healthy battery should retain 80% or more of its original capacity after 1000 charge cycles
4. If your battery health drops below 80%, consider having it serviced

For MacBooks with Apple Silicon:
------------------------------
1. Apple Silicon Macs have excellent battery efficiency out of the box
2. Use Optimized Battery Charging to reduce battery aging
3. Rosetta 2 emulation for Intel apps uses more power - prefer native Apple Silicon apps when possible
4. System Settings → Battery → Low Power Mode can dramatically extend battery life
EOF

  # Display the tips
  less "$tips_file"
  
  # Offer to save to desktop
  if confirm "Would you like to save these tips to your Desktop?"; then
    local tips_path="$HOME/Desktop/battery_optimization_tips.txt"
    cp "$tips_file" "$tips_path"
    log "Battery optimization tips saved to: $tips_path"
  fi
  
  # Clean up
  rm "$tips_file"
  
  echo
  read -n 1 -s -r -p "Press any key to continue..."
} 