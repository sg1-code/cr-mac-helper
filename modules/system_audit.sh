#!/bin/bash

# system_audit.sh - Functions for performing comprehensive system audits and generating reports

# Main system audit function
system_audit() {
  echo -e "\n${BLUE}=== System Audit and Report Generation ===${NC}"
  
  # Create a timestamp for the report
  local timestamp=$(date "+%Y-%m-%d_%H-%M-%S")
  local report_dir="$HOME/Documents/macOS_System_Reports"
  local report_path="$report_dir/system_report_$timestamp"
  local html_report="$report_path.html"
  
  # Create reports directory if it doesn't exist
  mkdir -p "$report_dir"
  
  echo "1. Run comprehensive system audit"
  echo "2. Run quick system audit"
  echo "3. View previous reports"
  echo "4. Return to main menu"
  echo -n "Select an option: "
  read -r audit_choice
  
  case "$audit_choice" in
    1) generate_comprehensive_report "$html_report" ;;
    2) generate_quick_report "$html_report" ;;
    3) view_previous_reports "$report_dir" ;;
    4) return ;;
    *) log --warn "Invalid choice. Returning to main menu."; return ;;
  esac
}

# View previous reports
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

# Function to generate a comprehensive system report
generate_comprehensive_report() {
  local html_report="$1"
  
  echo -e "\n${BLUE}--- Generating Comprehensive System Report ---${NC}"
  log "This will analyze your system and generate a detailed report."
  log "The report will include information about disk usage, apps, hidden folders, and more."
  log "This may take several minutes to complete."
  
  if ! confirm "Continue with comprehensive system audit?"; then
    return
  fi
  
  # Start collecting data
  log "Collecting system information..."
  
  # Create a temporary directory for data collection
  local tmp_dir=$(mktemp -d)
  
  # Run various data collection functions in the background for efficiency
  collect_system_info "$tmp_dir/system_info.json" &
  local pid1=$!
  
  collect_disk_usage "$tmp_dir/disk_usage.json" &
  local pid2=$!
  
  collect_app_info "$tmp_dir/app_info.json" &
  local pid3=$!
  
  collect_hidden_folders "$tmp_dir/hidden_folders.json" &
  local pid4=$!
  
  collect_login_items "$tmp_dir/login_items.json" &
  local pid5=$!
  
  collect_large_files "$tmp_dir/large_files.json" &
  local pid6=$!
  
  collect_network_info "$tmp_dir/network_info.json" &
  local pid7=$!
  
  collect_security_info "$tmp_dir/security_info.json" &
  local pid8=$!
  
  # Show a spinner while collecting data
  echo -n "Collecting data "
  while kill -0 $pid1 2>/dev/null || kill -0 $pid2 2>/dev/null || 
        kill -0 $pid3 2>/dev/null || kill -0 $pid4 2>/dev/null || 
        kill -0 $pid5 2>/dev/null || kill -0 $pid6 2>/dev/null || 
        kill -0 $pid7 2>/dev/null || kill -0 $pid8 2>/dev/null; do
    for s in / - \\ \|; do
      printf "\b%s" "$s"
      sleep 0.1
    done
  done
  printf "\bDone!\n"
  
  # Generate the HTML report
  log "Generating HTML report..."
  generate_html_report "$tmp_dir" "$html_report" "comprehensive"
  
  # Clean up temporary files
  rm -rf "$tmp_dir"
  
  log "Report successfully generated at: $html_report"
  
  if confirm "Would you like to view the report now?"; then
    open "$html_report"
  fi
  
  read -n 1 -s -r -p "Press any key to continue..."
}

# Function to generate a quick system report
generate_quick_report() {
  local html_report="$1"
  
  echo -e "\n${BLUE}--- Generating Quick System Report ---${NC}"
  log "This will perform a quick analysis of your system and generate a basic report."
  log "This should only take a minute or two."
  
  if ! confirm "Continue with quick system audit?"; then
    return
  fi
  
  # Start collecting data
  log "Collecting system information..."
  
  # Create a temporary directory for data collection
  local tmp_dir=$(mktemp -d)
  
  # Collect only the essential data
  collect_system_info "$tmp_dir/system_info.json" &
  local pid1=$!
  
  collect_disk_usage "$tmp_dir/disk_usage.json" &
  local pid2=$!
  
  collect_large_files "$tmp_dir/large_files.json" &
  local pid3=$!
  
  # Show a spinner while collecting data
  echo -n "Collecting data "
  while kill -0 $pid1 2>/dev/null || kill -0 $pid2 2>/dev/null || kill -0 $pid3 2>/dev/null; do
    for s in / - \\ \|; do
      printf "\b%s" "$s"
      sleep 0.1
    done
  done
  printf "\bDone!\n"
  
  # Generate the HTML report
  log "Generating HTML report..."
  generate_html_report "$tmp_dir" "$html_report" "quick"
  
  # Clean up temporary files
  rm -rf "$tmp_dir"
  
  log "Report successfully generated at: $html_report"
  
  if confirm "Would you like to view the report now?"; then
    open "$html_report"
  fi
  
  read -n 1 -s -r -p "Press any key to continue..."
}

# Collect basic system information
collect_system_info() {
  local output_file="$1"
  
  # Create a JSON object with system information
  {
    echo "{"
    echo "  \"hostname\": \"$(hostname)\","
    echo "  \"os_version\": \"$(sw_vers -productVersion)\","
    echo "  \"build_version\": \"$(sw_vers -buildVersion)\","
    echo "  \"kernel_version\": \"$(uname -r)\","
    echo "  \"model\": \"$(system_profiler SPHardwareDataType | grep "Model Name" | sed 's/.*: //')\","
    echo "  \"processor\": \"$(sysctl -n machdep.cpu.brand_string)\","
    echo "  \"cores\": \"$(sysctl -n hw.physicalcpu)\","
    echo "  \"ram\": \"$(( $(sysctl -n hw.memsize) / 1073741824 )) GB\","
    echo "  \"uptime\": \"$(uptime | sed 's/.*up //' | sed 's/,.*//')\","
    echo "  \"last_boot\": \"$(date -r $(sysctl -n kern.boottime | awk -F'[= ,]' '{print $6}'))\""
    echo "}"
  } > "$output_file"
}

# Collect disk usage information
collect_disk_usage() {
  local output_file="$1"
  
  # Get disk usage for the main volume
  local total_disk=$(df -h / | awk 'NR==2 {print $2}')
  local used_disk=$(df -h / | awk 'NR==2 {print $3}')
  local free_disk=$(df -h / | awk 'NR==2 {print $4}')
  local used_percent=$(df -h / | awk 'NR==2 {print $5}' | tr -d '%')
  
  # Get usage by directory
  local tmp_usage_file=$(mktemp)
  sudo du -sh /Applications /Library /System /Users /usr /private/var 2>/dev/null | sort -hr > "$tmp_usage_file"
  
  # Format as JSON
  {
    echo "{"
    echo "  \"total\": \"$total_disk\","
    echo "  \"used\": \"$used_disk\","
    echo "  \"free\": \"$free_disk\","
    echo "  \"used_percent\": $used_percent,"
    echo "  \"directory_usage\": ["
    
    local first=true
    while read -r line; do
      local size=$(echo "$line" | awk '{print $1}')
      local dir=$(echo "$line" | awk '{print $2}')
      
      if $first; then
        first=false
      else
        echo ","
      fi
      
      echo -n "    {\"directory\": \"$dir\", \"size\": \"$size\"}"
    done < "$tmp_usage_file"
    
    echo
    echo "  ]"
    echo "}"
  } > "$output_file"
  
  rm "$tmp_usage_file"
}

# Collect information about installed applications
collect_app_info() {
  local output_file="$1"
  
  # Get list of applications
  local apps_file=$(mktemp)
  find /Applications -maxdepth 2 -name "*.app" | sort > "$apps_file"
  
  # Get sizes of each application
  {
    echo "{"
    echo "  \"total_count\": $(wc -l < "$apps_file"),"
    echo "  \"applications\": ["
    
    local first=true
    while read -r app_path; do
      local app_name=$(basename "$app_path" .app)
      local app_size=$(du -sh "$app_path" 2>/dev/null | awk '{print $1}')
      local app_modified=$(stat -f "%Sm" -t "%Y-%m-%d" "$app_path" 2>/dev/null)
      
      if $first; then
        first=false
      else
        echo ","
      fi
      
      echo -n "    {\"name\": \"$app_name\", \"path\": \"$app_path\", \"size\": \"$app_size\", \"last_modified\": \"$app_modified\"}"
    done < "$apps_file"
    
    echo
    echo "  ]"
    echo "}"
  } > "$output_file"
  
  rm "$apps_file"
}

# Collect information about hidden folders
collect_hidden_folders() {
  local output_file="$1"
  
  # Get list of hidden folders in home directory
  local hidden_folders_file=$(mktemp)
  find "$HOME" -maxdepth 1 -type d -name ".*" ! -name ".Trash" ! -name "." ! -name ".." | sort > "$hidden_folders_file"
  
  # Get sizes and details of each hidden folder
  {
    echo "{"
    echo "  \"total_count\": $(wc -l < "$hidden_folders_file"),"
    echo "  \"hidden_folders\": ["
    
    local first=true
    while read -r folder_path; do
      local folder_name=$(basename "$folder_path")
      local folder_size=$(du -sh "$folder_path" 2>/dev/null | awk '{print $1}')
      local folder_modified=$(stat -f "%Sm" -t "%Y-%m-%d" "$folder_path" 2>/dev/null)
      
      # Determine if the folder is potentially unused
      local is_used=1
      local description=""
      
      case "$folder_name" in
        .npm | .node_repl_history | .node_modules)
          command -v node >/dev/null 2>&1 || is_used=0
          description="Node.js and npm package manager files"
          ;;
        .nvm)
          command -v nvm >/dev/null 2>&1 || is_used=0
          description="Node Version Manager"
          ;;
        .yarn)
          command -v yarn >/dev/null 2>&1 || is_used=0
          description="Yarn package manager"
          ;;
        .expo)
          command -v expo >/dev/null 2>&1 || is_used=0
          description="Expo CLI for React Native development"
          ;;
        .cargo | .rustup)
          command -v rustc >/dev/null 2>&1 || is_used=0
          description="Rust programming language and Cargo package manager"
          ;;
        *)
          description="Other configuration or data folder"
          ;;
      esac
      
      if $first; then
        first=false
      else
        echo ","
      fi
      
      echo -n "    {\"name\": \"$folder_name\", \"path\": \"$folder_path\", \"size\": \"$folder_size\", \"last_modified\": \"$folder_modified\", \"is_used\": $is_used, \"description\": \"$description\"}"
    done < "$hidden_folders_file"
    
    echo
    echo "  ]"
    echo "}"
  } > "$output_file"
  
  rm "$hidden_folders_file"
}

# Collect information about login items
collect_login_items() {
  local output_file="$1"
  
  # Get login items using osascript
  local login_items=$(osascript -e 'tell application "System Events" to get the name of every login item')
  
  # Format as JSON
  {
    echo "{"
    echo "  \"login_items\": ["
    
    local first=true
    while IFS= read -r item; do
      if [[ -n "$item" ]]; then
        if $first; then
          first=false
        else
          echo ","
        fi
        
        echo -n "    {\"name\": \"$item\"}"
      fi
    done <<< "$login_items"
    
    echo
    echo "  ]"
    echo "}"
  } > "$output_file"
}

# Collect information about large files
collect_large_files() {
  local output_file="$1"
  
  # Find large files (>100MB) in the user's home directory
  local large_files_file=$(mktemp)
  find "$HOME" -type f -size +100M -not -path "*/Library/*" -not -path "*/.*/*" 2>/dev/null | sort > "$large_files_file"
  
  # Format as JSON
  {
    echo "{"
    echo "  \"total_count\": $(wc -l < "$large_files_file"),"
    echo "  \"large_files\": ["
    
    local first=true
    while read -r file_path; do
      if [[ -n "$file_path" ]]; then
        local file_name=$(basename "$file_path")
        local file_size=$(du -sh "$file_path" 2>/dev/null | awk '{print $1}')
        local file_type=$(file -b "$file_path" | tr -d '"' | tr -d '\')
        
        if $first; then
          first=false
        else
          echo ","
        fi
        
        echo -n "    {\"name\": \"$file_name\", \"path\": \"$file_path\", \"size\": \"$file_size\", \"type\": \"$file_type\"}"
      fi
    done < "$large_files_file"
    
    echo
    echo "  ]"
    echo "}"
  } > "$output_file"
  
  rm "$large_files_file"
}

# Collect network information
collect_network_info() {
  local output_file="$1"
  
  # Get network interfaces
  local interfaces=$(ifconfig -l)
  
  # Get current IP addresses
  local ip_info=$(ifconfig | grep "inet " | grep -v 127.0.0.1)
  
  # Get DNS servers
  local dns_servers=$(cat /etc/resolv.conf 2>/dev/null | grep nameserver | awk '{print $2}')
  
  # Format as JSON
  {
    echo "{"
    echo "  \"interfaces\": \"$interfaces\","
    echo "  \"ip_addresses\": ["
    
    local first=true
    while read -r line; do
      if [[ -n "$line" ]]; then
        local ip=$(echo "$line" | awk '{print $2}')
        local interface=$(echo "$line" | awk -F: '{print $1}')
        
        if $first; then
          first=false
        else
          echo ","
        fi
        
        echo -n "    {\"interface\": \"$interface\", \"ip\": \"$ip\"}"
      fi
    done <<< "$ip_info"
    
    echo
    echo "  ],"
    echo "  \"dns_servers\": ["
    
    first=true
    while read -r dns; do
      if [[ -n "$dns" ]]; then
        if $first; then
          first=false
        else
          echo ","
        fi
        
        echo -n "    \"$dns\""
      fi
    done <<< "$dns_servers"
    
    echo
    echo "  ]"
    echo "}"
  } > "$output_file"
}

# Collect security information
collect_security_info() {
  local output_file="$1"
  
  # Check firewall status
  local firewall_status=$(defaults read /Library/Preferences/com.apple.alf globalstate 2>/dev/null || echo "Unknown")
  
  # Check if SIP is enabled
  local sip_status=$(csrutil status | grep -o 'enabled\|disabled')
  
  # Check FileVault status
  local filevault_status=$(fdesetup status 2>/dev/null | grep -o 'On\|Off' || echo "Unknown")
  
  # Format as JSON
  {
    echo "{"
    echo "  \"firewall\": \"$firewall_status\","
    echo "  \"sip\": \"$sip_status\","
    echo "  \"filevault\": \"$filevault_status\""
    echo "}"
  } > "$output_file"
}

# Generate HTML report
generate_html_report() {
  local data_dir="$1"
  local output_file="$2"
  local report_type="$3"
  
  # Load data files
  local system_info=""
  local disk_usage=""
  local app_info=""
  local hidden_folders=""
  local login_items=""
  local large_files=""
  local network_info=""
  local security_info=""
  
  if [[ -f "$data_dir/system_info.json" ]]; then
    system_info=$(cat "$data_dir/system_info.json")
  fi
  
  if [[ -f "$data_dir/disk_usage.json" ]]; then
    disk_usage=$(cat "$data_dir/disk_usage.json")
  fi
  
  if [[ -f "$data_dir/app_info.json" ]]; then
    app_info=$(cat "$data_dir/app_info.json")
  fi
  
  if [[ -f "$data_dir/hidden_folders.json" ]]; then
    hidden_folders=$(cat "$data_dir/hidden_folders.json")
  fi
  
  if [[ -f "$data_dir/login_items.json" ]]; then
    login_items=$(cat "$data_dir/login_items.json")
  fi
  
  if [[ -f "$data_dir/large_files.json" ]]; then
    large_files=$(cat "$data_dir/large_files.json")
  fi
  
  if [[ -f "$data_dir/network_info.json" ]]; then
    network_info=$(cat "$data_dir/network_info.json")
  fi
  
  if [[ -f "$data_dir/security_info.json" ]]; then
    security_info=$(cat "$data_dir/security_info.json")
  fi
  
  # Create HTML report
  cat > "$output_file" << EOF
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>macOS System Report</title>
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      line-height: 1.6;
      color: #333;
      max-width: 1200px;
      margin: 0 auto;
      padding: 20px;
      background-color: #f9f9f9;
    }
    h1, h2, h3 {
      color: #0066cc;
    }
    .header {
      text-align: center;
      margin-bottom: 30px;
      padding-bottom: 20px;
      border-bottom: 1px solid #ddd;
    }
    .container {
      background-color: white;
      padding: 20px;
      border-radius: 8px;
      box-shadow: 0 2px 4px rgba(0,0,0,0.1);
      margin-bottom: 20px;
    }
    .row {
      display: flex;
      flex-wrap: wrap;
      margin: 0 -10px;
    }
    .col {
      flex: 1;
      padding: 0 10px;
      min-width: 300px;
    }
    .data-item {
      margin-bottom: 10px;
    }
    .data-item span {
      font-weight: bold;
    }
    table {
      width: 100%;
      border-collapse: collapse;
      margin: 20px 0;
    }
    th, td {
      padding: 12px;
      text-align: left;
      border-bottom: 1px solid #ddd;
    }
    th {
      background-color: #f2f2f2;
    }
    tr:hover {
      background-color: #f5f5f5;
    }
    .chart-container {
      height: 300px;
      margin: 20px 0;
    }
    .footer {
      text-align: center;
      margin-top: 30px;
      font-size: 0.8em;
      color: #666;
    }
    .warning {
      color: #e74c3c;
    }
    .success {
      color: #2ecc71;
    }
    .info {
      color: #3498db;
    }
  </style>
  <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
</head>
<body>
  <div class="header">
    <h1>macOS System Report</h1>
    <p>Generated on $(date "+%Y-%m-%d at %H:%M:%S")</p>
  </div>
  
  <div class="container">
    <h2>System Information</h2>
    <div class="row">
      <div class="col">
        <div class="data-item"><span>Hostname:</span> <span id="hostname"></span></div>
        <div class="data-item"><span>OS Version:</span> <span id="os_version"></span></div>
        <div class="data-item"><span>Build Version:</span> <span id="build_version"></span></div>
        <div class="data-item"><span>Model:</span> <span id="model"></span></div>
      </div>
      <div class="col">
        <div class="data-item"><span>Processor:</span> <span id="processor"></span></div>
        <div class="data-item"><span>CPU Cores:</span> <span id="cores"></span></div>
        <div class="data-item"><span>RAM:</span> <span id="ram"></span></div>
        <div class="data-item"><span>Uptime:</span> <span id="uptime"></span></div>
      </div>
    </div>
  </div>
  
  <div class="container">
    <h2>Disk Space Usage</h2>
    <div class="row">
      <div class="col">
        <div class="data-item"><span>Total Disk Space:</span> <span id="total_disk"></span></div>
        <div class="data-item"><span>Used Disk Space:</span> <span id="used_disk"></span></div>
        <div class="data-item"><span>Free Disk Space:</span> <span id="free_disk"></span></div>
      </div>
      <div class="col">
        <div class="chart-container">
          <canvas id="diskUsageChart"></canvas>
        </div>
      </div>
    </div>
    
    <h3>Directory Usage</h3>
    <div class="chart-container">
      <canvas id="directoryUsageChart"></canvas>
    </div>
    <div id="directory_usage_table"></div>
  </div>
  
  <div id="large_files_container" class="container" style="display: none;">
    <h2>Large Files (>100MB)</h2>
    <div id="large_files_table"></div>
  </div>
  
  <div id="apps_container" class="container" style="display: none;">
    <h2>Installed Applications</h2>
    <div class="data-item"><span>Total Applications:</span> <span id="total_apps"></span></div>
    <div class="chart-container">
      <canvas id="topAppsChart"></canvas>
    </div>
    <div id="apps_table"></div>
  </div>
  
  <div id="hidden_folders_container" class="container" style="display: none;">
    <h2>Hidden Folders</h2>
    <div class="data-item"><span>Total Hidden Folders:</span> <span id="total_hidden_folders"></span></div>
    <div class="data-item"><span>Potentially Unused:</span> <span id="unused_hidden_folders"></span></div>
    <div class="chart-container">
      <canvas id="hiddenFoldersChart"></canvas>
    </div>
    <div id="hidden_folders_table"></div>
  </div>
  
  <div id="login_items_container" class="container" style="display: none;">
    <h2>Login Items</h2>
    <div id="login_items_list"></div>
  </div>
  
  <div id="network_container" class="container" style="display: none;">
    <h2>Network Configuration</h2>
    <div class="row">
      <div class="col">
        <h3>IP Addresses</h3>
        <div id="ip_addresses_list"></div>
      </div>
      <div class="col">
        <h3>DNS Servers</h3>
        <div id="dns_servers_list"></div>
      </div>
    </div>
  </div>
  
  <div id="security_container" class="container" style="display: none;">
    <h2>Security Status</h2>
    <div class="row">
      <div class="col">
        <div class="data-item"><span>Firewall:</span> <span id="firewall_status"></span></div>
        <div class="data-item"><span>System Integrity Protection:</span> <span id="sip_status"></span></div>
        <div class="data-item"><span>FileVault Encryption:</span> <span id="filevault_status"></span></div>
      </div>
      <div class="col">
        <div class="chart-container">
          <canvas id="securityChart"></canvas>
        </div>
      </div>
    </div>
  </div>
  
  <div class="container">
    <h2>System Health Summary</h2>
    <div id="system_health"></div>
  </div>
  
  <div class="footer">
    <p>Generated by CR - Mac Helper</p>
    <p>Report data is valid as of the generation time. System data may have changed since then.</p>
  </div>
  
  <script>
    // Load JSON data
    const systemInfo = ${system_info:-'{}'};
    const diskUsage = ${disk_usage:-'{}'};
    const appInfo = ${app_info:-'{}'};
    const hiddenFolders = ${hidden_folders:-'{}'};
    const loginItems = ${login_items:-'{}'};
    const largeFiles = ${large_files:-'{}'};
    const networkInfo = ${network_info:-'{}'};
    const securityInfo = ${security_info:-'{}'};
    
    // Populate system information
    document.getElementById('hostname').textContent = systemInfo.hostname || 'N/A';
    document.getElementById('os_version').textContent = systemInfo.os_version || 'N/A';
    document.getElementById('build_version').textContent = systemInfo.build_version || 'N/A';
    document.getElementById('model').textContent = systemInfo.model || 'N/A';
    document.getElementById('processor').textContent = systemInfo.processor || 'N/A';
    document.getElementById('cores').textContent = systemInfo.cores || 'N/A';
    document.getElementById('ram').textContent = systemInfo.ram || 'N/A';
    document.getElementById('uptime').textContent = systemInfo.uptime || 'N/A';
    
    // Populate disk usage information
    if (diskUsage.total) {
      document.getElementById('total_disk').textContent = diskUsage.total;
      document.getElementById('used_disk').textContent = diskUsage.used;
      document.getElementById('free_disk').textContent = diskUsage.free;
      
      // Create disk usage chart
      const diskUsageCtx = document.getElementById('diskUsageChart').getContext('2d');
      new Chart(diskUsageCtx, {
        type: 'doughnut',
        data: {
          labels: ['Used Space', 'Free Space'],
          datasets: [{
            data: [diskUsage.used_percent, 100 - diskUsage.used_percent],
            backgroundColor: ['#3498db', '#2ecc71'],
            borderWidth: 0
          }]
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          plugins: {
            title: {
              display: true,
              text: 'Disk Usage'
            },
            legend: {
              position: 'bottom'
            }
          }
        }
      });
      
      // Create directory usage chart if available
      if (diskUsage.directory_usage && diskUsage.directory_usage.length > 0) {
        const directoryData = diskUsage.directory_usage.slice(0, 6); // Top 6 directories
        
        const directoryCtx = document.getElementById('directoryUsageChart').getContext('2d');
        new Chart(directoryCtx, {
          type: 'bar',
          data: {
            labels: directoryData.map(item => item.directory),
            datasets: [{
              label: 'Size',
              data: directoryData.map(item => parseFloat(item.size)),
              backgroundColor: '#3498db'
            }]
          },
          options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
              title: {
                display: true,
                text: 'Top Directory Usage'
              },
              legend: {
                display: false
              }
            },
            scales: {
              y: {
                beginAtZero: true,
                title: {
                  display: true,
                  text: 'Size (GB)'
                }
              }
            }
          }
        });
        
        // Create directory usage table
        let directoryTable = '<table><thead><tr><th>Directory</th><th>Size</th></tr></thead><tbody>';
        diskUsage.directory_usage.forEach(item => {
          directoryTable += \`<tr><td>\${item.directory}</td><td>\${item.size}</td></tr>\`;
        });
        directoryTable += '</tbody></table>';
        document.getElementById('directory_usage_table').innerHTML = directoryTable;
      }
    }
    
    // Populate large files information
    if (largeFiles.large_files && largeFiles.large_files.length > 0) {
      document.getElementById('large_files_container').style.display = 'block';
      
      let largeFilesTable = '<table><thead><tr><th>Name</th><th>Path</th><th>Size</th><th>Type</th></tr></thead><tbody>';
      largeFiles.large_files.forEach(file => {
        largeFilesTable += \`<tr><td>\${file.name}</td><td>\${file.path}</td><td>\${file.size}</td><td>\${file.type}</td></tr>\`;
      });
      largeFilesTable += '</tbody></table>';
      document.getElementById('large_files_table').innerHTML = largeFilesTable;
    }
    
    // Populate application information
    if (appInfo.applications && appInfo.applications.length > 0) {
      document.getElementById('apps_container').style.display = 'block';
      document.getElementById('total_apps').textContent = appInfo.total_count || 'N/A';
      
      // Sort applications by size (largest first) and take top 10
      const topApps = [...appInfo.applications]
        .sort((a, b) => {
          const sizeA = parseFloat(a.size) || 0;
          const sizeB = parseFloat(b.size) || 0;
          return sizeB - sizeA;
        })
        .slice(0, 10);
      
      // Create top apps chart
      const topAppsCtx = document.getElementById('topAppsChart').getContext('2d');
      new Chart(topAppsCtx, {
        type: 'bar',
        data: {
          labels: topApps.map(app => app.name),
          datasets: [{
            label: 'Size',
            data: topApps.map(app => parseFloat(app.size) || 0),
            backgroundColor: '#3498db'
          }]
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          plugins: {
            title: {
              display: true,
              text: 'Top 10 Largest Applications'
            },
            legend: {
              display: false
            }
          },
          scales: {
            y: {
              beginAtZero: true,
              title: {
                display: true,
                text: 'Size (GB)'
              }
            }
          }
        }
      });
      
      // Create applications table
      let appsTable = '<table><thead><tr><th>Name</th><th>Size</th><th>Last Modified</th></tr></thead><tbody>';
      appInfo.applications.slice(0, 30).forEach(app => {
        appsTable += \`<tr><td>\${app.name}</td><td>\${app.size}</td><td>\${app.last_modified}</td></tr>\`;
      });
      appsTable += '</tbody></table>';
      document.getElementById('apps_table').innerHTML = appsTable;
    }
    
    // Populate hidden folders information
    if (hiddenFolders.hidden_folders && hiddenFolders.hidden_folders.length > 0) {
      document.getElementById('hidden_folders_container').style.display = 'block';
      
      const unusedFolders = hiddenFolders.hidden_folders.filter(folder => folder.is_used === 0);
      
      document.getElementById('total_hidden_folders').textContent = hiddenFolders.total_count || 'N/A';
      document.getElementById('unused_hidden_folders').textContent = unusedFolders.length || '0';
      
      // Sort folders by size (largest first) and take top 10
      const topFolders = [...hiddenFolders.hidden_folders]
        .sort((a, b) => {
          const sizeA = parseFloat(a.size) || 0;
          const sizeB = parseFloat(b.size) || 0;
          return sizeB - sizeA;
        })
        .slice(0, 10);
      
      // Create hidden folders chart
      const hiddenFoldersCtx = document.getElementById('hiddenFoldersChart').getContext('2d');
      new Chart(hiddenFoldersCtx, {
        type: 'bar',
        data: {
          labels: topFolders.map(folder => folder.name),
          datasets: [{
            label: 'Size',
            data: topFolders.map(folder => parseFloat(folder.size) || 0),
            backgroundColor: topFolders.map(folder => folder.is_used ? '#3498db' : '#e74c3c')
          }]
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          plugins: {
            title: {
              display: true,
              text: 'Top 10 Largest Hidden Folders'
            },
            legend: {
              display: false
            }
          },
          scales: {
            y: {
              beginAtZero: true,
              title: {
                display: true,
                text: 'Size (GB)'
              }
            }
          }
        }
      });
      
      // Create hidden folders table
      let foldersTable = '<table><thead><tr><th>Name</th><th>Size</th><th>Status</th><th>Description</th></tr></thead><tbody>';
      hiddenFolders.hidden_folders.forEach(folder => {
        const status = folder.is_used ? '<span class="success">In Use</span>' : '<span class="warning">Potentially Unused</span>';
        foldersTable += \`<tr><td>\${folder.name}</td><td>\${folder.size}</td><td>\${status}</td><td>\${folder.description}</td></tr>\`;
      });
      foldersTable += '</tbody></table>';
      document.getElementById('hidden_folders_table').innerHTML = foldersTable;
    }
    
    // Populate login items information
    if (loginItems.login_items && loginItems.login_items.length > 0) {
      document.getElementById('login_items_container').style.display = 'block';
      
      let loginItemsList = '<ul>';
      loginItems.login_items.forEach(item => {
        loginItemsList += \`<li>\${item.name}</li>\`;
      });
      loginItemsList += '</ul>';
      document.getElementById('login_items_list').innerHTML = loginItemsList;
    }
    
    // Populate network information
    if (networkInfo.ip_addresses || networkInfo.dns_servers) {
      document.getElementById('network_container').style.display = 'block';
      
      if (networkInfo.ip_addresses && networkInfo.ip_addresses.length > 0) {
        let ipList = '<ul>';
        networkInfo.ip_addresses.forEach(ip => {
          ipList += \`<li>\${ip.interface}: \${ip.ip}</li>\`;
        });
        ipList += '</ul>';
        document.getElementById('ip_addresses_list').innerHTML = ipList;
      }
      
      if (networkInfo.dns_servers && networkInfo.dns_servers.length > 0) {
        let dnsList = '<ul>';
        networkInfo.dns_servers.forEach(dns => {
          dnsList += \`<li>\${dns}</li>\`;
        });
        dnsList += '</ul>';
        document.getElementById('dns_servers_list').innerHTML = dnsList;
      }
    }
    
    // Populate security information
    if (securityInfo.firewall || securityInfo.sip || securityInfo.filevault) {
      document.getElementById('security_container').style.display = 'block';
      
      const firewallStatus = securityInfo.firewall === '1' || securityInfo.firewall === '2' ? 
        '<span class="success">Enabled</span>' : '<span class="warning">Disabled</span>';
      
      const sipStatus = securityInfo.sip === 'enabled' ? 
        '<span class="success">Enabled</span>' : '<span class="warning">Disabled</span>';
      
      const filevaultStatus = securityInfo.filevault && securityInfo.filevault.includes('On') ? 
        '<span class="success">Enabled</span>' : '<span class="warning">Disabled</span>';
      
      document.getElementById('firewall_status').innerHTML = firewallStatus;
      document.getElementById('sip_status').innerHTML = sipStatus;
      document.getElementById('filevault_status').innerHTML = filevaultStatus;
      
      // Create security chart
      const securityCtx = document.getElementById('securityChart').getContext('2d');
          
      const firewallValue = securityInfo.firewall === '1' || securityInfo.firewall === '2' ? 1 : 0;
      const sipValue = securityInfo.sip === 'enabled' ? 1 : 0;
      const filevaultValue = securityInfo.filevault && securityInfo.filevault.includes('On') ? 1 : 0;
      
      new Chart(securityCtx, {
        type: 'radar',
        data: {
          labels: ['Firewall', 'System Integrity Protection', 'FileVault Encryption'],
          datasets: [{
            label: 'Security Status',
            data: [firewallValue, sipValue, filevaultValue],
            backgroundColor: 'rgba(52, 152, 219, 0.2)',
            borderColor: 'rgba(52, 152, 219, 1)',
            pointBackgroundColor: 'rgba(52, 152, 219, 1)',
            pointBorderColor: '#fff',
            pointHoverBackgroundColor: '#fff',
            pointHoverBorderColor: 'rgba(52, 152, 219, 1)'
          }]
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          scales: {
            r: {
              angleLines: {
                display: true
              },
              suggestedMin: 0,
              suggestedMax: 1
            }
          }
        }
      });
    }
    
    // Generate system health summary
    const healthSummary = [];
    
    // Disk space check
    if (diskUsage.used_percent) {
      if (diskUsage.used_percent > 90) {
        healthSummary.push('<div class="data-item warning"><span>Warning:</span> Disk space is critically low. Consider cleaning up unused files.</div>');
      } else if (diskUsage.used_percent > 75) {
        healthSummary.push('<div class="data-item info"><span>Notice:</span> Disk space is getting low. Consider freeing up some space soon.</div>');
      } else {
        healthSummary.push('<div class="data-item success"><span>Good:</span> Disk space usage is at a healthy level.</div>');
      }
    }
    
    // Large files check
    if (largeFiles.large_files && largeFiles.large_files.length > 10) {
      healthSummary.push(\`<div class="data-item info"><span>Notice:</span> Found \${largeFiles.large_files.length} large files (>100MB) that could be archived or removed.</div>\`);
    }
    
    // Hidden folders check
    if (hiddenFolders.hidden_folders) {
      const unusedFolders = hiddenFolders.hidden_folders.filter(folder => folder.is_used === 0);
      if (unusedFolders.length > 0) {
        healthSummary.push(\`<div class="data-item info"><span>Notice:</span> Found \${unusedFolders.length} potentially unused hidden folders that could be cleaned up.</div>\`);
      }
    }
    
    // Security checks
    if (securityInfo.firewall && securityInfo.firewall !== '1' && securityInfo.firewall !== '2') {
      healthSummary.push('<div class="data-item warning"><span>Warning:</span> Firewall is disabled. Consider enabling it for better security.</div>');
    }
    
    if (securityInfo.sip && securityInfo.sip !== 'enabled') {
      healthSummary.push('<div class="data-item warning"><span>Warning:</span> System Integrity Protection is disabled. This reduces system security.</div>');
    }
    
    if (securityInfo.filevault && !securityInfo.filevault.includes('On')) {
      healthSummary.push('<div class="data-item info"><span>Notice:</span> FileVault disk encryption is not enabled. Consider enabling it for sensitive data.</div>');
    }
    
    // Display health summary
    if (healthSummary.length === 0) {
      document.getElementById('system_health').innerHTML = '<div class="data-item success"><span>Great:</span> No significant issues found with your system.</div>';
    } else {
      document.getElementById('system_health').innerHTML = healthSummary.join('');
    }
  </script>
</body>
</html>
EOF
} 