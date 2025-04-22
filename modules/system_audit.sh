#!/bin/bash

# system_audit.sh - Enhanced system auditing and reporting functions for macOS 2025

# Main system audit function
system_audit() {
  echo -e "\n${BLUE}=== System Audit and Reports ===${NC}"
  
  echo "1. Generate comprehensive system report"
  echo "2. Check privacy permissions and app authorizations"
  echo "3. Analyze disk space usage"
  echo "4. Generate security compliance report"
  echo "5. Scan for large and duplicate files"
  echo "6. Generate app usage statistics"
  echo "7. Check for macOS compatibility issues"
  echo "8. View previous reports"
  echo "9. Return to main menu"
  echo -n "Select an option: "
  read -r audit_choice
  
  case "$audit_choice" in
    1) generate_system_report ;;
    2) check_privacy_permissions ;;
    3) analyze_disk_usage ;;
    4) generate_security_report ;;
    5) scan_for_large_files ;;
    6) app_usage_statistics ;;
    7) check_compatibility_issues ;;
    8) view_previous_reports "$HOME/Documents/macOS_System_Reports" ;;
    9) return ;;
    *) log --warn "Invalid choice. Returning to main menu."; return ;;
  esac
}

# View previous reports (keep existing function)
view_previous_reports() {
  local report_dir="$1"
  
  # List all HTML reports
  local reports=()
  while IFS= read -r file; do
    if [[ "$file" == *.html ]]; then
      reports+=("$file")
    fi
  done < <(find "$report_dir" -type f -name "*.html" | sort -r)
  
  if [[ ${#reports[@]} -eq 0 ]]; then
    log "No previous reports found."
    read -n 1 -s -r -p "Press any key to continue..."
    return
  fi
  
  echo -e "\n${BLUE}--- Previous System Reports ---${NC}"
  for i in "${!reports[@]}"; do
    local file="${reports[$i]}"
    local filename=$(basename "$file")
    local date_str=$(echo "$filename" | sed 's/system_report_\(.*\)\.html/\1/' | tr '_' ' ')
    echo "$((i+1)). Report from $(date -r "$file" "+%Y-%m-%d %H:%M:%S")"
  done
  
  echo -e "\nSelect a report to open (number), or 0 to return:"
  read -r report_choice
  
  if [[ "$report_choice" == "0" ]]; then
    return
  elif [[ "$report_choice" =~ ^[0-9]+$ && "$report_choice" -le "${#reports[@]}" ]]; then
    # Open the selected report
    open "${reports[$((report_choice-1))]}"
  else
    log --warn "Invalid choice."
  fi
  
  read -n 1 -s -r -p "Press any key to continue..."
}

# Generate a comprehensive system report
generate_system_report() {
  echo -e "\n${BLUE}--- Generating Comprehensive System Report ---${NC}"
  
  log "This will collect various system information and generate a comprehensive report."
  
  # Create a timestamp for the report
  local timestamp=$(date "+%Y-%m-%d_%H-%M-%S")
  local report_dir="$HOME/Documents/macOS_System_Reports"
  local html_report="$report_dir/system_report_$timestamp.html"
  
  # Create reports directory if it doesn't exist
  mkdir -p "$report_dir"
  
  # Create a temporary directory for report files
  local tmp_dir=$(mktemp -d)
  local main_report="$tmp_dir/system_report.txt"
  
  echo "CR Mac Helper - System Report" > "$main_report"
  echo "Generated: $(date)" >> "$main_report"
  echo "=================================" >> "$main_report"
  echo "" >> "$main_report"
  
  # System and hardware information
  echo "### SYSTEM INFORMATION ###" >> "$main_report"
  echo "macOS Version:" >> "$main_report"
  sw_vers >> "$main_report"
  echo "" >> "$main_report"
  
  echo "Hardware Overview:" >> "$main_report"
  system_profiler SPHardwareDataType | grep -v -E "Serial Number|UUID|Provisioning|Hardware UUID" >> "$main_report"
  echo "" >> "$main_report"
  
  # Apple Silicon specific info
  if [[ "$(uname -m)" == "arm64" ]]; then
    echo "Apple Silicon Details:" >> "$main_report"
    system_profiler SPiBridgeDataType 2>/dev/null >> "$main_report"
    echo "" >> "$main_report"
  fi
  
  # CPU and memory
  echo "### CPU & MEMORY ###" >> "$main_report"
  echo "CPU Info:" >> "$main_report"
  sysctl -n machdep.cpu.brand_string 2>/dev/null >> "$main_report" || echo "Information not available" >> "$main_report"
  echo "CPU Cores: $(sysctl -n hw.ncpu 2>/dev/null)" >> "$main_report"
  echo "" >> "$main_report"
  
  echo "Memory Info:" >> "$main_report"
  echo "Total Memory: $(( $(sysctl -n hw.memsize 2>/dev/null) / 1073741824 )) GB" >> "$main_report"
  echo "Memory Usage:" >> "$main_report"
  vm_stat | perl -ne '/page size of (\d+)/ and $size=$1; /Pages\s+([^:]+)[^\d]+(\d+)/ and printf("%-20s %10.2f MB\n", "$1:", $2 * $size / 1048576);' >> "$main_report"
  echo "" >> "$main_report"
  
  # Storage information
  echo "### STORAGE ###" >> "$main_report"
  echo "Disk Information:" >> "$main_report"
  df -h >> "$main_report"
  echo "" >> "$main_report"
  
  echo "Disk Health:" >> "$main_report"
  system_profiler SPStorageDataType | grep -v -E "Mount Point|Volume Name|Disk [sS]ize|Free [sS]pace|Used [sS]pace" >> "$main_report"
  echo "" >> "$main_report"
  
  # Network configuration
  echo "### NETWORK ###" >> "$main_report"
  echo "Active Network Services:" >> "$main_report"
  networksetup -listallnetworkservices | grep -v '*' >> "$main_report"
  echo "" >> "$main_report"
  
  echo "Network Interfaces:" >> "$main_report"
  ifconfig | grep -E "^[a-zA-Z0-9]+:|inet |status" >> "$main_report"
  echo "" >> "$main_report"
  
  # Power management (for laptops)
  if system_profiler SPPowerDataType | grep -q "Battery"; then
    echo "### POWER MANAGEMENT ###" >> "$main_report"
    echo "Battery Information:" >> "$main_report"
    system_profiler SPPowerDataType >> "$main_report"
    echo "" >> "$main_report"
  fi
  
  # Security settings
  echo "### SECURITY SETTINGS ###" >> "$main_report"
  echo "FileVault Status:" >> "$main_report"
  fdesetup status 2>&1 >> "$main_report"
  echo "" >> "$main_report"
  
  echo "Firewall Status:" >> "$main_report"
  defaults read /Library/Preferences/com.apple.alf globalstate 2>/dev/null >> "$main_report" || echo "Not available" >> "$main_report"
  echo "Firewall status (0=off, 1=on for specific services, 2=on for essential services)" >> "$main_report"
  echo "" >> "$main_report"
  
  echo "System Integrity Protection Status:" >> "$main_report"
  csrutil status 2>&1 >> "$main_report"
  echo "" >> "$main_report"
  
  # Software and updates
  echo "### SOFTWARE ###" >> "$main_report"
  echo "Software Updates Available:" >> "$main_report"
  softwareupdate -l 2>&1 >> "$main_report"
  echo "" >> "$main_report"
  
  # Top running processes
  echo "### PROCESSES ###" >> "$main_report"
  echo "Top CPU Processes:" >> "$main_report"
  ps aux | head -1 >> "$main_report"
  ps aux | sort -nr -k 3 | head -10 >> "$main_report"
  echo "" >> "$main_report"
  
  echo "Top Memory Processes:" >> "$main_report"
  ps aux | head -1 >> "$main_report"
  ps aux | sort -nr -k 4 | head -10 >> "$main_report"
  echo "" >> "$main_report"
  
  # Startup items
  echo "### STARTUP ITEMS ###" >> "$main_report"
  echo "Launch Agents (User):" >> "$main_report"
  ls -la ~/Library/LaunchAgents 2>/dev/null >> "$main_report" || echo "No user launch agents found." >> "$main_report"
  echo "" >> "$main_report"
  
  echo "Launch Agents (System):" >> "$main_report"
  ls -la /Library/LaunchAgents 2>/dev/null >> "$main_report" || echo "No system launch agents found." >> "$main_report"
  echo "" >> "$main_report"
  
  echo "Launch Daemons:" >> "$main_report"
  ls -la /Library/LaunchDaemons 2>/dev/null >> "$main_report" || echo "No launch daemons found." >> "$main_report"
  echo "" >> "$main_report"
  
  # System recommendations
  echo "### SYSTEM RECOMMENDATIONS ###" >> "$main_report"
  echo "Based on the collected information, consider the following recommendations:" >> "$main_report"
  
  # Check system version
  local os_version=$(sw_vers -productVersion)
  local is_outdated=0
  if [[ "$os_version" < "14.0" ]]; then
    echo "- Update macOS to the latest version (current: $os_version)" >> "$main_report"
    is_outdated=1
  fi
  
  # Check FileVault
  if ! fdesetup status | grep -q "is On"; then
    echo "- Enable FileVault disk encryption for better security" >> "$main_report"
  fi
  
  # Check free disk space
  local disk_free=$(df -h / | awk 'NR==2 {print $4}' | sed 's/[A-Za-z]//g')
  if (( $(echo "$disk_free < 20" | bc -l) )); then
    echo "- Free up disk space (only $disk_free GB available)" >> "$main_report"
  fi
  
  # Check firewall status
  local firewall_status=$(defaults read /Library/Preferences/com.apple.alf globalstate 2>/dev/null)
  if [[ "$firewall_status" == "0" ]]; then
    echo "- Enable the macOS firewall for better security" >> "$main_report"
  fi
  
  # Other common recommendations
  echo "- Regularly back up important data with Time Machine" >> "$main_report"
  echo "- Review and update privacy permissions in System Settings > Privacy & Security" >> "$main_report"
  echo "- Clean up unused applications and large files" >> "$main_report"
  echo "- Check login items and disable unnecessary startup items" >> "$main_report"
  echo "" >> "$main_report"
  
  # Final HTML report generation
  generate_html_report "$main_report" "$html_report"
  
  # Clean up temporary directory
  rm -rf "$tmp_dir"
  
  log "System report generated: $html_report"
  
  if confirm "Would you like to view the report now?"; then
    open "$html_report"
  fi
  
  echo
  read -n 1 -s -r -p "Press any key to continue..."
}

# Generate HTML report from text report
generate_html_report() {
  local main_report="$1"
  local html_report="$2"
  
  cat > "$html_report" << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>CR Mac Helper - System Report</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, 'Open Sans', 'Helvetica Neue', sans-serif;
            line-height: 1.6;
            color: #333;
            margin: 0;
            padding: 20px;
            background-color: #f5f5f7;
        }
        .container {
            max-width: 1000px;
            margin: 0 auto;
            background-color: white;
            padding: 30px;
            border-radius: 10px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
        }
        h1, h2, h3 {
            color: #007aff;
        }
        h1 {
            border-bottom: 2px solid #007aff;
            padding-bottom: 10px;
        }
        h2 {
            margin-top: 30px;
            border-bottom: 1px solid #ddd;
            padding-bottom: 5px;
        }
        .section {
            margin-bottom: 30px;
        }
        pre {
            background-color: #f1f1f1;
            padding: 15px;
            border-radius: 5px;
            overflow-x: auto;
            font-family: monospace;
            white-space: pre-wrap;
        }
        .recommendations {
            background-color: #e8f5ff;
            padding: 20px;
            border-radius: 5px;
            border-left: 5px solid #007aff;
        }
        .recommendations ul {
            margin-top: 10px;
        }
        .timestamp {
            color: #666;
            font-style: italic;
        }
        .footer {
            margin-top: 40px;
            text-align: center;
            font-size: 0.9em;
            color: #666;
            border-top: 1px solid #ddd;
            padding-top: 10px;
        }
        nav {
            position: fixed;
            top: 20px;
            right: 20px;
            background: white;
            border-radius: 5px;
            padding: 10px;
            box-shadow: 0 2px 5px rgba(0,0,0,0.1);
            max-width: 200px;
            max-height: 80vh;
            overflow-y: auto;
            font-size: 0.9em;
        }
        nav ul {
            list-style-type: none;
            padding: 0;
            margin: 0;
        }
        nav li {
            margin-bottom: 5px;
        }
        nav a {
            text-decoration: none;
            color: #007aff;
        }
        nav a:hover {
            text-decoration: underline;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>CR Mac Helper - System Report</h1>
        <p class="timestamp">Generated on $(date)</p>
EOF

  # Create navigation menu
  echo '<nav>
    <strong>Table of Contents</strong>
    <ul>' >> "$html_report"
  
  # Extract section headers for navigation
  grep "^### " "$main_report" | while read -r section; do
    section_name=$(echo "$section" | sed 's/### //')
    section_id=$(echo "$section_name" | tr '[:upper:] ' '[:lower:]-')
    echo "<li><a href=\"#$section_id\">$section_name</a></li>" >> "$html_report"
  done
  
  echo '</ul>
</nav>' >> "$html_report"

  # Convert report sections to HTML
  local current_section=""
  while IFS= read -r line; do
    if [[ "$line" == "### "* ]]; then
      # Close previous section if one exists
      if [[ -n "$current_section" ]]; then
        echo "        </pre>
    </div>" >> "$html_report"
      fi
      
      # Start new section
      current_section=$(echo "$line" | sed 's/### //')
      section_id=$(echo "$current_section" | tr '[:upper:] ' '[:lower:]-')
      
      echo "    <div class=\"section\" id=\"$section_id\">
        <h2>$current_section</h2>
        <pre>" >> "$html_report"
    elif [[ "$line" == "CR Mac Helper - System Report" || "$line" == "Generated:"* || "$line" == "================="* ]]; then
      # Skip header lines
      continue
    elif [[ -n "$current_section" ]]; then
      # Add line to current section
      echo "$line" >> "$html_report"
    fi
  done < "$main_report"
  
  # Close last section
  if [[ -n "$current_section" ]]; then
    echo "        </pre>
    </div>" >> "$html_report"
  fi
  
  # Add footer and close HTML
  echo "        <div class=\"footer\">
            <p>Generated by CR Mac Helper v1.1</p>
        </div>
    </div>
</body>
</html>" >> "$html_report"
}

# Check privacy permissions and app authorizations
check_privacy_permissions() {
  echo -e "\n${BLUE}--- Privacy Permissions and App Authorizations ---${NC}"
  
  log "Analyzing privacy permissions granted to applications..."
  
  # Create temporary file for report
  local report_file=$(mktemp)
  echo "Privacy Permissions and App Authorizations" > "$report_file"
  echo "Generated: $(date)" >> "$report_file"
  echo "=========================================" >> "$report_file"
  echo "" >> "$report_file"
  
  # Check TCC database for permissions
  echo "### App Privacy Permissions ###" >> "$report_file"
  echo "The following applications have been granted privacy permissions:" >> "$report_file"
  echo "" >> "$report_file"
  
  # TCC permission types to check
  local permission_types=(
    "kTCCServiceCamera"
    "kTCCServiceMicrophone"
    "kTCCServiceLocation"
    "kTCCServiceContactsFull"
    "kTCCServiceCalendarFull"
    "kTCCServiceReminders"
    "kTCCServicePhotos"
    "kTCCServiceMediaLibrary"
    "kTCCServiceScreenCapture"
    "kTCCServiceAccessibility"
    "kTCCServicePostEvent"
    "kTCCServiceSystemPolicyAllFiles"
    "kTCCServicePrototype4"
  )
  
  local permission_names=(
    "Camera"
    "Microphone"
    "Location"
    "Contacts"
    "Calendar"
    "Reminders"
    "Photos"
    "Music Library"
    "Screen Recording"
    "Accessibility"
    "Input Monitoring"
    "Full Disk Access"
    "Notification Center"
  )
  
  # Try to access both user and system databases
  local tcc_files=(
    "$HOME/Library/Application Support/com.apple.TCC/TCC.db"
    "/Library/Application Support/com.apple.TCC/TCC.db"
  )
  
  for i in "${!permission_types[@]}"; do
    local permission="${permission_types[$i]}"
    local perm_name="${permission_names[$i]}"
    
    echo "--- $perm_name Access ---" >> "$report_file"
    local found=0
    
    for tcc_file in "${tcc_files[@]}"; do
      if [[ -f "$tcc_file" ]]; then
        # Try to read the database (may fail due to permissions)
        if [[ $DRY_RUN -eq 0 ]]; then
          local query_result=$(sqlite3 "$tcc_file" "SELECT client,auth_value FROM access WHERE service='$permission'" 2>/dev/null)
          
          if [[ -n "$query_result" ]]; then
            echo "$query_result" | while IFS='|' read -r app auth; do
              if [[ "$auth" == "2" ]]; then
                local auth_status="Allowed"
              else
                local auth_status="Denied"
              fi
              
              echo "- $app: $auth_status" >> "$report_file"
              found=1
            done
          fi
        fi
      fi
    done
    
    if [[ $found -eq 0 ]]; then
      echo "No applications found with $perm_name permissions" >> "$report_file"
    fi
    
    echo "" >> "$report_file"
  done
  
  # Check login items
  echo "### Login Items ###" >> "$report_file"
  echo "The following items are set to start at login:" >> "$report_file"
  
  # Modern login items (macOS 13+)
  echo "System Settings Login Items:" >> "$report_file"
  local login_items_plist="$HOME/Library/Application Support/com.apple.backgroundtaskmanagementagent/backgrounditems.btm"
  if [[ -f "$login_items_plist" ]]; then
    if [[ $DRY_RUN -eq 0 ]]; then
      local items=$(plutil -convert xml1 -o - "$login_items_plist" 2>/dev/null | grep -A1 "string" | grep "string" | sed -e 's/<string>//g' -e 's/<\/string>//g' -e 's/^[[:space:]]*//')
      
      if [[ -n "$items" ]]; then
        echo "$items" | while IFS= read -r item; do
          echo "- $item" >> "$report_file"
        done
      else
        echo "No modern login items found" >> "$report_file"
      fi
    fi
  else
    echo "Background items file not found" >> "$report_file"
  fi
  
  # Legacy login items
  echo "" >> "$report_file"
  echo "Legacy Login Items:" >> "$report_file"
  local legacy_items=$(osascript -e 'tell application "System Events" to get the name of every login item' 2>/dev/null)
  
  if [[ -n "$legacy_items" && "$legacy_items" != *"error"* ]]; then
    echo "$legacy_items" | tr ',' '\n' | while IFS= read -r item; do
      item=$(echo "$item" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
      echo "- $item" >> "$report_file"
    done
  else
    echo "No legacy login items found or access denied" >> "$report_file"
  fi
  
  echo "" >> "$report_file"
  
  # Launch Agents and Daemons
  echo "### Launch Agents and Daemons ###" >> "$report_file"
  
  local launch_paths=(
    "$HOME/Library/LaunchAgents"
    "/Library/LaunchAgents"
    "/Library/LaunchDaemons"
    "/System/Library/LaunchAgents"
    "/System/Library/LaunchDaemons"
  )
  
  for path in "${launch_paths[@]}"; do
    if [[ -d "$path" ]]; then
      local dir_name=$(basename "$path")
      local parent_dir=$(basename "$(dirname "$path")")
      
      echo "--- $parent_dir/$dir_name ---" >> "$report_file"
      ls -1 "$path"/*.plist 2>/dev/null | while IFS= read -r plist; do
        local name=$(basename "$plist")
        echo "- $name" >> "$report_file"
      done
      echo "" >> "$report_file"
    fi
  done
  
  # Recommendations
  echo "### Recommendations ###" >> "$report_file"
  echo "1. Regularly audit your privacy permissions and revoke unnecessary access" >> "$report_file"
  echo "2. Review login items and background services, removing those you don't recognize" >> "$report_file"
  echo "3. Be cautious with apps that request Full Disk Access, Accessibility, or Input Monitoring" >> "$report_file"
  echo "4. Disable Microphone and Camera access for apps that don't need it" >> "$report_file"
  echo "5. Check System Settings > Privacy & Security regularly to review permissions" >> "$report_file"
  echo "" >> "$report_file"
  
  # Display the report
  less "$report_file"
  
  # Offer to save the report
  if confirm "Would you like to save this privacy permissions report to your Desktop?"; then
    local report_path="$HOME/Desktop/privacy_permissions_$(date +%Y%m%d_%H%M%S).txt"
    cp "$report_file" "$report_path"
    log "Privacy permissions report saved to: $report_path"
  fi
  
  # Clean up
  rm "$report_file"
  
  echo
  read -n 1 -s -r -p "Press any key to continue..."
}

# Analyze disk space usage
analyze_disk_usage() {
  echo -e "\n${BLUE}--- Disk Space Usage Analysis ---${NC}"
  
  log "Analyzing disk space usage. This may take a moment..."
  
  # Create temporary file for report
  local report_file=$(mktemp)
  
  echo "Disk Space Usage Analysis" > "$report_file"
  echo "Generated: $(date)" >> "$report_file"
  echo "=========================" >> "$report_file"
  echo "" >> "$report_file"
  
  # System overview
  echo "### System Storage Overview ###" >> "$report_file"
  df -h | grep -v tmpfs >> "$report_file"
  echo "" >> "$report_file"
  
  # Large directories in home
  echo "### Largest Directories in Home ###" >> "$report_file"
  echo "Finding largest directories in $HOME..." | tee -a "$report_file"
  if [[ $DRY_RUN -eq 0 ]]; then
    find "$HOME" -type d -not -path "*/\.*" -depth 1 -exec du -sh {} \; 2>/dev/null | sort -hr | head -15 >> "$report_file"
  fi
  echo "" >> "$report_file"
  
  # Large directories in Applications
  echo "### Application Sizes ###" >> "$report_file"
  echo "Finding largest applications..." | tee -a "$report_file"
  if [[ $DRY_RUN -eq 0 ]]; then
    find /Applications -maxdepth 1 -name "*.app" -exec du -sh {} \; 2>/dev/null | sort -hr | head -15 >> "$report_file"
  fi
  echo "" >> "$report_file"
  
  # User caches
  echo "### User Cache Size ###" >> "$report_file"
  local cache_size=$(du -sh "$HOME/Library/Caches" 2>/dev/null | cut -f1)
  echo "User Caches: $cache_size" >> "$report_file"
  echo "" >> "$report_file"
  
  # System caches
  echo "### System Cache Size ###" >> "$report_file"
  local sys_cache_size=$(sudo du -sh /Library/Caches 2>/dev/null | cut -f1)
  echo "System Caches: ${sys_cache_size:-Permission denied}" >> "$report_file"
  echo "" >> "$report_file"
  
  # Downloads folder
  echo "### Downloads Folder Size ###" >> "$report_file"
  local downloads_size=$(du -sh "$HOME/Downloads" 2>/dev/null | cut -f1)
  echo "Downloads Folder: $downloads_size" >> "$report_file"
  echo "" >> "$report_file"
  
  # Trash size
  echo "### Trash Size ###" >> "$report_file"
  local trash_size=$(du -sh "$HOME/.Trash" 2>/dev/null | cut -f1)
  echo "Trash: ${trash_size:-Empty or inaccessible}" >> "$report_file"
  echo "" >> "$report_file"
  
  # iOS backups
  echo "### iOS Backups Size ###" >> "$report_file"
  local backups_path="$HOME/Library/Application Support/MobileSync/Backup"
  if [[ -d "$backups_path" ]]; then
    local backup_size=$(du -sh "$backups_path" 2>/dev/null | cut -f1)
    echo "iOS Backups: $backup_size" >> "$report_file"
    
    # List individual backups
    find "$backups_path" -maxdepth 1 -type d -not -path "$backups_path" -exec du -sh {} \; 2>/dev/null | sort -hr >> "$report_file"
  else
    echo "No iOS backups found" >> "$report_file"
  fi
  echo "" >> "$report_file"
  
  # Mail downloads and attachments
  echo "### Mail Attachments ###" >> "$report_file"
  local mail_path="$HOME/Library/Mail"
  if [[ -d "$mail_path" ]]; then
    local mail_size=$(du -sh "$mail_path" 2>/dev/null | cut -f1)
    echo "Mail Data: $mail_size" >> "$report_file"
  else
    echo "Mail data not found" >> "$report_file"
  fi
  echo "" >> "$report_file"
  
  # XCode derived data
  echo "### Xcode Data ###" >> "$report_file"
  local xcode_derived="$HOME/Library/Developer/Xcode/DerivedData"
  if [[ -d "$xcode_derived" ]]; then
    local derived_size=$(du -sh "$xcode_derived" 2>/dev/null | cut -f1)
    echo "Xcode Derived Data: $derived_size" >> "$report_file"
  else
    echo "No Xcode derived data found" >> "$report_file"
  fi
  echo "" >> "$report_file"
  
  # Recommendations
  echo "### Storage Optimization Recommendations ###" >> "$report_file"
  echo "Based on the analysis, consider these actions to free up disk space:" >> "$report_file"
  echo "1. Empty the Trash (Current size: ${trash_size:-Unknown})" >> "$report_file"
  echo "2. Clean up your Downloads folder (Current size: ${downloads_size:-Unknown})" >> "$report_file"
  echo "3. Clear application caches (User caches: ${cache_size:-Unknown}, System caches: ${sys_cache_size:-Unknown})" >> "$report_file"
  
  if [[ -d "$backups_path" ]]; then
    echo "4. Remove old iOS backups (Total size: ${backup_size:-Unknown})" >> "$report_file"
  fi
  
  if [[ -d "$xcode_derived" ]]; then
    echo "5. Clear Xcode derived data (Current size: ${derived_size:-Unknown})" >> "$report_file"
  fi
  
  echo "6. Uninstall large unused applications" >> "$report_file"
  echo "7. Move large files to external storage or cloud services" >> "$report_file"
  echo "8. Use the 'Clean Caches' option in CR Mac Helper regularly" >> "$report_file"
  echo "" >> "$report_file"
  
  # Display the report
  less "$report_file"
  
  # Offer to save the report
  if confirm "Would you like to save this disk usage report to your Desktop?"; then
    local report_path="$HOME/Desktop/disk_usage_$(date +%Y%m%d_%H%M%S).txt"
    cp "$report_file" "$report_path"
    log "Disk usage report saved to: $report_path"
  fi
  
  # Clean up
  rm "$report_file"
  
  echo
  read -n 1 -s -r -p "Press any key to continue..."
}

# Generate security compliance report
generate_security_report() {
  echo -e "\n${BLUE}--- Security Compliance Report ---${NC}"
  
  log "Generating security compliance report..."
  
  # Create temporary file for report
  local report_file=$(mktemp)
  
  echo "Security Compliance Report" > "$report_file"
  echo "Generated: $(date)" >> "$report_file"
  echo "=========================" >> "$report_file"
  echo "" >> "$report_file"
  
  # OS version check
  echo "### Operating System ###" >> "$report_file"
  local os_version=$(sw_vers -productVersion)
  local os_build=$(sw_vers -buildVersion)
  echo "macOS Version: $os_version (Build $os_build)" >> "$report_file"
  
  # Check if running latest major OS
  if [[ "$os_version" < "14.0" ]]; then
    echo "⚠️ WARNING: Not running the latest major version of macOS" >> "$report_file"
    echo "Recommendation: Update to macOS Sequoia (15.0) or later for the latest security features." >> "$report_file"
  else
    echo "✓ Running a current major version of macOS" >> "$report_file"
  fi
  
  # Check for pending updates
  echo "" >> "$report_file"
  echo "Software Updates:" >> "$report_file"
  local updates=$(softwareupdate -l 2>&1)
  if [[ "$updates" == *"No new software available"* ]]; then
    echo "✓ System is up to date" >> "$report_file"
  else
    echo "⚠️ Software updates available:" >> "$report_file"
    echo "$updates" >> "$report_file"
    echo "Recommendation: Install available updates as soon as possible." >> "$report_file"
  fi
  echo "" >> "$report_file"
  
  # System Integrity Protection
  echo "### System Integrity Protection ###" >> "$report_file"
  local sip_status=$(csrutil status)
  if [[ "$sip_status" == *"enabled"* ]]; then
    echo "✓ System Integrity Protection is enabled" >> "$report_file"
  else
    echo "⚠️ WARNING: System Integrity Protection is disabled" >> "$report_file"
    echo "Recommendation: Enable SIP for improved security. Use Recovery Mode to re-enable." >> "$report_file"
  fi
  echo "" >> "$report_file"
  
  # FileVault
  echo "### Disk Encryption ###" >> "$report_file"
  local filevault_status=$(fdesetup status 2>&1)
  if [[ "$filevault_status" == *"FileVault is On"* ]]; then
    echo "✓ FileVault disk encryption is enabled" >> "$report_file"
  else
    echo "⚠️ WARNING: FileVault disk encryption is not enabled" >> "$report_file"
    echo "Recommendation: Enable FileVault in System Settings > Privacy & Security to protect your data." >> "$report_file"
  fi
  echo "" >> "$report_file"
  
  # Firewall
  echo "### Firewall ###" >> "$report_file"
  local firewall_status=$(defaults read /Library/Preferences/com.apple.alf globalstate 2>/dev/null)
  if [[ "$firewall_status" == "0" || -z "$firewall_status" ]]; then
    echo "⚠️ WARNING: Firewall is disabled" >> "$report_file"
    echo "Recommendation: Enable the firewall in System Settings > Network > Firewall." >> "$report_file"
  else
    echo "✓ Firewall is enabled (Mode: $firewall_status)" >> "$report_file"
  fi
  echo "" >> "$report_file"
  
  # Auto-login
  echo "### Login Security ###" >> "$report_file"
  local auto_login=$(defaults read /Library/Preferences/com.apple.loginwindow autoLoginUser 2>/dev/null)
  if [[ -n "$auto_login" ]]; then
    echo "⚠️ WARNING: Automatic login is enabled for user '$auto_login'" >> "$report_file"
    echo "Recommendation: Disable automatic login in System Settings > Users & Groups." >> "$report_file"
  else
    echo "✓ Automatic login is disabled" >> "$report_file"
  fi
  
  # Password requirements
  local pwpolicy_min_length=$(pwpolicy -getaccountpolicies 2>/dev/null | grep -A1 "policyAttributeMinimumLength" | tail -1 | grep -o ">[0-9]*<" | tr -d '<>')
  if [[ -n "$pwpolicy_min_length" && "$pwpolicy_min_length" -ge 12 ]]; then
    echo "✓ Password minimum length policy is adequate ($pwpolicy_min_length characters)" >> "$report_file"
  else
    echo "⚠️ WARNING: Password policy may not be sufficient" >> "$report_file"
    echo "Recommendation: Set a password policy requiring at least 12 characters." >> "$report_file"
  fi
  echo "" >> "$report_file"
  
  # Gatekeeper
  echo "### Gatekeeper ###" >> "$report_file"
  local gatekeeper_status=$(spctl --status 2>&1)
  if [[ "$gatekeeper_status" == *"enabled"* ]]; then
    echo "✓ Gatekeeper is enabled" >> "$report_file"
  else
    echo "⚠️ WARNING: Gatekeeper is disabled" >> "$report_file"
    echo "Recommendation: Enable Gatekeeper by running 'sudo spctl --master-enable'" >> "$report_file"
  fi
  echo "" >> "$report_file"
  
  # Remote services
  echo "### Remote Services ###" >> "$report_file"
  local remote_login=$(sudo systemsetup -getremotelogin 2>&1 | grep -i "on\|off")
  if [[ "$remote_login" == *"On"* ]]; then
    echo "⚠️ WARNING: Remote Login (SSH) is enabled" >> "$report_file"
    echo "Recommendation: Disable Remote Login in System Settings > Sharing if not needed." >> "$report_file"
  else
    echo "✓ Remote Login (SSH) is disabled" >> "$report_file"
  fi
  
  # Screen Sharing
  if [[ -f "/System/Library/LaunchDaemons/com.apple.screensharing.plist" ]]; then
    local screen_sharing_loaded=$(sudo launchctl list | grep -c "com.apple.screensharing")
    if [[ $screen_sharing_loaded -gt 0 ]]; then
      echo "⚠️ WARNING: Screen Sharing is enabled" >> "$report_file"
      echo "Recommendation: Disable Screen Sharing in System Settings > Sharing if not needed." >> "$report_file"
    else
      echo "✓ Screen Sharing is disabled" >> "$report_file"
    fi
  else
    echo "✓ Screen Sharing is disabled" >> "$report_file"
  fi
  echo "" >> "$report_file"
  
  # Summary and score
  echo "### Security Compliance Score ###" >> "$report_file"
  local total_checks=8
  local passed=0
  
  # Count passing checks
  [[ "$sip_status" == *"enabled"* ]] && ((passed++))
  [[ "$filevault_status" == *"FileVault is On"* ]] && ((passed++))
  [[ "$firewall_status" != "0" && -n "$firewall_status" ]] && ((passed++))
  [[ -z "$auto_login" ]] && ((passed++))
  [[ -n "$pwpolicy_min_length" && "$pwpolicy_min_length" -ge 12 ]] && ((passed++))
  [[ "$gatekeeper_status" == *"enabled"* ]] && ((passed++))
  [[ "$remote_login" != *"On"* ]] && ((passed++))
  [[ $screen_sharing_loaded -eq 0 || ! -f "/System/Library/LaunchDaemons/com.apple.screensharing.plist" ]] && ((passed++))
  
  local score=$((passed * 100 / total_checks))
  
  echo "Security Score: $score% ($passed of $total_checks checks passed)" >> "$report_file"
  echo "" >> "$report_file"
  
  if [[ $score -eq 100 ]]; then
    echo "Excellent! Your system meets all basic security requirements." >> "$report_file"
  elif [[ $score -ge 80 ]]; then
    echo "Good. Your system meets most security requirements, but there's room for improvement." >> "$report_file"
  elif [[ $score -ge 60 ]]; then
    echo "Fair. Your system has some security measures in place, but several important protections are missing." >> "$report_file"
  else
    echo "Poor. Your system fails to meet many basic security requirements and may be at risk." >> "$report_file"
  fi
  echo "" >> "$report_file"
  
  # Final recommendations
  echo "### Additional Security Recommendations ###" >> "$report_file"
  echo "1. Use a password manager to generate and store strong, unique passwords" >> "$report_file"
  echo "2. Enable two-factor authentication for your Apple ID" >> "$report_file"
  echo "3. Regularly review apps with privacy permission access in System Settings" >> "$report_file"
  echo "4. Keep all third-party applications updated" >> "$report_file"
  echo "5. Consider using a VPN when connecting to public Wi-Fi networks" >> "$report_file"
  echo "6. Review your important backups regularly to ensure they're working" >> "$report_file"
  echo "7. Install security updates promptly when available" >> "$report_file"
  echo "" >> "$report_file"
  
  # Display the report
  less "$report_file"
  
  # Offer to save the report
  if confirm "Would you like to save this security compliance report to your Desktop?"; then
    local report_path="$HOME/Desktop/security_compliance_$(date +%Y%m%d_%H%M%S).txt"
    cp "$report_file" "$report_path"
    log "Security compliance report saved to: $report_path"
  fi
  
  # Clean up
  rm "$report_file"
  
  echo
  read -n 1 -s -r -p "Press any key to continue..."
}

# Scan for large and duplicate files
scan_for_large_files() {
  echo -e "\n${BLUE}--- Large and Duplicate Files Scan ---${NC}"
  
  log "This tool helps identify unusually large files and potential duplicates."
  log "Note: The duplicate check is based on file size and name, not content."
  
  # Ask for scan location
  echo "Select location to scan:"
  echo "1. Home directory ($HOME)"
  echo "2. Desktop"
  echo "3. Downloads folder"
  echo "4. Documents folder"
  echo "5. Custom path"
  echo -n "Enter your choice: "
  read -r scan_choice
  
  case "$scan_choice" in
    1) scan_path="$HOME" ;;
    2) scan_path="$HOME/Desktop" ;;
    3) scan_path="$HOME/Downloads" ;;
    4) scan_path="$HOME/Documents" ;;
    5) 
      echo -n "Enter the absolute path to scan: "
      read -r custom_path
      scan_path="$custom_path"
      ;;
    *) 
      log --warn "Invalid choice. Defaulting to home directory."
      scan_path="$HOME"
      ;;
  esac
  
  if [[ ! -d "$scan_path" ]]; then
    log --error "Invalid directory: $scan_path"
    return 1
  fi
  
  # Ask for minimum file size
  echo -n "Enter minimum file size to look for (in MB, default 100): "
  read -r min_size
  min_size=${min_size:-100}
  
  log "Scanning $scan_path for files larger than ${min_size}MB..."
  log "This may take some time for large directories."
  
  # Create temp files for reports
  local large_files=$(mktemp)
  local duplicate_candidates=$(mktemp)
  local report_file=$(mktemp)
  
  echo "Large and Duplicate Files Report" > "$report_file"
  echo "Generated: $(date)" >> "$report_file"
  echo "================================" >> "$report_file"
  echo "Scan location: $scan_path" >> "$report_file"
  echo "Minimum file size: ${min_size}MB" >> "$report_file"
  echo "" >> "$report_file"
  
  # Find large files
  if [[ $DRY_RUN -eq 0 ]]; then
    find "$scan_path" -type f -size +"$min_size"M -print0 2>/dev/null | xargs -0 du -h 2>/dev/null | sort -hr > "$large_files"
  
    echo "### LARGE FILES ###" >> "$report_file"
    if [[ -s "$large_files" ]]; then
      head -20 "$large_files" >> "$report_file"
      local total_large=$(wc -l < "$large_files")
      if [[ $total_large -gt 20 ]]; then
        echo "...and $(($total_large - 20)) more files. Full list will be in saved report." >> "$report_file"
      fi
    else
      echo "No files larger than ${min_size}MB found." >> "$report_file"
    fi
    echo "" >> "$report_file"
    
    # Check for potential duplicates (files with the same size)
    echo "### POTENTIAL DUPLICATES ###" >> "$report_file"
    echo "Note: These are files with identical sizes, not necessarily identical content." >> "$report_file"
    echo "" >> "$report_file"
    
    # Find files with duplicate sizes > 10MB
    find "$scan_path" -type f -size +10M -exec ls -la {} \; 2>/dev/null | 
    awk '{print $5, $9}' | sort -n | 
    awk '{ if (size == $1) { print prev; print $0; duplicates=1 } else { duplicates=0 } size=$1; prev=$0 }' > "$duplicate_candidates"
    
    if [[ -s "$duplicate_candidates" ]]; then
      cat "$duplicate_candidates" >> "$report_file"
    else
      echo "No potential duplicate files found." >> "$report_file"
    fi
    echo "" >> "$report_file"
    
    # File type summary
    echo "### FILE TYPE SUMMARY ###" >> "$report_file"
    echo "File extensions by total size (top 10):" >> "$report_file"
    find "$scan_path" -type f -not -path "*/\.*" 2>/dev/null | 
    grep -v "^$" | 
    perl -ne 'print $1 if m/\.([^.\/]+)$/' | 
    tr '[:upper:]' '[:lower:]' | 
    sort | 
    uniq -c | 
    sort -nr | 
    head -10 | 
    while read -r count ext; do
      echo ".$ext: $count files" >> "$report_file"
    done
    echo "" >> "$report_file"
    
    # Recommendations
    echo "### RECOMMENDATIONS ###" >> "$report_file"
    echo "1. Consider moving large media files to external storage" >> "$report_file"
    echo "2. Check potential duplicates and remove unnecessary copies" >> "$report_file"
    echo "3. Review large installer files (.dmg, .pkg) that can be deleted after use" >> "$report_file"
    echo "4. Archive old documents and projects you no longer actively use" >> "$report_file"
    echo "5. Use cloud storage for large files that you access infrequently" >> "$report_file"
    echo "" >> "$report_file"
  fi
  
  # Display the report
  less "$report_file"
  
  # Offer to save full report
  if confirm "Would you like to save this file analysis report to your Desktop?"; then
    local report_path="$HOME/Desktop/large_files_report_$(date +%Y%m%d_%H%M%S).txt"
    
    # Create a full report with all large files
    cp "$report_file" "$report_path"
    
    # Append all large files if truncated in the displayed report
    if [[ -s "$large_files" ]]; then
      local total_large=$(wc -l < "$large_files")
      if [[ $total_large -gt 20 ]]; then
        echo "" >> "$report_path"
        echo "### COMPLETE LIST OF LARGE FILES ###" >> "$report_path"
        cat "$large_files" >> "$report_path"
      fi
    fi
    
    log "File analysis report saved to: $report_path"
  fi
  
  # Clean up
  rm "$large_files" "$duplicate_candidates" "$report_file"
  
  echo
  read -n 1 -s -r -p "Press any key to continue..."
}

# Generate app usage statistics
app_usage_statistics() {
  echo -e "\n${BLUE}--- Application Usage Statistics ---${NC}"
  
  log "Generating application usage statistics..."
  
  # Create temporary file for report
  local report_file=$(mktemp)
  
  echo "Application Usage Statistics" > "$report_file"
  echo "Generated: $(date)" >> "$report_file"
  echo "===========================" >> "$report_file"
  echo "" >> "$report_file"
  
  # Recently used applications
  echo "### Recently Used Applications ###" >> "$report_file"
  
  # Find recently used applications from Launch Services database
  if [[ -d "$HOME/Library/Application Support/com.apple.sharedfilelist" ]]; then
    echo "Applications used in recent sessions:" >> "$report_file"
    
    # Get recently used apps from RecentApplications.sfl2
    local recent_apps="$HOME/Library/Application Support/com.apple.sharedfilelist/com.apple.LSSharedFileList.RecentApplications.sfl2"
    
    if [[ -f "$recent_apps" && $DRY_RUN -eq 0 ]]; then
      plutil -convert xml1 -o - "$recent_apps" 2>/dev/null | 
      grep -A 2 "Bookmark" | 
      grep -E "file:///Applications|file://$HOME/Applications" | 
      sed -E 's/.*file:\/\/(.*)".*/\1/' | 
      sort | uniq | 
      while read -r app_path; do
        local app_path=$(echo "$app_path" | sed 's/%20/ /g')
        if [[ -d "$app_path" ]]; then
          local app_name=$(basename "$app_path" .app)
          echo "- $app_name" >> "$report_file"
        fi
      done
    else
      echo "Could not access recent applications list." >> "$report_file"
    fi
  else
    echo "Recent applications data not available." >> "$report_file"
  fi
  echo "" >> "$report_file"
  
  # Most active processes
  echo "### Most Active Applications (current) ###" >> "$report_file"
  echo "Top applications by CPU usage:" >> "$report_file"
  ps aux | head -1 >> "$report_file"
  ps aux | grep -v "grep\|ps aux" | sort -nr -k 3 | head -5 >> "$report_file"
  echo "" >> "$report_file"
  
  echo "Top applications by memory usage:" >> "$report_file"
  ps aux | head -1 >> "$report_file"
  ps aux | grep -v "grep\|ps aux" | sort -nr -k 4 | head -5 >> "$report_file"
  echo "" >> "$report_file"
  
  # Application count and categories
  echo "### Application Statistics ###" >> "$report_file"
  
  # Count applications in main Applications folder
  local sys_app_count=$(find /Applications -maxdepth 1 -name "*.app" | wc -l | tr -d ' ')
  echo "System Applications: $sys_app_count" >> "$report_file"
  
  # Count applications in user Applications folder
  if [[ -d "$HOME/Applications" ]]; then
    local user_app_count=$(find "$HOME/Applications" -maxdepth 1 -name "*.app" | wc -l | tr -d ' ')
    echo "User Applications: $user_app_count" >> "$report_file"
  fi
  
  # Total application count
  local total_apps=$((sys_app_count + user_app_count))
  echo "Total Applications: $total_apps" >> "$report_file"
  echo "" >> "$report_file"
  
  # Application ages
  echo "### Application Age Analysis ###" >> "$report_file"
  echo "Oldest applications (by last modified date):" >> "$report_file"
  
  if [[ $DRY_RUN -eq 0 ]]; then
    find /Applications -maxdepth 1 -name "*.app" -type d -exec stat -f "%m %N" {} \; 2>/dev/null | 
    sort -n | head -10 | 
    while read -r mod_time app_path; do
      local app_name=$(basename "$app_path" .app)
      local date_str=$(date -r "$mod_time" "+%Y-%m-%d")
      echo "- $app_name: Last modified $date_str" >> "$report_file"
    done
  fi
  echo "" >> "$report_file"
  
  # Applications never/rarely used
  echo "### Rarely Used Applications ###" >> "$report_file"
  echo "Applications not accessed recently (based on access time):" >> "$report_file"
  
  # Cut-off date (90 days ago)
  local cutoff_date=$(date -v-90d +%s)
  
  if [[ $DRY_RUN -eq 0 ]]; then
    find /Applications -maxdepth 1 -name "*.app" -type d -atime +90 2>/dev/null | 
    while read -r app_path; do
      local app_name=$(basename "$app_path" .app)
      local access_time=$(stat -f "%a" "$app_path")
      local access_date=$(date -r "$access_time" "+%Y-%m-%d")
      echo "- $app_name: Last accessed $access_date" >> "$report_file"
    done
  fi
  echo "" >> "$report_file"
  
  # Application power and resource usage
  if [[ -d "/Library/Application Support/com.apple.PowerManagement" ]]; then
    echo "### Application Power Impact ###" >> "$report_file"
    echo "Applications with high energy impact (if available):" >> "$report_file"
    
    # This requires root to access properly
    if [[ $EUID -eq 0 && $DRY_RUN -eq 0 ]]; then
      if [[ -f "/Library/Application Support/com.apple.PowerManagement/PowerLog.powerlog" ]]; then
        echo "Power impact data available but requires specialized analysis." >> "$report_file"
      else
        echo "Power impact data not available." >> "$report_file"
      fi
    else
      echo "Power impact data requires administrator access." >> "$report_file"
    fi
  fi
  echo "" >> "$report_file"
  
  # App Store vs Non-App Store
  echo "### App Sources ###" >> "$report_file"
  echo "This analysis may help identify applications that were not installed via the App Store." >> "$report_file"
  
  # Count App Store receipts
  local receipt_path="/Library/Application Support/App Store/receipts"
  if [[ -d "$receipt_path" ]]; then
    local receipt_count=$(find "$receipt_path" -name "*.receipt" | wc -l | tr -d ' ')
    echo "App Store Applications: ~$receipt_count" >> "$report_file"
    echo "Non-App Store Applications: ~$((total_apps - receipt_count))" >> "$report_file"
  else
    echo "App Store receipt information not available." >> "$report_file"
  fi
  echo "" >> "$report_file"
  
  # Recommendations
  echo "### Recommendations ###" >> "$report_file"
  echo "1. Consider uninstalling applications you haven't used in more than 90 days" >> "$report_file"
  echo "2. Monitor applications with high CPU or memory usage regularly" >> "$report_file"
  echo "3. Update frequently used applications to their latest versions" >> "$report_file"
  echo "4. For battery-powered devices, be mindful of applications with high energy impact" >> "$report_file"
  echo "5. Review your application portfolio periodically and remove unnecessary software" >> "$report_file"
  echo "" >> "$report_file"
  
  # Display the report
  less "$report_file"
  
  # Offer to save the report
  if confirm "Would you like to save this application usage report to your Desktop?"; then
    local report_path="$HOME/Desktop/app_usage_$(date +%Y%m%d_%H%M%S).txt"
    cp "$report_file" "$report_path"
    log "Application usage report saved to: $report_path"
  fi
  
  # Clean up
  rm "$report_file"
  
  echo
  read -n 1 -s -r -p "Press any key to continue..."
}

# Check for macOS compatibility issues
check_compatibility_issues() {
  echo -e "\n${BLUE}--- macOS Compatibility Check ---${NC}"
  
  log "Checking for software compatibility issues..."
  
  # Create temporary file for report
  local report_file=$(mktemp)
  
  echo "macOS Compatibility Report" > "$report_file"
  echo "Generated: $(date)" >> "$report_file"
  echo "==========================" >> "$report_file"
  echo "" >> "$report_file"
  
  # System information
  echo "### System Information ###" >> "$report_file"
  local os_version=$(sw_vers -productVersion)
  local os_build=$(sw_vers -buildVersion)
  local cpu_type=$(uname -m)
  
  echo "macOS Version: $os_version (Build $os_build)" >> "$report_file"
  echo "CPU Architecture: $cpu_type" >> "$report_file"
  echo "" >> "$report_file"
  
  # Check for Rosetta
  local rosetta_needed=0
  if [[ "$cpu_type" == "arm64" ]]; then
    echo "### Rosetta 2 Status ###" >> "$report_file"
    if [[ -f "/Library/Apple/usr/share/rosetta/rosetta" ]]; then
      echo "✓ Rosetta 2 is installed" >> "$report_file"
    else
      echo "⚠️ Rosetta 2 is not installed" >> "$report_file"
      echo "Recommendation: Install Rosetta 2 if you need to run Intel-based applications." >> "$report_file"
      rosetta_needed=1
    fi
    echo "" >> "$report_file"
  fi
  
  # Check for 32-bit applications (relevant for older macOS versions)
  echo "### Application Architecture ###" >> "$report_file"
  
  if [[ "$os_version" < "10.15" ]]; then
    echo "Checking for 32-bit applications (incompatible with macOS Catalina and later):" >> "$report_file"
    
    if [[ $DRY_RUN -eq 0 ]]; then
      local found_32bit=0
      
      # Check Applications folder
      find /Applications -name "*.app" -maxdepth 2 -type d 2>/dev/null | while read -r app; do
        local is_32bit=$(file "$app/Contents/MacOS/"* 2>/dev/null | grep "i386" | grep -v "x86_64")
        if [[ -n "$is_32bit" ]]; then
          if [[ $found_32bit -eq 0 ]]; then
            echo "The following applications are 32-bit and will not work on macOS Catalina or later:" >> "$report_file"
            found_32bit=1
          fi
          local app_name=$(basename "$app" .app)
          echo "- $app_name" >> "$report_file"
        fi
      done
      
      if [[ $found_32bit -eq 0 ]]; then
        echo "No 32-bit applications found. All applications should be compatible with newer macOS versions." >> "$report_file"
      fi
    fi
  else
    echo "Your system is running macOS Catalina or later, which does not support 32-bit applications." >> "$report_file"
  fi
  echo "" >> "$report_file"
  
  # Check for Intel vs Apple Silicon native apps
  if [[ "$cpu_type" == "arm64" ]]; then
    echo "### Apple Silicon Compatibility ###" >> "$report_file"
    echo "Checking for applications that might be running under Rosetta 2:" >> "$report_file"
    
    if [[ $DRY_RUN -eq 0 ]]; then
      local found_intel=0
      local checked_apps=0
      
      # Check Applications folder (limit to 50 to keep it reasonably fast)
      find /Applications -name "*.app" -maxdepth 2 -type d 2>/dev/null | head -50 | while read -r app; do
        ((checked_apps++))
        local main_binary=$(find "$app/Contents/MacOS" -type f -maxdepth 1 -perm +111 2>/dev/null | head -1)
        
        if [[ -n "$main_binary" ]]; then
          local arch_type=$(file "$main_binary" 2>/dev/null)
          
          if [[ "$arch_type" == *"x86_64"* && "$arch_type" != *"arm64"* ]]; then
            if [[ $found_intel -eq 0 ]]; then
              echo "The following applications are Intel-only and will use Rosetta 2:" >> "$report_file"
              found_intel=1
            fi
            local app_name=$(basename "$app" .app)
            echo "- $app_name" >> "$report_file"
          fi
        fi
      done
      
      if [[ $found_intel -eq 0 ]]; then
        echo "All checked applications ($checked_apps) appear to support Apple Silicon natively." >> "$report_file"
      fi
    fi
    echo "" >> "$report_file"
  fi
  
  # Check for software that might need updates for the current OS
  echo "### Software Update Recommendations ###" >> "$report_file"
  echo "Applications that may need updates for best compatibility:" >> "$report_file"
  
  # Check some commonly problematic applications
  local outdated_apps=()
  
  if [[ -d "/Applications/Adobe Creative Cloud" ]] && [[ "$os_version" > "12.0" ]]; then
    outdated_apps+=("Adobe Creative Cloud: Check for updates to ensure compatibility with macOS $os_version")
  fi
  
  if [[ -d "/Applications/Microsoft Office 2019" ]] && [[ "$os_version" > "12.0" ]]; then
    outdated_apps+=("Microsoft Office 2019: Consider updating to Microsoft 365 for best compatibility")
  fi
  
  if [[ -d "/Applications/Microsoft Office 2016" ]]; then
    outdated_apps+=("Microsoft Office 2016: This version is quite old and may have compatibility issues")
  fi
  
  # Check for older versions of common apps
  if [[ -d "/Applications/Firefox.app" ]]; then
    local firefox_info=$(/Applications/Firefox.app/Contents/MacOS/firefox --version 2>/dev/null)
    if [[ "$firefox_info" == *"Firefox"* ]]; then
      local firefox_version=$(echo "$firefox_info" | awk '{print $3}')
      if [[ $(echo "$firefox_version" | cut -d. -f1) -lt 100 ]]; then
        outdated_apps+=("Firefox ($firefox_version): Consider updating to the latest version")
      fi
    fi
  fi
  
  # Output outdated apps
  if [[ ${#outdated_apps[@]} -gt 0 ]]; then
    for app in "${outdated_apps[@]}"; do
      echo "- $app" >> "$report_file"
    done
  else
    echo "No specific compatibility issues detected with common applications." >> "$report_file"
  fi
  echo "" >> "$report_file"
  
  # Kernel extension and system extension status
  echo "### System Extensions ###" >> "$report_file"
  
  if [[ "$os_version" > "10.15" ]]; then
    echo "Kernel Extensions (kexts) are being phased out in favor of System Extensions." >> "$report_file"
    echo "The following kernel extensions are loaded (may require special approval):" >> "$report_file"
    
    if [[ $DRY_RUN -eq 0 ]]; then
      kextstat | grep -v "com.apple" | head -10 >> "$report_file"
      local kext_count=$(kextstat | grep -v "com.apple" | wc -l | tr -d ' ')
      
      if [[ $kext_count -gt 10 ]]; then
        echo "...and $(($kext_count - 10)) more." >> "$report_file"
      elif [[ $kext_count -eq 0 ]]; then
        echo "No third-party kernel extensions found." >> "$report_file"
      fi
    fi
  fi
  echo "" >> "$report_file"
  
  # Recommendations
  echo "### Compatibility Recommendations ###" >> "$report_file"
  
  # Add standard recommendations
  echo "General recommendations:" >> "$report_file"
  echo "1. Keep your software updated to the latest versions" >> "$report_file"
  echo "2. Check developers' websites for compatibility information before major OS upgrades" >> "$report_file"
  echo "3. Back up your system before major OS upgrades" >> "$report_file"
  echo "4. Subscribe to newsletters or follow social media of critical software vendors for update notifications" >> "$report_file"
  
  # Architecture-specific recommendations
  if [[ "$cpu_type" == "arm64" ]]; then
    echo "5. If you notice performance issues with certain applications, check if they're optimized for Apple Silicon" >> "$report_file"
    if [[ $rosetta_needed -eq 1 ]]; then
      echo "6. Install Rosetta 2 to run Intel-based applications: softwareupdate --install-rosetta --agree-to-license" >> "$report_file"
    fi
  fi
  
  # Version-specific recommendations
  if [[ "$os_version" < "14.0" ]]; then
    echo "7. Consider upgrading to the latest macOS version for security improvements and new features" >> "$report_file"
  fi
  
  echo "" >> "$report_file"
  
  # Display the report
  less "$report_file"
  
  # Offer to save the report
  if confirm "Would you like to save this compatibility report to your Desktop?"; then
    local report_path="$HOME/Desktop/compatibility_report_$(date +%Y%m%d_%H%M%S).txt"
    cp "$report_file" "$report_path"
    log "Compatibility report saved to: $report_path"
  fi
  
  # Install Rosetta if needed and confirmed
  if [[ "$cpu_type" == "arm64" && $rosetta_needed -eq 1 ]]; then
    if confirm "Would you like to install Rosetta 2 for Intel application compatibility?"; then
      if [[ $DRY_RUN -eq 0 ]]; then
        log "Installing Rosetta 2..."
        run_command softwareupdate --install-rosetta --agree-to-license
      else
        log "DRY RUN: Would install Rosetta 2"
      fi
    fi
  fi
  
  # Clean up
  rm "$report_file"
  
  echo
  read -n 1 -s -r -p "Press any key to continue..."
}