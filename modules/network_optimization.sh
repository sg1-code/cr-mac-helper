#!/bin/bash

# network_optimization.sh - Network optimization functions

# Main network optimization function
network_optimization() {
  echo -e "\n${BLUE}=== Network Optimization ===${NC}"
  check_privileges 1  # Recommend elevated privileges
  
  echo "1. Reset network settings"
  echo "2. Optimize DNS settings"
  echo "3. Display network statistics"
  echo "4. Scan network for devices"
  echo "5. Return to main menu"
  echo -n "Select an option: "
  read -r net_choice
  
  case "$net_choice" in
    1) reset_network ;;
    2) optimize_dns ;;
    3) network_stats ;;
    4) scan_network ;;
    5) return ;;
    *) log --warn "Invalid choice. Returning to main menu."; return ;;
  esac
}

# Reset network settings
reset_network() {
  echo -e "\n${BLUE}--- Resetting Network Settings ---${NC}"
  
  # Need sudo for these operations
  if [[ $EUID -ne 0 ]]; then
    log --warn "This operation requires root privileges."
    if ! confirm "Attempt to run with sudo?"; then
      return
    fi
  fi
  
  log "This will reset various network settings to help fix connectivity issues."
  log "WARNING: This will temporarily disconnect you from the network."
  
  if ! confirm "Continue with network reset? This will disrupt your current network connection."; then
    return
  fi
  
  # Show menu of reset options
  echo "1. Full network reset (all settings)"
  echo "2. Reset DNS cache only"
  echo "3. Reset Wi-Fi configurations only"
  echo "4. Reset TCP/IP stack only"
  echo -n "Select an option: "
  read -r reset_choice
  
  case "$reset_choice" in
    1)  # Full network reset
      log "Performing full network reset..."
      
      if [[ $DRY_RUN -eq 1 ]]; then
        log "DRY RUN: Would perform full network reset"
      else
        # Create backup of network settings
        log "Creating backup of network configurations..."
        local backup_dir="$BACKUP_DIR/network_settings"
        run_command mkdir -p "$backup_dir"
        
        # Backup DNS cache
        run_command cp -f /var/run/resolv.conf "$backup_dir/" 2>/dev/null
        
        # Backup network preferences
        run_command cp -f /Library/Preferences/SystemConfiguration/NetworkInterfaces.plist "$backup_dir/" 2>/dev/null
        run_command cp -f /Library/Preferences/SystemConfiguration/preferences.plist "$backup_dir/" 2>/dev/null
        
        # Flush DNS cache
        log "Flushing DNS cache..."
        run_command sudo dscacheutil -flushcache
        run_command sudo killall -HUP mDNSResponder
        
        # Reset TCP/IP stack
        log "Resetting TCP/IP stack..."
        run_command sudo ifconfig en0 down 2>/dev/null
        run_command sudo ifconfig en0 up 2>/dev/null
        
        # Reset network service order
        log "Resetting network service order..."
        run_command sudo networksetup -restoreallnetworkservices
        
        # Delete Wi-Fi preferences
        log "Deleting Wi-Fi configurations..."
        run_command sudo rm -f /Library/Preferences/SystemConfiguration/com.apple.airport.preferences.plist 2>/dev/null
        
        # Restart network services
        log "Restarting network services..."
        run_command sudo launchctl unload -w /System/Library/LaunchDaemons/com.apple.mDNSResponder.plist 2>/dev/null
        run_command sudo launchctl load -w /System/Library/LaunchDaemons/com.apple.mDNSResponder.plist 2>/dev/null
        
        log "Full network reset completed."
        log "You may need to reconnect to your Wi-Fi network or restart your computer."
      fi
      ;;
      
    2)  # Reset DNS cache only
      log "Resetting DNS cache..."
      
      if [[ $DRY_RUN -eq 1 ]]; then
        log "DRY RUN: Would reset DNS cache"
      else
        # Flush DNS cache
        run_command sudo dscacheutil -flushcache
        run_command sudo killall -HUP mDNSResponder
        
        log "DNS cache has been reset."
      fi
      ;;
      
    3)  # Reset Wi-Fi configurations only
      log "Resetting Wi-Fi configurations..."
      
      if [[ $DRY_RUN -eq 1 ]]; then
        log "DRY RUN: Would reset Wi-Fi configurations"
      else
        # Backup Wi-Fi preferences
        local backup_dir="$BACKUP_DIR/network_settings"
        run_command mkdir -p "$backup_dir"
        run_command cp -f /Library/Preferences/SystemConfiguration/com.apple.airport.preferences.plist "$backup_dir/" 2>/dev/null
        
        # Delete Wi-Fi preferences
        run_command sudo rm -f /Library/Preferences/SystemConfiguration/com.apple.airport.preferences.plist 2>/dev/null
        
        # Turn Wi-Fi off and on
        log "Cycling Wi-Fi interface..."
        run_command sudo networksetup -setairportpower en0 off
        sleep 2
        run_command sudo networksetup -setairportpower en0 on
        
        log "Wi-Fi configurations have been reset."
        log "You will need to reconnect to your Wi-Fi network."
      fi
      ;;
      
    4)  # Reset TCP/IP stack only
      log "Resetting TCP/IP stack..."
      
      if [[ $DRY_RUN -eq 1 ]]; then
        log "DRY RUN: Would reset TCP/IP stack"
      else
        # Get list of active network interfaces
        local interfaces=$(ifconfig -l | tr ' ' '\n' | grep -v lo)
        
        for interface in $interfaces; do
          log "Resetting interface $interface..."
          run_command sudo ifconfig $interface down 2>/dev/null
          sleep 1
          run_command sudo ifconfig $interface up 2>/dev/null
        done
        
        log "TCP/IP stack has been reset."
      fi
      ;;
      
    *)
      log --warn "Invalid choice."
      ;;
  esac
  
  echo
  read -n 1 -s -r -p "Press any key to continue..."
}

# Optimize DNS settings
optimize_dns() {
  echo -e "\n${BLUE}--- Optimizing DNS Settings ---${NC}"
  
  # Need sudo for these operations
  if [[ $EUID -ne 0 ]]; then
    log --warn "This operation requires root privileges."
    if ! confirm "Attempt to run with sudo?"; then
      return
    fi
  fi
  
  log "This will optimize your DNS settings for faster and more reliable internet."
  
  # Show current DNS settings
  log "Current DNS servers:"
  networksetup -getdnsservers Wi-Fi
  
  log "Select a DNS provider to use:"
  echo "1. Cloudflare (1.1.1.1) - Fast and privacy-focused"
  echo "2. Google (8.8.8.8) - Reliable and widely used"
  echo "3. Quad9 (9.9.9.9) - Security-focused DNS"
  echo "4. OpenDNS (208.67.222.222) - Security and parental controls"
  echo "5. Custom DNS servers"
  echo "6. Restore default DNS (from DHCP)"
  echo -n "Select an option: "
  read -r dns_choice
  
  # Get active network service
  local active_service=$(networksetup -listallnetworkservices | grep -v "*" | head -n 1)
  
  # If no active service is found, ask user to select one
  if [[ -z "$active_service" ]]; then
    log "No active network service detected. Please select one:"
    networksetup -listallnetworkservices | grep -v "*" | awk '{print NR". "$0}'
    echo -n "Enter the number of the network service to configure: "
    read -r service_num
    
    active_service=$(networksetup -listallnetworkservices | grep -v "*" | sed -n "${service_num}p")
    
    if [[ -z "$active_service" ]]; then
      log --warn "Invalid selection."
      return
    fi
  fi
  
  log "Configuring DNS for network service: $active_service"
  
  case "$dns_choice" in
    1)  # Cloudflare
      if [[ $DRY_RUN -eq 1 ]]; then
        log "DRY RUN: Would set DNS to Cloudflare (1.1.1.1, 1.0.0.1)"
      else
        run_command sudo networksetup -setdnsservers "$active_service" 1.1.1.1 1.0.0.1
        log "DNS set to Cloudflare (1.1.1.1, 1.0.0.1)"
      fi
      ;;
      
    2)  # Google
      if [[ $DRY_RUN -eq 1 ]]; then
        log "DRY RUN: Would set DNS to Google (8.8.8.8, 8.8.4.4)"
      else
        run_command sudo networksetup -setdnsservers "$active_service" 8.8.8.8 8.8.4.4
        log "DNS set to Google (8.8.8.8, 8.8.4.4)"
      fi
      ;;
      
    3)  # Quad9
      if [[ $DRY_RUN -eq 1 ]]; then
        log "DRY RUN: Would set DNS to Quad9 (9.9.9.9, 149.112.112.112)"
      else
        run_command sudo networksetup -setdnsservers "$active_service" 9.9.9.9 149.112.112.112
        log "DNS set to Quad9 (9.9.9.9, 149.112.112.112)"
      fi
      ;;
      
    4)  # OpenDNS
      if [[ $DRY_RUN -eq 1 ]]; then
        log "DRY RUN: Would set DNS to OpenDNS (208.67.222.222, 208.67.220.220)"
      else
        run_command sudo networksetup -setdnsservers "$active_service" 208.67.222.222 208.67.220.220
        log "DNS set to OpenDNS (208.67.222.222, 208.67.220.220)"
      fi
      ;;
      
    5)  # Custom DNS
      echo "Enter primary DNS server:"
      read -r primary_dns
      echo "Enter secondary DNS server (leave empty if none):"
      read -r secondary_dns
      
      if [[ -z "$secondary_dns" ]]; then
        if [[ $DRY_RUN -eq 1 ]]; then
          log "DRY RUN: Would set DNS to custom server ($primary_dns)"
        else
          run_command sudo networksetup -setdnsservers "$active_service" "$primary_dns"
          log "DNS set to custom server ($primary_dns)"
        fi
      else
        if [[ $DRY_RUN -eq 1 ]]; then
          log "DRY RUN: Would set DNS to custom servers ($primary_dns, $secondary_dns)"
        else
          run_command sudo networksetup -setdnsservers "$active_service" "$primary_dns" "$secondary_dns"
          log "DNS set to custom servers ($primary_dns, $secondary_dns)"
        fi
      fi
      ;;
      
    6)  # Restore default
      if [[ $DRY_RUN -eq 1 ]]; then
        log "DRY RUN: Would restore DNS to DHCP defaults"
      else
        run_command sudo networksetup -setdnsservers "$active_service" "Empty"
        log "DNS settings restored to DHCP defaults"
      fi
      ;;
      
    *)
      log --warn "Invalid choice."
      ;;
  esac
  
  # Flush DNS cache to apply changes
  if [[ $dns_choice =~ ^[1-6]$ && $DRY_RUN -eq 0 ]]; then
    log "Flushing DNS cache to apply changes..."
    run_command sudo dscacheutil -flushcache
    run_command sudo killall -HUP mDNSResponder
  fi
  
  echo
  read -n 1 -s -r -p "Press any key to continue..."
}

# Display network statistics
network_stats() {
  echo -e "\n${BLUE}--- Network Statistics ---${NC}"
  
  log "Gathering network statistics and information..."
  
  # Create a temporary file for the report
  local report_file=$(mktemp)
  echo "Network Statistics Report - $(date)" > "$report_file"
  echo "-----------------------------" >> "$report_file"
  echo "" >> "$report_file"
  
  # Network interfaces
  echo "### Network Interfaces ###" >> "$report_file"
  run_command ifconfig -a >> "$report_file" 2>/dev/null
  echo "" >> "$report_file"
  
  # Active connections
  echo "### Active Network Connections ###" >> "$report_file"
  run_command netstat -n -f inet >> "$report_file" 2>/dev/null
  echo "" >> "$report_file"
  
  # Routing table
  echo "### Routing Table ###" >> "$report_file"
  run_command netstat -nr -f inet >> "$report_file" 2>/dev/null
  echo "" >> "$report_file"
  
  # DNS configuration
  echo "### DNS Configuration ###" >> "$report_file"
  run_command cat /etc/resolv.conf >> "$report_file" 2>/dev/null
  echo "" >> "$report_file"
  
  # Wi-Fi information
  echo "### Wi-Fi Information ###" >> "$report_file"
  run_command /System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I >> "$report_file" 2>/dev/null
  echo "" >> "$report_file"
  
  # Display the report
  if [[ -s "$report_file" ]]; then
    less "$report_file"
    
    # Offer to save the report
    if confirm "Would you like to save this report to your Desktop?"; then
      local report_path="$HOME/Desktop/network_stats_$(date +%Y%m%d_%H%M%S).txt"
      cp "$report_file" "$report_path"
      log "Report saved to: $report_path"
    fi
  else
    log --warn "Failed to collect network statistics."
  fi
  
  # Clean up the temporary file
  rm "$report_file" 2>/dev/null
  
  echo
  read -n 1 -s -r -p "Press any key to continue..."
}

# Scan network for devices
scan_network() {
  echo -e "\n${BLUE}--- Scanning Network for Devices ---${NC}"
  
  # Check if we have ping
  if ! command -v ping >/dev/null 2>&1; then
    log --error "The 'ping' command is required but not found."
    return
  fi
  
  # Check for arp
  if ! command -v arp >/dev/null 2>&1; then
    log --error "The 'arp' command is required but not found."
    return
  fi
  
  log "This will scan your local network for connected devices."
  log "Note: This process may take several minutes depending on your network size."
  
  # Get local IP and subnet
  local local_ip=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null)
  
  if [[ -z "$local_ip" ]]; then
    log --warn "Could not determine your local IP address."
    return
  fi
  
  log "Your IP address: $local_ip"
  
  # Extract the network prefix
  local network_prefix=$(echo "$local_ip" | cut -d. -f1-3)
  
  if [[ -z "$network_prefix" ]]; then
    log --warn "Could not determine network prefix."
    return
  fi
  
  log "Scanning network: $network_prefix.0/24"
  
  if ! confirm "Continue with network scan?"; then
    return
  fi
  
  # Create a temp file for results
  local results_file=$(mktemp)
  
  log "Scanning for active devices. This may take a while..."
  echo "IP Address       MAC Address       Hostname/Vendor" > "$results_file"
  echo "------------------------------------------------" >> "$results_file"
  
  # Set a limit for parallel processes
  local max_procs=20
  local procs=0
  
  for i in {1..254}; do
    local target_ip="$network_prefix.$i"
    
    # Start a background ping process
    (
      # Ping with a short timeout
      if ping -c 1 -W 1 "$target_ip" >/dev/null 2>&1; then
        # Get MAC address from ARP table
        local mac=$(arp -n "$target_ip" | awk '{print $4}' | grep -v "at")
        
        # Get hostname if possible
        local hostname=$(host "$target_ip" 2>/dev/null | awk '{print $5}' | sed 's/\.$//')
        [[ "$hostname" == *"NXDOMAIN"* || -z "$hostname" ]] && hostname="Unknown"
        
        # Format the output
        printf "%-15s %-18s %s\n" "$target_ip" "${mac:-Unknown}" "$hostname" >> "$results_file"
      fi
    ) &
    
    # Limit the number of parallel processes
    procs=$((procs + 1))
    if [[ $procs -ge $max_procs ]]; then
      wait
      procs=0
    fi
  done
  
  # Wait for all remaining processes to finish
  wait
  
  # Sort the results and display them
  sort -n -t . -k 1,1 -k 2,2 -k 3,3 -k 4,4 "$results_file" | grep -v "^IP Address" | sed '1i\IP Address       MAC Address       Hostname/Vendor\n------------------------------------------------' > "${results_file}.sorted"
  mv "${results_file}.sorted" "$results_file"
  
  log "Scan complete."
  
  # Count devices
  local device_count=$(grep -v "^IP\|^--" "$results_file" | wc -l | tr -d ' ')
  log "Found $device_count devices on your network."
  
  # Display results
  less "$results_file"
  
  # Offer to save the report
  if confirm "Would you like to save this report to your Desktop?"; then
    local report_path="$HOME/Desktop/network_scan_$(date +%Y%m%d_%H%M%S).txt"
    cp "$results_file" "$report_path"
    log "Report saved to: $report_path"
  fi
  
  # Clean up
  rm "$results_file"
  
  echo
  read -n 1 -s -r -p "Press any key to continue..."
} 