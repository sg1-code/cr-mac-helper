#!/bin/bash

# cloud_storage_management.sh - Cloud storage service management and optimization

# Main cloud storage management function
cloud_storage_management() {
  echo -e "\n${BLUE}=== Cloud Storage Management ===${NC}"
  check_privileges 0  # Does not require root
  
  echo "1. Detect cloud service clients"
  echo "2. Manage iCloud storage"
  echo "3. Manage Dropbox"
  echo "4. Manage Google Drive"
  echo "5. Manage OneDrive"
  echo "6. Manage cloud storage preferences"
  echo "7. Return to main menu"
  echo -n "Select an option: "
  read -r cloud_choice
  
  case "$cloud_choice" in
    1) detect_cloud_clients ;;
    2) manage_icloud ;;
    3) manage_dropbox ;;
    4) manage_google_drive ;;
    5) manage_onedrive ;;
    6) manage_cloud_preferences ;;
    7) return ;;
    *) log --warn "Invalid choice. Returning to main menu."; return ;;
  esac
}

# Detect installed cloud service clients
detect_cloud_clients() {
  echo -e "\n${BLUE}--- Detecting Cloud Storage Clients ---${NC}"
  
  log "Scanning for installed cloud storage services..."
  
  # Create temporary file for report
  local report_file=$(mktemp)
  echo "Cloud Storage Services Report" > "$report_file"
  echo "Generated: $(date)" >> "$report_file"
  echo "===========================" >> "$report_file"
  echo "" >> "$report_file"
  
  # Check for each cloud service
  # iCloud
  echo "### iCloud Status ###" >> "$report_file"
  if [[ -d "$HOME/Library/Mobile Documents/com~apple~CloudDocs" ]]; then
    echo "iCloud Drive is configured" >> "$report_file"
    local icloud_size=$(du -sh "$HOME/Library/Mobile Documents/com~apple~CloudDocs" 2>/dev/null | cut -f1)
    echo "Local iCloud Drive size: $icloud_size" >> "$report_file"
    
    # Check if Desktop & Documents syncing is enabled
    if [[ -d "$HOME/Library/Mobile Documents/com~apple~CloudDocs/Desktop" || -d "$HOME/Library/Mobile Documents/com~apple~CloudDocs/Documents" ]]; then
      echo "Desktop & Documents folder syncing: Enabled" >> "$report_file"
    else
      echo "Desktop & Documents folder syncing: Disabled" >> "$report_file"
    fi
  else
    echo "iCloud Drive does not appear to be configured" >> "$report_file"
  fi
  echo "" >> "$report_file"
  
  # Dropbox
  echo "### Dropbox Status ###" >> "$report_file"
  if [[ -d "/Applications/Dropbox.app" ]]; then
    echo "Dropbox is installed" >> "$report_file"
    
    # Check if Dropbox folder exists
    local dropbox_path=""
    if [[ -f "$HOME/.dropbox/info.json" ]]; then
      dropbox_path=$(grep -oE '"path": "[^"]+"' "$HOME/.dropbox/info.json" | cut -d'"' -f4)
    fi
    
    if [[ -n "$dropbox_path" && -d "$dropbox_path" ]]; then
      echo "Dropbox folder: $dropbox_path" >> "$report_file"
      local dropbox_size=$(du -sh "$dropbox_path" 2>/dev/null | cut -f1)
      echo "Local Dropbox size: $dropbox_size" >> "$report_file"
    else
      # Try to find Dropbox folder by common locations
      if [[ -d "$HOME/Dropbox" ]]; then
        echo "Dropbox folder: $HOME/Dropbox" >> "$report_file"
        local dropbox_size=$(du -sh "$HOME/Dropbox" 2>/dev/null | cut -f1)
        echo "Local Dropbox size: $dropbox_size" >> "$report_file"
      else
        echo "Dropbox folder not found or not configured" >> "$report_file"
      fi
    fi
  else
    echo "Dropbox is not installed" >> "$report_file"
  fi
  echo "" >> "$report_file"
  
  # Google Drive
  echo "### Google Drive Status ###" >> "$report_file"
  if [[ -d "/Applications/Google Drive.app" || -d "/Applications/Google Drive File Stream.app" || -d "/Applications/Drive File Stream.app" ]]; then
    echo "Google Drive is installed" >> "$report_file"
    
    # Check for different versions of Google Drive
    if [[ -d "/Applications/Google Drive.app" ]]; then
      echo "Google Drive (Backup and Sync) is installed" >> "$report_file"
    fi
    
    if [[ -d "/Applications/Google Drive File Stream.app" || -d "/Applications/Drive File Stream.app" ]]; then
      echo "Google Drive File Stream is installed" >> "$report_file"
    fi
    
    # Try to find Google Drive folder
    if [[ -d "$HOME/Google Drive" ]]; then
      echo "Google Drive folder: $HOME/Google Drive" >> "$report_file"
      local gdrive_size=$(du -sh "$HOME/Google Drive" 2>/dev/null | cut -f1)
      echo "Local Google Drive size: $gdrive_size" >> "$report_file"
    elif [[ -d "/Volumes/GoogleDrive" ]]; then
      echo "Google Drive File Stream mounted at: /Volumes/GoogleDrive" >> "$report_file"
    elif [[ -d "$HOME/Library/CloudStorage/GoogleDrive-"* ]]; then
      local gdrive_path=$(find "$HOME/Library/CloudStorage" -name "GoogleDrive-*" -type d | head -1)
      echo "Google Drive folder: $gdrive_path" >> "$report_file"
      local gdrive_size=$(du -sh "$gdrive_path" 2>/dev/null | cut -f1)
      echo "Local Google Drive size: $gdrive_size" >> "$report_file"
    else
      echo "Google Drive folder not found or not configured" >> "$report_file"
    fi
  else
    echo "Google Drive is not installed" >> "$report_file"
  fi
  echo "" >> "$report_file"
  
  # OneDrive
  echo "### OneDrive Status ###" >> "$report_file"
  if [[ -d "/Applications/OneDrive.app" ]]; then
    echo "OneDrive is installed" >> "$report_file"
    
    # Try to find OneDrive folder
    if [[ -d "$HOME/OneDrive" ]]; then
      echo "OneDrive folder: $HOME/OneDrive" >> "$report_file"
      local onedrive_size=$(du -sh "$HOME/OneDrive" 2>/dev/null | cut -f1)
      echo "Local OneDrive size: $onedrive_size" >> "$report_file"
    elif [[ -d "$HOME/Library/CloudStorage/OneDrive-"* ]]; then
      local onedrive_path=$(find "$HOME/Library/CloudStorage" -name "OneDrive-*" -type d | head -1)
      echo "OneDrive folder: $onedrive_path" >> "$report_file"
      local onedrive_size=$(du -sh "$onedrive_path" 2>/dev/null | cut -f1)
      echo "Local OneDrive size: $onedrive_size" >> "$report_file"
    else
      echo "OneDrive folder not found or not configured" >> "$report_file"
    fi
  else
    echo "OneDrive is not installed" >> "$report_file"
  fi
  echo "" >> "$report_file"
  
  # Box
  echo "### Box Status ###" >> "$report_file"
  if [[ -d "/Applications/Box.app" ]]; then
    echo "Box is installed" >> "$report_file"
    
    # Try to find Box folder
    if [[ -d "$HOME/Box" || -d "$HOME/Box Sync" ]]; then
      local box_path=$(find "$HOME" -maxdepth 1 -name "Box*" -type d | head -1)
      echo "Box folder: $box_path" >> "$report_file"
      local box_size=$(du -sh "$box_path" 2>/dev/null | cut -f1)
      echo "Local Box size: $box_size" >> "$report_file"
    else
      echo "Box folder not found or not configured" >> "$report_file"
    fi
  else
    echo "Box is not installed" >> "$report_file"
  fi
  echo "" >> "$report_file"
  
  # Total Cloud Storage Usage
  echo "### Total Cloud Storage Usage ###" >> "$report_file"
  echo "These figures represent the local disk space used by cloud storage services:" >> "$report_file"
  
  local total_size=0
  if [[ -n "$icloud_size" ]]; then
    echo "iCloud Drive: $icloud_size" >> "$report_file"
  fi
  
  if [[ -n "$dropbox_size" ]]; then
    echo "Dropbox: $dropbox_size" >> "$report_file"
  fi
  
  if [[ -n "$gdrive_size" ]]; then
    echo "Google Drive: $gdrive_size" >> "$report_file"
  fi
  
  if [[ -n "$onedrive_size" ]]; then
    echo "OneDrive: $onedrive_size" >> "$report_file"
  fi
  
  if [[ -n "$box_size" ]]; then
    echo "Box: $box_size" >> "$report_file"
  fi
  echo "" >> "$report_file"
  
  # Recommendations
  echo "### Recommendations ###" >> "$report_file"
  echo "1. Consider using selective sync to limit which folders are stored locally" >> "$report_file"
  echo "2. Remove large files that don't need to be in cloud storage" >> "$report_file"
  echo "3. Consolidate your cloud services if you use multiple providers" >> "$report_file"
  echo "4. Check startup items to make sure only necessary cloud services start automatically" >> "$report_file"
  echo "" >> "$report_file"
  
  # Display the report
  less "$report_file"
  
  # Offer to save the report
  if confirm "Would you like to save this cloud storage report to your Desktop?"; then
    local report_path="$HOME/Desktop/cloud_storage_report_$(date +%Y%m%d_%H%M%S).txt"
    cp "$report_file" "$report_path"
    log "Cloud storage report saved to: $report_path"
  fi
  
  # Clean up
  rm "$report_file"
  
  echo
  read -n 1 -s -r -p "Press any key to continue..."
  cloud_storage_management
}

# Manage iCloud Drive
manage_icloud() {
  echo -e "\n${BLUE}--- iCloud Drive Management ---${NC}"
  
  # Check if iCloud Drive is configured
  if [[ ! -d "$HOME/Library/Mobile Documents/com~apple~CloudDocs" ]]; then
    log --warn "iCloud Drive does not appear to be configured on this system."
    log "Please set up iCloud Drive through System Settings > Apple ID > iCloud"
    echo
    read -n 1 -s -r -p "Press any key to continue..."
    cloud_storage_management
    return
  fi
  
  # Show iCloud info
  local icloud_path="$HOME/Library/Mobile Documents/com~apple~CloudDocs"
  local icloud_size=$(du -sh "$icloud_path" 2>/dev/null | cut -f1)
  
  echo "iCloud Drive Information:"
  echo "- Local folder: $icloud_path"
  echo "- Local size: $icloud_size"
  
  # Check if Desktop & Documents syncing is enabled
  if [[ -d "$HOME/Library/Mobile Documents/com~apple~CloudDocs/Desktop" || -d "$HOME/Library/Mobile Documents/com~apple~CloudDocs/Documents" ]]; then
    echo "- Desktop & Documents folder syncing: Enabled"
  else
    echo "- Desktop & Documents folder syncing: Disabled"
  fi
  
  echo
  echo "iCloud Management Options:"
  echo "1. View largest files in iCloud Drive"
  echo "2. Open iCloud Drive in Finder"
  echo "3. Open iCloud settings in System Settings"
  echo "4. Optimize iCloud storage"
  echo "5. Return to cloud storage menu"
  echo -n "Select an option: "
  read -r icloud_choice
  
  case "$icloud_choice" in
    1) view_largest_icloud_files ;;
    2) 
      log "Opening iCloud Drive in Finder..."
      open "$icloud_path"
      echo
      read -n 1 -s -r -p "Press any key to continue..."
      manage_icloud
      ;;
    3)
      log "Opening iCloud settings..."
      open "x-apple.systempreferences:com.apple.preferences.AppleIDPrefPane?iCloud"
      echo
      read -n 1 -s -r -p "Press any key to continue..."
      manage_icloud
      ;;
    4) optimize_icloud_storage ;;
    5) cloud_storage_management ;;
    *) log --warn "Invalid choice."; manage_icloud ;;
  esac
}

# View largest files in iCloud Drive
view_largest_icloud_files() {
  echo -e "\n${BLUE}--- Largest Files in iCloud Drive ---${NC}"
  
  local icloud_path="$HOME/Library/Mobile Documents/com~apple~CloudDocs"
  
  if [[ ! -d "$icloud_path" ]]; then
    log --warn "iCloud Drive folder not found."
    echo
    read -n 1 -s -r -p "Press any key to continue..."
    manage_icloud
    return
  fi
  
  echo "Searching for large files in iCloud Drive. This may take a moment..."
  
  # Create a temporary file for the report
  local report_file=$(mktemp)
  
  if [[ $DRY_RUN -eq 0 ]]; then
    # Find the 50 largest files
    find "$icloud_path" -type f -not -path "*/\.*" -exec du -h {} \; 2>/dev/null | sort -hr | head -50 > "$report_file"
    
    # Check if we found any files
    if [[ ! -s "$report_file" ]]; then
      log "No files found in iCloud Drive."
      rm "$report_file"
      echo
      read -n 1 -s -r -p "Press any key to continue..."
      manage_icloud
      return
    fi
    
    echo -e "\n${CYAN}Top 50 Largest Files in iCloud Drive:${NC}"
    cat "$report_file"
    echo
    
    # Offer to browse to specific files
    echo "Would you like to open a specific file's location in Finder?"
    if confirm "Open a file location?"; then
      echo "Enter the line number of the file to open its location (1-50):"
      read -r line_num
      
      if [[ "$line_num" =~ ^[0-9]+$ && "$line_num" -ge 1 && "$line_num" -le 50 ]]; then
        local file_path=$(sed -n "${line_num}p" "$report_file" | awk '{$1=""; print $0}' | xargs)
        if [[ -f "$file_path" ]]; then
          log "Opening folder containing: $(basename "$file_path")"
          open -R "$file_path"
        else
          log --warn "File not found."
        fi
      else
        log --warn "Invalid selection."
      fi
    fi
  else
    log "DRY RUN: Would search for and display largest files in iCloud Drive"
  fi
  
  # Clean up
  rm "$report_file"
  
  echo
  read -n 1 -s -r -p "Press any key to continue..."
  manage_icloud
}

# Optimize iCloud storage
optimize_icloud_storage() {
  echo -e "\n${BLUE}--- Optimize iCloud Storage ---${NC}"
  
  local icloud_path="$HOME/Library/Mobile Documents/com~apple~CloudDocs"
  
  if [[ ! -d "$icloud_path" ]]; then
    log --warn "iCloud Drive folder not found."
    echo
    read -n 1 -s -r -p "Press any key to continue..."
    manage_icloud
    return
  fi
  
  echo "iCloud Storage Optimization Options:"
  echo "1. Check for downloadable files (stored in cloud only)"
  echo "2. Check for large and old files"
  echo "3. Open Optimize Storage settings"
  echo "4. Back to iCloud management"
  echo -n "Select an option: "
  read -r optimize_choice
  
  case "$optimize_choice" in
    1)
      echo -e "\n${CYAN}Checking for cloud-only files...${NC}"
      echo "This will list files that are available only in the cloud but not stored locally."
      echo "These files have a cloud icon in Finder and don't take up local storage."
      
      if [[ $DRY_RUN -eq 0 ]]; then
        # Look for cloud-only files
        log "Searching for cloud-only files. This may take some time..."
        
        # Create temporary file for results
        local cloud_files=$(mktemp)
        
        # Macintosh HD is not physically stored on disk but is in the cloud
        find "$icloud_path" -type f -name "*.icloud" 2>/dev/null > "$cloud_files"
        
        if [[ -s "$cloud_files" ]]; then
          local count=$(wc -l < "$cloud_files" | tr -d ' ')
          echo "Found $count files stored only in the cloud (not taking local space)."
          
          # Show sample of cloud files
          echo "Sample of cloud-only files:"
          head -10 "$cloud_files" | sed "s|$icloud_path/||" | sed 's/\.icloud$//'
          
          if [[ $count -gt 10 ]]; then
            echo "...and $(($count - 10)) more."
          fi
        else
          echo "No cloud-only files found. All your iCloud files appear to be downloaded locally."
        fi
        
        rm "$cloud_files"
      else
        log "DRY RUN: Would search for cloud-only files"
      fi
      ;;
    2)
      echo -e "\n${CYAN}Checking for large and old files...${NC}"
      echo "This will find large files that haven't been accessed recently."
      
      if [[ $DRY_RUN -eq 0 ]]; then
        # Create temporary file for results
        local large_old_files=$(mktemp)
        
        log "Searching for files larger than 50MB and not accessed in 90+ days..."
        
        # Find large files not accessed recently
        find "$icloud_path" -type f -size +50M -atime +90 -not -name "*.icloud" -exec ls -lah {} \; 2>/dev/null | sort -k5hr > "$large_old_files"
        
        if [[ -s "$large_old_files" ]]; then
          local count=$(wc -l < "$large_old_files" | tr -d ' ')
          echo "Found $count large files not accessed in 90+ days."
          echo "These files might be good candidates for removal or archiving elsewhere."
          
          # Display the files
          cat "$large_old_files"
        else
          echo "No large, old files found."
        fi
        
        rm "$large_old_files"
      else
        log "DRY RUN: Would search for large and old files"
      fi
      ;;
    3)
      log "Opening System Settings to manage iCloud Storage..."
      open "x-apple.systempreferences:com.apple.preferences.AppleIDPrefPane?iCloud"
      ;;
    4) manage_icloud ;;
    *) log --warn "Invalid choice."; optimize_icloud_storage ;;
  esac
  
  echo
  read -n 1 -s -r -p "Press any key to continue..."
  manage_icloud
}

# Manage Dropbox
manage_dropbox() {
  echo -e "\n${BLUE}--- Dropbox Management ---${NC}"
  
  # Check if Dropbox is installed
  if [[ ! -d "/Applications/Dropbox.app" ]]; then
    log --warn "Dropbox does not appear to be installed on this system."
    log "You can download Dropbox from https://www.dropbox.com/install"
    echo
    read -n 1 -s -r -p "Press any key to continue..."
    cloud_storage_management
    return
  fi
  
  # Try to find Dropbox folder
  local dropbox_path=""
  if [[ -f "$HOME/.dropbox/info.json" ]]; then
    dropbox_path=$(grep -oE '"path": "[^"]+"' "$HOME/.dropbox/info.json" | cut -d'"' -f4)
  fi
  
  if [[ -z "$dropbox_path" && -d "$HOME/Dropbox" ]]; then
    dropbox_path="$HOME/Dropbox"
  fi
  
  if [[ -z "$dropbox_path" || ! -d "$dropbox_path" ]]; then
    log --warn "Could not find Dropbox folder. Make sure Dropbox is set up correctly."
    echo
    read -n 1 -s -r -p "Press any key to continue..."
    cloud_storage_management
    return
  fi
  
  # Show Dropbox info
  local dropbox_size=$(du -sh "$dropbox_path" 2>/dev/null | cut -f1)
  
  echo "Dropbox Information:"
  echo "- Installation: /Applications/Dropbox.app"
  echo "- Local folder: $dropbox_path"
  echo "- Local size: $dropbox_size"
  
  # Check for Dropbox cache
  local cache_path="$HOME/.dropbox.cache"
  if [[ -d "$cache_path" ]]; then
    local cache_size=$(du -sh "$cache_path" 2>/dev/null | cut -f1)
    echo "- Cache size: $cache_size"
  fi
  
  echo
  echo "Dropbox Management Options:"
  echo "1. View largest files in Dropbox"
  echo "2. Clean Dropbox cache"
  echo "3. Open Dropbox folder in Finder"
  echo "4. Launch Dropbox application"
  echo "5. Return to cloud storage menu"
  echo -n "Select an option: "
  read -r dropbox_choice
  
  case "$dropbox_choice" in
    1) view_largest_dropbox_files "$dropbox_path" ;;
    2) clean_dropbox_cache ;;
    3) 
      log "Opening Dropbox folder in Finder..."
      open "$dropbox_path"
      echo
      read -n 1 -s -r -p "Press any key to continue..."
      manage_dropbox
      ;;
    4)
      log "Launching Dropbox application..."
      open -a Dropbox
      echo
      read -n 1 -s -r -p "Press any key to continue..."
      manage_dropbox
      ;;
    5) cloud_storage_management ;;
    *) log --warn "Invalid choice."; manage_dropbox ;;
  esac
}

# View largest files in Dropbox
view_largest_dropbox_files() {
  local dropbox_path="$1"
  echo -e "\n${BLUE}--- Largest Files in Dropbox ---${NC}"
  
  if [[ ! -d "$dropbox_path" ]]; then
    log --warn "Dropbox folder not found."
    echo
    read -n 1 -s -r -p "Press any key to continue..."
    manage_dropbox
    return
  fi
  
  echo "Searching for large files in Dropbox. This may take a moment..."
  
  # Create a temporary file for the report
  local report_file=$(mktemp)
  
  if [[ $DRY_RUN -eq 0 ]]; then
    # Find the 50 largest files
    find "$dropbox_path" -type f -not -path "*/\.*" -exec du -h {} \; 2>/dev/null | sort -hr | head -50 > "$report_file"
    
    # Check if we found any files
    if [[ ! -s "$report_file" ]]; then
      log "No files found in Dropbox."
      rm "$report_file"
      echo
      read -n 1 -s -r -p "Press any key to continue..."
      manage_dropbox
      return
    fi
    
    echo -e "\n${CYAN}Top 50 Largest Files in Dropbox:${NC}"
    cat "$report_file"
    echo
    
    # Offer to browse to specific files
    echo "Would you like to open a specific file's location in Finder?"
    if confirm "Open a file location?"; then
      echo "Enter the line number of the file to open its location (1-50):"
      read -r line_num
      
      if [[ "$line_num" =~ ^[0-9]+$ && "$line_num" -ge 1 && "$line_num" -le 50 ]]; then
        local file_path=$(sed -n "${line_num}p" "$report_file" | awk '{$1=""; print $0}' | xargs)
        if [[ -f "$file_path" ]]; then
          log "Opening folder containing: $(basename "$file_path")"
          open -R "$file_path"
        else
          log --warn "File not found."
        fi
      else
        log --warn "Invalid selection."
      fi
    fi
  else
    log "DRY RUN: Would search for and display largest files in Dropbox"
  fi
  
  # Clean up
  rm "$report_file"
  
  echo
  read -n 1 -s -r -p "Press any key to continue..."
  manage_dropbox
}

# Clean Dropbox cache
clean_dropbox_cache() {
  echo -e "\n${BLUE}--- Clean Dropbox Cache ---${NC}"
  
  local cache_path="$HOME/.dropbox.cache"
  
  if [[ ! -d "$cache_path" ]]; then
    log "Dropbox cache directory not found or already clean."
    echo
    read -n 1 -s -r -p "Press any key to continue..."
    manage_dropbox
    return
  fi
  
  local cache_size=$(du -sh "$cache_path" 2>/dev/null | cut -f1)
  log "Dropbox cache found: $cache_size"
  
  if confirm "Would you like to clean the Dropbox cache?"; then
    # First try to quit Dropbox
    log "Attempting to quit Dropbox before cleaning cache..."
    osascript -e 'quit app "Dropbox"' 2>/dev/null
    sleep 2
    
    # Check if Dropbox is still running
    if pgrep -x "Dropbox" > /dev/null; then
      log --warn "Could not quit Dropbox. Some cache files may be in use."
      if ! confirm "Continue with cache cleaning anyway?"; then
        log "Cache cleaning cancelled."
        echo
        read -n 1 -s -r -p "Press any key to continue..."
        manage_dropbox
        return
      fi
    fi
    
    # Backup the cache directory (structure only, not contents)
    backup_item "$cache_path"
    
    # Clean the cache
    log "Cleaning Dropbox cache..."
    if [[ $DRY_RUN -eq 0 ]]; then
      run_command rm -rf "$cache_path"/*
      log "Dropbox cache has been cleaned."
    else
      log "DRY RUN: Would clean Dropbox cache at $cache_path"
    fi
    
    # Ask about restarting Dropbox
    if confirm "Would you like to restart Dropbox?"; then
      log "Starting Dropbox..."
      run_command open -a Dropbox
    fi
  fi
  
  echo
  read -n 1 -s -r -p "Press any key to continue..."
  manage_dropbox
}

# Manage Google Drive
manage_google_drive() {
  echo -e "\n${BLUE}--- Google Drive Management ---${NC}"
  
  # Check for different versions of Google Drive
  local gdrive_app=""
  if [[ -d "/Applications/Google Drive.app" ]]; then
    gdrive_app="/Applications/Google Drive.app"
  elif [[ -d "/Applications/Google Drive File Stream.app" ]]; then
    gdrive_app="/Applications/Google Drive File Stream.app"
  elif [[ -d "/Applications/Drive File Stream.app" ]]; then
    gdrive_app="/Applications/Drive File Stream.app"
  fi
  
  if [[ -z "$gdrive_app" ]]; then
    log --warn "Google Drive does not appear to be installed on this system."
    log "You can download Google Drive from https://www.google.com/drive/download/"
    echo
    read -n 1 -s -r -p "Press any key to continue..."
    cloud_storage_management
    return
  fi
  
  # Try to find Google Drive folder
  local gdrive_path=""
  if [[ -d "$HOME/Google Drive" ]]; then
    gdrive_path="$HOME/Google Drive"
  elif [[ -d "/Volumes/GoogleDrive" ]]; then
    gdrive_path="/Volumes/GoogleDrive"
  elif [[ -d "$HOME/Library/CloudStorage/GoogleDrive-"* ]]; then
    gdrive_path=$(find "$HOME/Library/CloudStorage" -name "GoogleDrive-*" -type d | head -1)
  fi
  
  # Show Google Drive info
  echo "Google Drive Information:"
  echo "- Installation: $gdrive_app"
  
  if [[ -n "$gdrive_path" && -d "$gdrive_path" ]]; then
    local gdrive_size=$(du -sh "$gdrive_path" 2>/dev/null | cut -f1)
    echo "- Local folder: $gdrive_path"
    echo "- Local size: $gdrive_size"
  else
    echo "- Local folder: Not found or not configured"
  fi
  
  echo
  echo "Google Drive Management Options:"
  if [[ -n "$gdrive_path" && -d "$gdrive_path" ]]; then
    echo "1. View largest files in Google Drive"
    echo "2. Clean Google Drive cache"
    echo "3. Open Google Drive folder in Finder"
    echo "4. Launch Google Drive application"
    echo "5. Return to cloud storage menu"
    echo -n "Select an option: "
    read -r gdrive_choice
    
    case "$gdrive_choice" in
      1) view_largest_gdrive_files "$gdrive_path" ;;
      2) clean_gdrive_cache ;;
      3) 
        log "Opening Google Drive folder in Finder..."
        open "$gdrive_path"
        echo
        read -n 1 -s -r -p "Press any key to continue..."
        manage_google_drive
        ;;
      4)
        log "Launching Google Drive application..."
        open "$gdrive_app"
        echo
        read -n 1 -s -r -p "Press any key to continue..."
        manage_google_drive
        ;;
      5) cloud_storage_management ;;
      *) log --warn "Invalid choice."; manage_google_drive ;;
    esac
  else
    echo "1. Clean Google Drive cache"
    echo "2. Launch Google Drive application"
    echo "3. Return to cloud storage menu"
    echo -n "Select an option: "
    read -r gdrive_choice
    
    case "$gdrive_choice" in
      1) clean_gdrive_cache ;;
      2)
        log "Launching Google Drive application..."
        open "$gdrive_app"
        echo
        read -n 1 -s -r -p "Press any key to continue..."
        manage_google_drive
        ;;
      3) cloud_storage_management ;;
      *) log --warn "Invalid choice."; manage_google_drive ;;
    esac
  fi
}

# View largest files in Google Drive
view_largest_gdrive_files() {
  local gdrive_path="$1"
  echo -e "\n${BLUE}--- Largest Files in Google Drive ---${NC}"
  
  if [[ ! -d "$gdrive_path" ]]; then
    log --warn "Google Drive folder not found."
    echo
    read -n 1 -s -r -p "Press any key to continue..."
    manage_google_drive
    return
  fi
  
  echo "Searching for large files in Google Drive. This may take a moment..."
  
  # Create a temporary file for the report
  local report_file=$(mktemp)
  
  if [[ $DRY_RUN -eq 0 ]]; then
    # Find the 50 largest files
    find "$gdrive_path" -type f -not -path "*/\.*" -exec du -h {} \; 2>/dev/null | sort -hr | head -50 > "$report_file"
    
    # Check if we found any files
    if [[ ! -s "$report_file" ]]; then
      log "No files found in Google Drive or files are stored in the cloud only."
      rm "$report_file"
      echo
      read -n 1 -s -r -p "Press any key to continue..."
      manage_google_drive
      return
    fi
    
    echo -e "\n${CYAN}Top 50 Largest Files in Google Drive:${NC}"
    cat "$report_file"
    echo
    
    # Offer to browse to specific files
    echo "Would you like to open a specific file's location in Finder?"
    if confirm "Open a file location?"; then
      echo "Enter the line number of the file to open its location (1-50):"
      read -r line_num
      
      if [[ "$line_num" =~ ^[0-9]+$ && "$line_num" -ge 1 && "$line_num" -le 50 ]]; then
        local file_path=$(sed -n "${line_num}p" "$report_file" | awk '{$1=""; print $0}' | xargs)
        if [[ -f "$file_path" ]]; then
          log "Opening folder containing: $(basename "$file_path")"
          open -R "$file_path"
        else
          log --warn "File not found."
        fi
      else
        log --warn "Invalid selection."
      fi
    fi
  else
    log "DRY RUN: Would search for and display largest files in Google Drive"
  fi
  
  # Clean up
  rm "$report_file"
  
  echo
  read -n 1 -s -r -p "Press any key to continue..."
  manage_google_drive
}

# Clean Google Drive cache
clean_gdrive_cache() {
  echo -e "\n${BLUE}--- Clean Google Drive Cache ---${NC}"
  
  # Locate Google Drive cache directories
  local cache_paths=(
    "$HOME/Library/Application Support/Google/DriveFS"
    "$HOME/Library/Caches/com.google.drivefs"
    "$HOME/Library/Caches/Google Drive"
  )
  
  local found_cache=0
  local total_size=0
  
  for path in "${cache_paths[@]}"; do
    if [[ -d "$path" ]]; then
      local size=$(du -sh "$path" 2>/dev/null | cut -f1)
      log "Google Drive cache found: $path ($size)"
      found_cache=1
    fi
  done
  
  if [[ $found_cache -eq 0 ]]; then
    log "No Google Drive cache directories found."
    echo
    read -n 1 -s -r -p "Press any key to continue..."
    manage_google_drive
    return
  fi
  
  if confirm "Would you like to clean Google Drive cache directories?"; then
    # Attempt to quit Google Drive first
    log "Attempting to quit Google Drive before cleaning cache..."
    osascript -e 'quit app "Google Drive"' 2>/dev/null
    osascript -e 'quit app "Google Drive File Stream"' 2>/dev/null
    osascript -e 'quit app "Drive File Stream"' 2>/dev/null
    sleep 2
    
    # Check if Google Drive is still running
    if pgrep -x "Google Drive" > /dev/null || pgrep -x "Google Drive File Stream" > /dev/null || pgrep -x "DriveFS" > /dev/null; then
      log --warn "Could not quit Google Drive. Some cache files may be in use."
      if ! confirm "Continue with cache cleaning anyway?"; then
        log "Cache cleaning cancelled."
        echo
        read -n 1 -s -r -p "Press any key to continue..."
        manage_google_drive
        return
      fi
    fi
    
    # Clean each cache directory
    for path in "${cache_paths[@]}"; do
      if [[ -d "$path" ]]; then
        # Backup the directory structure (not contents)
        backup_item "$path"
        
        log "Cleaning Google Drive cache: $path"
        if [[ $DRY_RUN -eq 0 ]]; then
          # Remove contents but preserve directory structure
          run_command find "$path" -mindepth 1 -delete
        else
          log "DRY RUN: Would clean Google Drive cache at $path"
        fi
      fi
    done
    
    log "Google Drive cache has been cleaned."
    
    # Ask about restarting Google Drive
    if confirm "Would you like to restart Google Drive?"; then
      log "Starting Google Drive..."
      local gdrive_app=""
      if [[ -d "/Applications/Google Drive.app" ]]; then
        gdrive_app="/Applications/Google Drive.app"
      elif [[ -d "/Applications/Google Drive File Stream.app" ]]; then
        gdrive_app="/Applications/Google Drive File Stream.app"
      elif [[ -d "/Applications/Drive File Stream.app" ]]; then
        gdrive_app="/Applications/Drive File Stream.app"
      fi
      
      if [[ -n "$gdrive_app" ]]; then
        run_command open -a "$gdrive_app"
      else
        log --warn "Google Drive application not found."
      fi
    fi
  fi
  
  echo
  read -n 1 -s -r -p "Press any key to continue..."
  manage_google_drive
}

# Manage OneDrive
manage_onedrive() {
  echo -e "\n${BLUE}--- OneDrive Management ---${NC}"
  
  # Check if OneDrive is installed
  if [[ ! -d "/Applications/OneDrive.app" ]]; then
    log --warn "OneDrive does not appear to be installed on this system."
    log "You can download OneDrive from https://www.microsoft.com/en-us/microsoft-365/onedrive/download"
    echo
    read -n 1 -s -r -p "Press any key to continue..."
    cloud_storage_management
    return
  fi
  
  # Try to find OneDrive folder
  local onedrive_path=""
  if [[ -d "$HOME/OneDrive" ]]; then
    onedrive_path="$HOME/OneDrive"
  elif [[ -d "$HOME/Library/CloudStorage/OneDrive-"* ]]; then
    onedrive_path=$(find "$HOME/Library/CloudStorage" -name "OneDrive-*" -type d | head -1)
  fi
  
  if [[ -z "$onedrive_path" || ! -d "$onedrive_path" ]]; then
    log --warn "Could not find OneDrive folder. Make sure OneDrive is set up correctly."
    echo
    read -n 1 -s -r -p "Press any key to continue..."
    cloud_storage_management
    return
  fi
  
  # Show OneDrive info
  local onedrive_size=$(du -sh "$onedrive_path" 2>/dev/null | cut -f1)
  
  echo "OneDrive Information:"
  echo "- Installation: /Applications/OneDrive.app"
  echo "- Local folder: $onedrive_path"
  echo "- Local size: $onedrive_size"
  
  echo
  echo "OneDrive Management Options:"
  echo "1. View largest files in OneDrive"
  echo "2. Clean OneDrive cache"
  echo "3. Open OneDrive folder in Finder"
  echo "4. Launch OneDrive application"
  echo "5. Return to cloud storage menu"
  echo -n "Select an option: "
  read -r onedrive_choice
  
  case "$onedrive_choice" in
    1) view_largest_onedrive_files "$onedrive_path" ;;
    2) clean_onedrive_cache ;;
    3) 
      log "Opening OneDrive folder in Finder..."
      open "$onedrive_path"
      echo
      read -n 1 -s -r -p "Press any key to continue..."
      manage_onedrive
      ;;
    4)
      log "Launching OneDrive application..."
      open -a OneDrive
      echo
      read -n 1 -s -r -p "Press any key to continue..."
      manage_onedrive
      ;;
    5) cloud_storage_management ;;
    *) log --warn "Invalid choice."; manage_onedrive ;;
  esac
}

# View largest files in OneDrive
view_largest_onedrive_files() {
  local onedrive_path="$1"
  echo -e "\n${BLUE}--- Largest Files in OneDrive ---${NC}"
  
  if [[ ! -d "$onedrive_path" ]]; then
    log --warn "OneDrive folder not found."
    echo
    read -n 1 -s -r -p "Press any key to continue..."
    manage_onedrive
    return
  fi
  
  echo "Searching for large files in OneDrive. This may take a moment..."
  
  # Create a temporary file for the report
  local report_file=$(mktemp)
  
  if [[ $DRY_RUN -eq 0 ]]; then
    # Find the 50 largest files
    find "$onedrive_path" -type f -not -path "*/\.*" -exec du -h {} \; 2>/dev/null | sort -hr | head -50 > "$report_file"
    
    # Check if we found any files
    if [[ ! -s "$report_file" ]]; then
      log "No files found in OneDrive."
      rm "$report_file"
      echo
      read -n 1 -s -r -p "Press any key to continue..."
      manage_onedrive
      return
    fi
    
    echo -e "\n${CYAN}Top 50 Largest Files in OneDrive:${NC}"
    cat "$report_file"
    echo
    
    # Offer to browse to specific files
    echo "Would you like to open a specific file's location in Finder?"
    if confirm "Open a file location?"; then
      echo "Enter the line number of the file to open its location (1-50):"
      read -r line_num
      
      if [[ "$line_num" =~ ^[0-9]+$ && "$line_num" -ge 1 && "$line_num" -le 50 ]]; then
        local file_path=$(sed -n "${line_num}p" "$report_file" | awk '{$1=""; print $0}' | xargs)
        if [[ -f "$file_path" ]]; then
          log "Opening folder containing: $(basename "$file_path")"
          open -R "$file_path"
        else
          log --warn "File not found."
        fi
      else
        log --warn "Invalid selection."
      fi
    fi
  else
    log "DRY RUN: Would search for and display largest files in OneDrive"
  fi
  
  # Clean up
  rm "$report_file"
  
  echo
  read -n 1 -s -r -p "Press any key to continue..."
  manage_onedrive
}

# Clean OneDrive cache
clean_onedrive_cache() {
  echo -e "\n${BLUE}--- Clean OneDrive Cache ---${NC}"
  
  # Locate OneDrive cache directories
  local cache_paths=(
    "$HOME/Library/Caches/com.microsoft.OneDrive"
    "$HOME/Library/Caches/com.microsoft.OneDriveStandaloneUpdater"
    "$HOME/Library/Containers/com.microsoft.OneDrive-mac/Data/Library/Caches"
  )
  
  local found_cache=0
  local total_size=0
  
  for path in "${cache_paths[@]}"; do
    if [[ -d "$path" ]]; then
      local size=$(du -sh "$path" 2>/dev/null | cut -f1)
      log "OneDrive cache found: $path ($size)"
      found_cache=1
    fi
  done
  
  if [[ $found_cache -eq 0 ]]; then
    log "No OneDrive cache directories found."
    echo
    read -n 1 -s -r -p "Press any key to continue..."
    manage_onedrive
    return
  fi
  
  if confirm "Would you like to clean OneDrive cache directories?"; then
    # Attempt to quit OneDrive first
    log "Attempting to quit OneDrive before cleaning cache..."
    osascript -e 'quit app "OneDrive"' 2>/dev/null
    sleep 2
    
    # Check if OneDrive is still running
    if pgrep -x "OneDrive" > /dev/null; then
      log --warn "Could not quit OneDrive. Some cache files may be in use."
      if ! confirm "Continue with cache cleaning anyway?"; then
        log "Cache cleaning cancelled."
        echo
        read -n 1 -s -r -p "Press any key to continue..."
        manage_onedrive
        return
      fi
    fi
    
    # Clean each cache directory
    for path in "${cache_paths[@]}"; do
      if [[ -d "$path" ]]; then
        # Backup the directory structure (not contents)
        backup_item "$path"
        
        log "Cleaning OneDrive cache: $path"
        if [[ $DRY_RUN -eq 0 ]]; then
          # Remove contents but preserve directory structure
          run_command find "$path" -mindepth 1 -delete
        else
          log "DRY RUN: Would clean OneDrive cache at $path"
        fi
      fi
    done
    
    log "OneDrive cache has been cleaned."
    
    # Ask about restarting OneDrive
    if confirm "Would you like to restart OneDrive?"; then
      log "Starting OneDrive..."
      run_command open -a OneDrive
    fi
  fi
  
  echo
  read -n 1 -s -r -p "Press any key to continue..."
  manage_onedrive
}

# Manage cloud storage preferences
manage_cloud_preferences() {
  echo -e "\n${BLUE}--- Cloud Storage Preferences ---${NC}"
  
  echo "Cloud Storage Optimization Options:"
  echo "1. Set a cloud service as preferred"
  echo "2. Display recommended cloud storage settings"
  echo "3. Manage startup settings for cloud services"
  echo "4. Return to cloud storage menu"
  echo -n "Select an option: "
  read -r pref_choice
  
  case "$pref_choice" in
    1) set_preferred_cloud_service ;;
    2) display_cloud_recommendations ;;
    3) manage_cloud_startup ;;
    4) cloud_storage_management ;;
    *) log --warn "Invalid choice."; manage_cloud_preferences ;;
  esac
}

# Set a cloud service as preferred
set_preferred_cloud_service() {
  echo -e "\n${BLUE}--- Set Preferred Cloud Service ---${NC}"
  
  echo "This will help you set one cloud service as your primary storage option."
  echo "The script will guide you through enabling selective sync for secondary services."
  echo
  
  # Detect installed cloud services
  local installed_services=()
  local service_paths=()
  
  if [[ -d "$HOME/Library/Mobile Documents/com~apple~CloudDocs" ]]; then
    installed_services+=("iCloud Drive")
    service_paths+=("$HOME/Library/Mobile Documents/com~apple~CloudDocs")
  fi
  
  if [[ -d "/Applications/Dropbox.app" ]]; then
    if [[ -d "$HOME/Dropbox" ]]; then
      installed_services+=("Dropbox")
      service_paths+=("$HOME/Dropbox")
    elif [[ -f "$HOME/.dropbox/info.json" ]]; then
      local dropbox_path=$(grep -oE '"path": "[^"]+"' "$HOME/.dropbox/info.json" | cut -d'"' -f4)
      if [[ -n "$dropbox_path" ]]; then
        installed_services+=("Dropbox")
        service_paths+=("$dropbox_path")
      fi
    fi
  fi
  
  if [[ -d "/Applications/Google Drive.app" || -d "/Applications/Google Drive File Stream.app" || -d "/Applications/Drive File Stream.app" ]]; then
    if [[ -d "$HOME/Google Drive" ]]; then
      installed_services+=("Google Drive")
      service_paths+=("$HOME/Google Drive")
    elif [[ -d "/Volumes/GoogleDrive" ]]; then
      installed_services+=("Google Drive")
      service_paths+=("/Volumes/GoogleDrive")
    elif [[ -d "$HOME/Library/CloudStorage/GoogleDrive-"* ]]; then
      local gdrive_path=$(find "$HOME/Library/CloudStorage" -name "GoogleDrive-*" -type d | head -1)
      installed_services+=("Google Drive")
      service_paths+=("$gdrive_path")
    fi
  fi
  
  if [[ -d "/Applications/OneDrive.app" ]]; then
    if [[ -d "$HOME/OneDrive" ]]; then
      installed_services+=("OneDrive")
      service_paths+=("$HOME/OneDrive")
    elif [[ -d "$HOME/Library/CloudStorage/OneDrive-"* ]]; then
      local onedrive_path=$(find "$HOME/Library/CloudStorage" -name "OneDrive-*" -type d | head -1)
      installed_services+=("OneDrive")
      service_paths+=("$onedrive_path")
    fi
  fi
  
  if [[ ${#installed_services[@]} -eq 0 ]]; then
    log --warn "No cloud services found on this system."
    echo
    read -n 1 -s -r -p "Press any key to continue..."
    manage_cloud_preferences
    return
  fi
  
  if [[ ${#installed_services[@]} -eq 1 ]]; then
    log "Only one cloud service (${installed_services[0]}) is installed on this system."
    log "No need to set a preferred service."
    echo
    read -n 1 -s -r -p "Press any key to continue..."
    manage_cloud_preferences
    return
  fi
  
  # Display installed services
  echo "Installed cloud services:"
  for i in "${!installed_services[@]}"; do
    local service="${installed_services[$i]}"
    local path="${service_paths[$i]}"
    local size=$(du -sh "$path" 2>/dev/null | cut -f1)
    echo "$((i+1)). $service - Path: $path - Size: $size"
  done
  
  echo
  echo -n "Select your preferred cloud service (1-${#installed_services[@]}): "
  read -r preferred_num
  
  if [[ "$preferred_num" =~ ^[0-9]+$ && "$preferred_num" -ge 1 && "$preferred_num" -le ${#installed_services[@]} ]]; then
    local preferred_service="${installed_services[$((preferred_num-1))]}"
    log "You've selected $preferred_service as your preferred cloud service."
    
    echo
    echo "For each additional cloud service, we recommend using selective sync"
    echo "to minimize duplicate storage. Would you like to open settings for"
    echo "each secondary service to adjust selective sync?"
    
    if confirm "Open settings for other cloud services?"; then
      for i in "${!installed_services[@]}"; do
        if [[ $((i+1)) -ne $preferred_num ]]; then
          local service="${installed_services[$i]}"
          log "Opening settings for $service..."
          
          case "$service" in
            "iCloud Drive")
              open "x-apple.systempreferences:com.apple.preferences.AppleIDPrefPane?iCloud"
              echo "In iCloud settings, you can disable specific apps and features."
              echo "Press any key when done adjusting iCloud settings..."
              read -n 1 -s -r
              ;;
            "Dropbox")
              open -a Dropbox
              echo "In Dropbox preferences, go to 'Sync' tab and click 'Choose folders'."
              echo "Press any key when done adjusting Dropbox settings..."
              read -n 1 -s -r
              ;;
            "Google Drive")
              if [[ -d "/Applications/Google Drive.app" ]]; then
                open -a "Google Drive"
              elif [[ -d "/Applications/Google Drive File Stream.app" ]]; then
                open -a "Google Drive File Stream"
              elif [[ -d "/Applications/Drive File Stream.app" ]]; then
                open -a "Drive File Stream"
              fi
              echo "In Google Drive preferences, find 'Sync options' or similar settings."
              echo "Press any key when done adjusting Google Drive settings..."
              read -n 1 -s -r
              ;;
            "OneDrive")
              open -a OneDrive
              echo "In OneDrive preferences, find 'Choose folders' in the Account tab."
              echo "Press any key when done adjusting OneDrive settings..."
              read -n 1 -s -r
              ;;
          esac
        fi
      done
    fi
    
    log "Cloud service preferences have been configured."
  else
    log --warn "Invalid selection."
  fi
  
  echo
  read -n 1 -s -r -p "Press any key to continue..."
  manage_cloud_preferences
}

# Display cloud recommendations
display_cloud_recommendations() {
  echo -e "\n${BLUE}--- Cloud Storage Recommendations ---${NC}"
  
  echo "Recommendations for Efficient Cloud Storage Management:"
  echo
  echo "1. Use Selective Sync to minimize local storage usage"
  echo "   • Only sync folders you need access to when offline"
  echo "   • Use web interfaces for occasional access to other files"
  echo
  echo "2. Avoid syncing large folders like:"
  echo "   • Photo libraries"
  echo "   • Virtual machine images"
  echo "   • Video files"
  echo "   • Software downloads/installers"
  echo
  echo "3. Keep folder structures consistent across services"
  echo "   • Use clear naming conventions"
  echo "   • Avoid duplicating the same files in multiple services"
  echo
  echo "4. Manage cache settings"
  echo "   • Regularly clean caches for unused services"
  echo "   • Set reasonable cache limits in app preferences"
  echo
  echo "5. Startup Management"
  echo "   • Only enable auto-start for your primary cloud service"
  echo "   • Manually start secondary services when needed"
  echo
  echo "6. Security best practices"
  echo "   • Enable two-factor authentication for all services"
  echo "   • Don't store sensitive data without encryption"
  echo "   • Regularly review access permissions"
  echo
  
  echo
  read -n 1 -s -r -p "Press any key to continue..."
  manage_cloud_preferences
}

# Manage cloud startup settings
manage_cloud_startup() {
  echo -e "\n${BLUE}--- Manage Cloud Service Startup Settings ---${NC}"
  
  log "Checking for cloud services in login items..."
  
  # Get current login items
  local login_items=$(osascript -e 'tell application "System Events" to get the name of every login item' 2>/dev/null)
  
  # Known cloud service apps
  local cloud_apps=("Dropbox" "Google Drive" "OneDrive" "Box")
  local found_apps=()
  
  for app in "${cloud_apps[@]}"; do
    if [[ "$login_items" == *"$app"* ]]; then
      found_apps+=("$app")
    fi
  done
  
  if [[ ${#found_apps[@]} -eq 0 ]]; then
    log "No cloud services found in login items."
    echo
    echo "Would you like to open Login Items settings to add a cloud service?"
    if confirm "Open Login Items settings?"; then
      log "Opening Login Items settings..."
      open "x-apple.systempreferences:com.apple.preferences.users"
      echo
      read -n 1 -s -r -p "Press Login Items tab in the sidebar, then press any key to continue..."
    fi
  else
    echo "Cloud services in login items:"
    for app in "${found_apps[@]}"; do
      echo "- $app"
    done
    
    echo
    echo "Would you like to manage these startup items?"
    if confirm "Manage startup items?"; then
      echo "1. Remove a cloud service from startup"
      echo "2. Open Login Items settings to make changes"
      echo -n "Select an option: "
      read -r startup_choice
      
      case "$startup_choice" in
        1)
          if [[ ${#found_apps[@]} -eq 1 ]]; then
            local app="${found_apps[0]}"
            if confirm "Remove $app from startup items?"; then
              log "Removing $app from login items..."
              osascript -e "tell application \"System Events\" to delete login item \"$app\""
              log "$app has been removed from startup items."
            fi
          else
            echo "Select a cloud service to remove from startup:"
            for i in "${!found_apps[@]}"; do
              echo "$((i+1)). ${found_apps[$i]}"
            done
            echo -n "Select an option (1-${#found_apps[@]}): "
            read -r app_num
            
            if [[ "$app_num" =~ ^[0-9]+$ && "$app_num" -ge 1 && "$app_num" -le ${#found_apps[@]} ]]; then
              local app="${found_apps[$((app_num-1))]}"
              if confirm "Remove $app from startup items?"; then
                log "Removing $app from login items..."
                osascript -e "tell application \"System Events\" to delete login item \"$app\""
                log "$app has been removed from startup items."
              fi
            else
              log --warn "Invalid selection."
            fi
          fi
          ;;
        2)
          log "Opening Login Items settings..."
          open "x-apple.systempreferences:com.apple.preferences.users"
          echo
          read -n 1 -s -r -p "Press Login Items tab in the sidebar, then press any key to continue..."
          ;;
        *)
          log --warn "Invalid choice."
          ;;
      esac
    fi
  fi
  
  echo
  read -n 1 -s -r -p "Press any key to continue..."
  manage_cloud_preferences
}