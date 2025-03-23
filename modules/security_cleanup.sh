#!/bin/bash

# security_cleanup.sh - Security cleanup and optimization functions

# Main security cleanup function
security_cleanup() {
  echo -e "\n${BLUE}=== Security Cleanup ===${NC}"
  check_privileges 1  # Recommend elevated privileges
  
  echo "1. Security audit"
  echo "2. Check for password-related issues"
  echo "3. Check firewall settings"
  echo "4. Check sharing settings"
  echo "5. Return to main menu"
  echo -n "Select an option: "
  read -r sec_choice
  
  case "$sec_choice" in
    1) security_audit ;;
    2) password_check ;;
    3) firewall_check ;;
    4) sharing_check ;;
    5) return ;;
    *) log --warn "Invalid choice. Returning to main menu."; return ;;
  esac
}

# Perform a security audit
security_audit() {
  echo -e "\n${BLUE}--- Security Audit ---${NC}"
  
  log "Performing comprehensive security audit..."
  
  # Create a temporary file for the security report
  local report_file=$(mktemp)
  echo "Security Audit Report - $(date)" > "$report_file"
  echo "---------------------------" >> "$report_file"
  echo "" >> "$report_file"
  
  # macOS Version information
  echo "### System Version ###" >> "$report_file"
  sw_vers >> "$report_file"
  echo "System build: $(system_profiler SPSoftwareDataType | grep "System Version" | cut -d: -f2- | xargs)" >> "$report_file"
  echo "" >> "$report_file"
  
  # Gatekeeper status
  echo "### Gatekeeper Status ###" >> "$report_file"
  spctl --status 2>&1 >> "$report_file"
  echo "" >> "$report_file"
  
  # System Integrity Protection status
  echo "### System Integrity Protection Status ###" >> "$report_file"
  csrutil status 2>&1 >> "$report_file"
  echo "" >> "$report_file"
  
  # Firewall status
  echo "### Firewall Status ###" >> "$report_file"
  defaults read /Library/Preferences/com.apple.alf globalstate 2>/dev/null >> "$report_file" || echo "Could not read firewall status" >> "$report_file"
  echo "Firewall status (0=off, 1=on for specific services, 2=on for essential services)" >> "$report_file"
  if [[ -f /usr/libexec/ApplicationFirewall/socketfilterfw ]]; then
    /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate >> "$report_file"
    /usr/libexec/ApplicationFirewall/socketfilterfw --getstealthmode >> "$report_file"
  fi
  echo "" >> "$report_file"
  
  # FileVault status
  echo "### FileVault Status ###" >> "$report_file"
  fdesetup status 2>&1 >> "$report_file"
  echo "" >> "$report_file"
  
  # Sharing services status
  echo "### Sharing Services Status ###" >> "$report_file"
  sharing_services=("Screen Sharing" "File Sharing" "Printer Sharing" "Remote Login" "Remote Management" "Remote Apple Events" "Internet Sharing" "Bluetooth Sharing" "Content Caching")
  for service in "${sharing_services[@]}"; do
    status=$(sudo systemsetup -getremotelogin 2>&1 | grep -i "on\|off")
    echo "$service: ${status:-Unknown}" >> "$report_file"
  done
  echo "" >> "$report_file"
  
  # Auto-login check
  echo "### Auto-Login Status ###" >> "$report_file"
  auto_login_user=$(defaults read /Library/Preferences/com.apple.loginwindow autoLoginUser 2>/dev/null)
  if [[ -n "$auto_login_user" ]]; then
    echo "WARNING: Auto-login is enabled for user $auto_login_user" >> "$report_file"
  else
    echo "Auto-login is disabled (good)" >> "$report_file"
  fi
  echo "" >> "$report_file"
  
  # Guest account check
  echo "### Guest Account Status ###" >> "$report_file"
  guest_enabled=$(defaults read /Library/Preferences/com.apple.loginwindow GuestEnabled 2>/dev/null)
  if [[ "$guest_enabled" == "1" ]]; then
    echo "WARNING: Guest account is enabled" >> "$report_file"
  else
    echo "Guest account is disabled (good)" >> "$report_file"
  fi
  echo "" >> "$report_file"
  
  # Check for software updates
  echo "### Available Software Updates ###" >> "$report_file"
  softwareupdate -l 2>/dev/null >> "$report_file"
  echo "" >> "$report_file"
  
  # Installed security apps
  echo "### Security Applications ###" >> "$report_file"
  security_apps=("Malwarebytes" "Sophos" "ClamXAV" "Bitdefender" "Norton" "McAfee" "ESET" "Avast" "AVG")
  for app in "${security_apps[@]}"; do
    if [[ -d "/Applications/${app}.app" ]]; then
      echo "$app is installed" >> "$report_file"
    fi
  done
  echo "" >> "$report_file"
  
  # Security recommendations
  echo "### Security Recommendations ###" >> "$report_file"
  echo "1. Keep macOS updated to the latest version" >> "$report_file"
  echo "2. Enable FileVault disk encryption" >> "$report_file"
  echo "3. Enable Firewall" >> "$report_file"
  echo "4. Disable all unnecessary sharing services" >> "$report_file"
  echo "5. Disable auto-login" >> "$report_file"
  echo "6. Disable guest account" >> "$report_file"
  echo "7. Use strong, unique passwords" >> "$report_file"
  echo "8. Consider using a password manager" >> "$report_file"
  echo "9. Enable two-factor authentication for Apple ID" >> "$report_file"
  echo "10. Review app permissions in System Preferences > Security & Privacy" >> "$report_file"
  echo "" >> "$report_file"
  
  # Display the report
  less "$report_file"
  
  # Offer to save the report
  if confirm "Would you like to save this security audit report to your Desktop?"; then
    local report_path="$HOME/Desktop/security_audit_$(date +%Y%m%d_%H%M%S).txt"
    cp "$report_file" "$report_path"
    log "Security audit report saved to: $report_path"
  fi
  
  # Clean up
  rm "$report_file"
  
  # Offer to fix issues
  if confirm "Would you like to fix security issues found in the audit?"; then
    echo "Select issues to fix:"
    echo "1. Enable/configure firewall"
    echo "2. Enable FileVault disk encryption"
    echo "3. Disable unnecessary sharing services"
    echo "4. Disable guest account"
    echo "5. All of the above"
    echo -n "Select an option (or 0 to skip): "
    read -r fix_choice
    
    case "$fix_choice" in
      1) firewall_check ;;
      2) 
        if [[ $DRY_RUN -eq 0 ]]; then
          log "Enabling FileVault..."
          run_command sudo fdesetup enable
        else
          log "DRY RUN: Would enable FileVault"
        fi
        ;;
      3) sharing_check ;;
      4)
        if [[ $DRY_RUN -eq 0 ]]; then
          log "Disabling guest account..."
          run_command sudo defaults write /Library/Preferences/com.apple.loginwindow GuestEnabled -bool NO
        else
          log "DRY RUN: Would disable guest account"
        fi
        ;;
      5)
        firewall_check
        if [[ $DRY_RUN -eq 0 ]]; then
          log "Enabling FileVault..."
          run_command sudo fdesetup enable
          log "Disabling guest account..."
          run_command sudo defaults write /Library/Preferences/com.apple.loginwindow GuestEnabled -bool NO
        else
          log "DRY RUN: Would enable FileVault and disable guest account"
        fi
        sharing_check
        ;;
      *) log "No fixes applied." ;;
    esac
  fi
  
  echo
  read -n 1 -s -r -p "Press any key to continue..."
}

# Check for password-related issues
password_check() {
  echo -e "\n${BLUE}--- Password Issues Check ---${NC}"
  
  log "Checking for password-related security issues..."
  
  # Create a temporary file for the report
  local report_file=$(mktemp)
  echo "Password Security Check - $(date)" > "$report_file"
  echo "---------------------------" >> "$report_file"
  echo "" >> "$report_file"
  
  # Check password policies
  echo "### Password Policies ###" >> "$report_file"
  pwpolicy -getaccountpolicies 2>/dev/null > "$report_file.tmp"
  if grep -q "maxMinutesUntilChangePassword" "$report_file.tmp"; then
    echo "Password expiration is enabled" >> "$report_file"
  else
    echo "No password expiration policy detected" >> "$report_file"
  fi
  rm "$report_file.tmp"
  
  # Check for password manager presence
  echo "" >> "$report_file"
  echo "### Password Manager Check ###" >> "$report_file"
  password_managers=("1Password" "LastPass" "Dashlane" "Bitwarden" "KeePassXC" "Keeper")
  found_pm=0
  for pm in "${password_managers[@]}"; do
    if [[ -d "/Applications/${pm}.app" ]]; then
      echo "$pm is installed" >> "$report_file"
      found_pm=1
    fi
  done
  if [[ $found_pm -eq 0 ]]; then
    echo "No password manager detected. Consider installing one for better password security." >> "$report_file"
  fi
  
  # Check keychain status
  echo "" >> "$report_file"
  echo "### Keychain Status ###" >> "$report_file"
  if ls -la "$HOME/Library/Keychains/" 2>/dev/null | grep -q "login.keychain"; then
    echo "Login keychain is present" >> "$report_file"
  else
    echo "WARNING: Login keychain not found or inaccessible" >> "$report_file"
  fi
  
  # Check for iCloud Keychain
  if defaults read MobileMeAccounts 2>/dev/null | grep -q "KEYCHAIN"; then
    echo "iCloud Keychain appears to be enabled" >> "$report_file"
  else
    echo "iCloud Keychain may not be enabled" >> "$report_file"
  fi
  
  # Password recommendations
  echo "" >> "$report_file"
  echo "### Password Recommendations ###" >> "$report_file"
  echo "1. Use strong, unique passwords for each account" >> "$report_file"
  echo "2. Consider using a password manager to store and generate secure passwords" >> "$report_file"
  echo "3. Enable two-factor authentication for important accounts" >> "$report_file"
  echo "4. Change passwords regularly (every 90 days is recommended)" >> "$report_file"
  echo "5. Don't reuse passwords across different services" >> "$report_file"
  echo "6. Minimum recommended password length: 12 characters" >> "$report_file"
  echo "7. Use a mix of uppercase, lowercase, numbers, and special characters" >> "$report_file"
  echo "8. Consider using a passphrase instead of a single password" >> "$report_file"
  echo "" >> "$report_file"
  
  # Display the report
  less "$report_file"
  
  # Offer to save the report
  if confirm "Would you like to save this password security report to your Desktop?"; then
    local report_path="$HOME/Desktop/password_security_$(date +%Y%m%d_%H%M%S).txt"
    cp "$report_file" "$report_path"
    log "Password security report saved to: $report_path"
  fi
  
  # Clean up
  rm "$report_file"
  
  # Offer to set password policies
  if confirm "Would you like to set recommended password policies?"; then
    if [[ $DRY_RUN -eq 0 ]]; then
      log "Setting password minimum length to 12 characters..."
      run_command sudo pwpolicy -setglobalpolicy "minChars=12"
      log "Setting password complexity requirements..."
      run_command sudo pwpolicy -setglobalpolicy "requiresNumeric=1 requiresAlpha=1 requiresSymbol=1"
      log "Password policies updated."
    else
      log "DRY RUN: Would set password policies for minimum length and complexity"
    fi
  fi
  
  # Offer to install a password manager
  if [[ $found_pm -eq 0 ]]; then
    if confirm "Would you like information on installing a password manager?"; then
      echo -e "\n${CYAN}Recommended Password Managers:${NC}"
      echo "1. 1Password: https://1password.com/"
      echo "2. Bitwarden: https://bitwarden.com/ (open source)"
      echo "3. KeePassXC: https://keepassxc.org/ (free and open source)"
      echo "4. LastPass: https://www.lastpass.com/"
      echo ""
      echo "These can be installed via their websites or the Mac App Store."
    fi
  fi
  
  echo
  read -n 1 -s -r -p "Press any key to continue..."
}

# Check firewall settings
firewall_check() {
  echo -e "\n${BLUE}--- Firewall Settings Check ---${NC}"
  
  # Need sudo for some operations
  if [[ $EUID -ne 0 ]]; then
    log --warn "This operation requires root privileges for full functionality."
    if ! confirm "Attempt to run with sudo?"; then
      return
    fi
  fi
  
  log "Checking firewall settings..."
  
  # Check firewall status
  local firewall_status=$(defaults read /Library/Preferences/com.apple.alf globalstate 2>/dev/null)
  
  if [[ "$firewall_status" == "0" ]]; then
    log --warn "Firewall is currently disabled."
    fw_status="Disabled"
  elif [[ "$firewall_status" == "1" ]]; then
    log "Firewall is enabled and set to allow signed applications."
    fw_status="Enabled (Allow signed apps)"
  elif [[ "$firewall_status" == "2" ]]; then
    log "Firewall is enabled and set to allow only essential services."
    fw_status="Enabled (Essential services only)"
  else
    log --warn "Could not determine firewall status."
    fw_status="Unknown"
  fi
  
  # Check stealth mode
  local stealth_mode=$(/usr/libexec/ApplicationFirewall/socketfilterfw --getstealthmode 2>/dev/null | grep -i "enabled\|disabled")
  
  # Display configuration options
  echo -e "\n${CYAN}Current Firewall Settings:${NC}"
  echo "Firewall: $fw_status"
  echo "Stealth Mode: $stealth_mode"
  echo ""
  echo "1. Enable firewall (allow signed applications)"
  echo "2. Enable firewall (allow essential services only)"
  echo "3. Enable stealth mode"
  echo "4. Disable firewall"
  echo "5. View firewall application rules"
  echo "6. Return to security menu"
  echo -n "Select an option: "
  read -r fw_choice
  
  case "$fw_choice" in
    1)  # Enable firewall (allow signed applications)
      if [[ $DRY_RUN -eq 1 ]]; then
        log "DRY RUN: Would enable firewall (allow signed applications)"
      else
        log "Enabling firewall..."
        run_command sudo defaults write /Library/Preferences/com.apple.alf globalstate -int 1
        run_command sudo launchctl unload /System/Library/LaunchDaemons/com.apple.alf.agent.plist 2>/dev/null
        run_command sudo launchctl load /System/Library/LaunchDaemons/com.apple.alf.agent.plist 2>/dev/null
        log "Firewall enabled and set to allow signed applications."
      fi
      ;;
      
    2)  # Enable firewall (essential services only)
      if [[ $DRY_RUN -eq 1 ]]; then
        log "DRY RUN: Would enable firewall (essential services only)"
      else
        log "Enabling firewall with strict settings..."
        run_command sudo defaults write /Library/Preferences/com.apple.alf globalstate -int 2
        run_command sudo launchctl unload /System/Library/LaunchDaemons/com.apple.alf.agent.plist 2>/dev/null
        run_command sudo launchctl load /System/Library/LaunchDaemons/com.apple.alf.agent.plist 2>/dev/null
        log "Firewall enabled and set to allow only essential services."
      fi
      ;;
      
    3)  # Enable stealth mode
      if [[ $DRY_RUN -eq 1 ]]; then
        log "DRY RUN: Would enable stealth mode"
      else
        log "Enabling stealth mode..."
        run_command sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on
        log "Stealth mode enabled. Your Mac will not respond to ICMP ping requests or connection attempts from closed TCP and UDP ports."
      fi
      ;;
      
    4)  # Disable firewall
      if confirm "Are you sure you want to disable the firewall? This is not recommended."; then
        if [[ $DRY_RUN -eq 1 ]]; then
          log "DRY RUN: Would disable firewall"
        else
          log "Disabling firewall..."
          run_command sudo defaults write /Library/Preferences/com.apple.alf globalstate -int 0
          run_command sudo launchctl unload /System/Library/LaunchDaemons/com.apple.alf.agent.plist 2>/dev/null
          run_command sudo launchctl load /System/Library/LaunchDaemons/com.apple.alf.agent.plist 2>/dev/null
          log --warn "Firewall has been disabled."
        fi
      fi
      ;;
      
    5)  # View firewall rules
      log "Current firewall application rules:"
      run_command sudo /usr/libexec/ApplicationFirewall/socketfilterfw --listapps
      ;;
      
    6)  # Return
      return
      ;;
      
    *)
      log --warn "Invalid choice."
      ;;
  esac
  
  echo
  read -n 1 -s -r -p "Press any key to continue..."
}

# Check sharing settings
sharing_check() {
  echo -e "\n${BLUE}--- Sharing Settings Check ---${NC}"
  
  # Need sudo for some operations
  if [[ $EUID -ne 0 ]]; then
    log --warn "This operation requires root privileges for full functionality."
    if ! confirm "Attempt to run with sudo?"; then
      return
    fi
  fi
  
  log "Checking sharing service settings..."
  
  # Check status of sharing services
  echo -e "\n${CYAN}Current Sharing Settings:${NC}"
  
  # Remote Login (SSH)
  local remote_login=$(sudo systemsetup -getremotelogin 2>&1 | grep -i "on\|off")
  echo "Remote Login (SSH): $remote_login"
  
  # Screen Sharing (VNC)
  if [[ -f "/System/Library/LaunchDaemons/com.apple.screensharing.plist" ]]; then
    local screen_sharing_loaded=$(sudo launchctl list | grep -c "com.apple.screensharing")
    if [[ $screen_sharing_loaded -gt 0 ]]; then
      echo "Screen Sharing (VNC): On"
    else
      echo "Screen Sharing (VNC): Off"
    fi
  else
    echo "Screen Sharing (VNC): Off"
  fi
  
  # File Sharing (SMB/AFP)
  if [[ -f "/System/Library/LaunchDaemons/com.apple.smbd.plist" ]]; then
    local file_sharing_loaded=$(sudo launchctl list | grep -c "com.apple.smbd")
    if [[ $file_sharing_loaded -gt 0 ]]; then
      echo "File Sharing (SMB): On"
    else
      echo "File Sharing (SMB): Off"
    fi
  else
    echo "File Sharing (SMB): Off"
  fi
  
  # Printer Sharing
  if [[ -f "/System/Library/LaunchDaemons/org.cups.cupsd.plist" ]]; then
    local printer_sharing_enabled=$(sudo cupsctl | grep -c "_share_printers=1")
    if [[ $printer_sharing_enabled -gt 0 ]]; then
      echo "Printer Sharing: On"
    else
      echo "Printer Sharing: Off"
    fi
  else
    echo "Printer Sharing: Off"
  fi
  
  # Internet Sharing
  local internet_sharing=$(defaults read /Library/Preferences/SystemConfiguration/com.apple.nat 2>/dev/null | grep -c "Enabled = 1")
  if [[ $internet_sharing -gt 0 ]]; then
    echo "Internet Sharing: On"
    internet_status="On"
  else
    echo "Internet Sharing: Off"
    internet_status="Off"
  fi
  
  # Bluetooth Sharing
  local bluetooth_sharing=$(defaults read /Library/Preferences/com.apple.Bluetooth PrefKeyServicesEnabled 2>/dev/null)
  if [[ "$bluetooth_sharing" == "1" ]]; then
    echo "Bluetooth Sharing: On"
    bluetooth_status="On"
  else
    echo "Bluetooth Sharing: Off"
    bluetooth_status="Off"
  fi
  
  # Options menu
  echo -e "\n${CYAN}Sharing Options:${NC}"
  echo "1. Disable all sharing services (recommended for security)"
  echo "2. Enable/disable specific services"
  echo "3. Return to security menu"
  echo -n "Select an option: "
  read -r share_choice
  
  case "$share_choice" in
    1)  # Disable all
      if [[ $DRY_RUN -eq 1 ]]; then
        log "DRY RUN: Would disable all sharing services"
      else
        log "Disabling all sharing services..."
        
        # Disable Remote Login
        run_command sudo systemsetup -setremotelogin off
        
        # Disable Screen Sharing
        run_command sudo launchctl unload -w /System/Library/LaunchDaemons/com.apple.screensharing.plist 2>/dev/null
        
        # Disable File Sharing
        run_command sudo launchctl unload -w /System/Library/LaunchDaemons/com.apple.smbd.plist 2>/dev/null
        
        # Disable Printer Sharing
        run_command sudo cupsctl --no-share-printers
        
        # Disable Internet Sharing
        if [[ "$internet_status" == "On" ]]; then
          run_command sudo defaults write /Library/Preferences/SystemConfiguration/com.apple.nat NAT -dict Enabled -int 0
        fi
        
        # Disable Bluetooth Sharing
        if [[ "$bluetooth_status" == "On" ]]; then
          run_command sudo defaults write /Library/Preferences/com.apple.Bluetooth PrefKeyServicesEnabled -bool false
        fi
        
        log "All sharing services have been disabled."
      fi
      ;;
      
    2)  # Enable/disable specific
      echo "Select service to configure:"
      echo "1. Remote Login (SSH)"
      echo "2. Screen Sharing (VNC)"
      echo "3. File Sharing (SMB)"
      echo "4. Printer Sharing"
      echo "5. Internet Sharing"
      echo "6. Bluetooth Sharing"
      echo -n "Select an option: "
      read -r service_choice
      
      echo "Enable this service? (y/n):"
      read -r enable_choice
      
      if [[ $DRY_RUN -eq 1 ]]; then
        log "DRY RUN: Would configure sharing service"
      else
        case "$service_choice" in
          1)  # Remote Login
            if [[ "$enable_choice" == "y" ]]; then
              run_command sudo systemsetup -setremotelogin on
              log "Remote Login (SSH) enabled."
            else
              run_command sudo systemsetup -setremotelogin off
              log "Remote Login (SSH) disabled."
            fi
            ;;
            
          2)  # Screen Sharing
            if [[ "$enable_choice" == "y" ]]; then
              run_command sudo launchctl load -w /System/Library/LaunchDaemons/com.apple.screensharing.plist
              log "Screen Sharing (VNC) enabled."
            else
              run_command sudo launchctl unload -w /System/Library/LaunchDaemons/com.apple.screensharing.plist
              log "Screen Sharing (VNC) disabled."
            fi
            ;;
            
          3)  # File Sharing
            if [[ "$enable_choice" == "y" ]]; then
              run_command sudo launchctl load -w /System/Library/LaunchDaemons/com.apple.smbd.plist
              log "File Sharing (SMB) enabled."
            else
              run_command sudo launchctl unload -w /System/Library/LaunchDaemons/com.apple.smbd.plist
              log "File Sharing (SMB) disabled."
            fi
            ;;
            
          4)  # Printer Sharing
            if [[ "$enable_choice" == "y" ]]; then
              run_command sudo cupsctl --share-printers
              log "Printer Sharing enabled."
            else
              run_command sudo cupsctl --no-share-printers
              log "Printer Sharing disabled."
            fi
            ;;
            
          5)  # Internet Sharing
            if [[ "$enable_choice" == "y" ]]; then
              log --warn "Internet Sharing should be configured through the System Preferences UI."
              log --warn "Command line configuration might be inconsistent."
            else
              run_command sudo defaults write /Library/Preferences/SystemConfiguration/com.apple.nat NAT -dict Enabled -int 0
              log "Internet Sharing disabled."
            fi
            ;;
            
          6)  # Bluetooth Sharing
            if [[ "$enable_choice" == "y" ]]; then
              run_command sudo defaults write /Library/Preferences/com.apple.Bluetooth PrefKeyServicesEnabled -bool true
              log "Bluetooth Sharing enabled."
            else
              run_command sudo defaults write /Library/Preferences/com.apple.Bluetooth PrefKeyServicesEnabled -bool false
              log "Bluetooth Sharing disabled."
            fi
            ;;
            
          *)
            log --warn "Invalid choice."
            ;;
        esac
      fi
      ;;
      
    3)  # Return
      return
      ;;
      
    *)
      log --warn "Invalid choice."
      ;;
  esac
  
  echo
  read -n 1 -s -r -p "Press any key to continue..."
} 