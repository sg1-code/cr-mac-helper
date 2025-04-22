#!/bin/bash

# app_cleanup.sh - Application cleanup and management functions

# Main app cleanup function
app_cleanup() {
  printf "\n${BLUE}=== App Cleanup ===${NC}\n"
  check_privileges 0  # Doesn't absolutely require root
  
  # Check disk space for backups
  check_disk_space 500 || return 1
  
  # Menu for different app cleanup options
  echo "1. Remove a specific application"
  echo "2. Find unused applications (by last accessed date)"
  echo "3. Check for broken app bundles"
  echo "4. Return to main menu"
  echo -n "Select an option: "
  read -r app_choice
  
  case "$app_choice" in
    1) remove_specific_app ;;
    2) find_unused_apps ;;
    3) check_broken_apps ;;
    4) return ;;
    *) log --warn "Invalid choice. Returning to main menu."; return ;;
  esac
}

# Process for removing a specific application
remove_specific_app() {
  printf "\n${BLUE}--- Complete App Removal ---${NC}\n"
  
  # Get a sorted list of installed applications, excluding system apps
  local system_apps=(
    "Safari.app" "Mail.app" "App Store.app" "System Preferences.app" "System Settings.app"
    "Utilities" "Photos.app" "Messages.app" "FaceTime.app" "Contacts.app" 
    "Calendar.app" "Reminders.app" "Notes.app" "Books.app" "Preview.app" 
    "Music.app" "TV.app" "Podcasts.app" "Maps.app" "News.app" 
    "Voice Memos.app" "Home.app" "Stocks.app" "Siri.app" "QuickTime Player.app" 
    "TextEdit.app" "Dictionary.app" "Calculator.app" "Stickies.app" 
    "Image Capture.app" "Automator.app" "Console.app" "Script Editor.app" 
    "Terminal.app" "Activity Monitor.app" "System Information.app" 
    "Boot Camp Assistant.app" "Migration Assistant.app" "VoiceOver Utility.app" 
    "ColorSync Utility.app" "Time Machine.app" "Chess.app" "Clock.app"
  )
  
  # Build exclusion pattern
  local exclude_pattern=""
  for app in "${system_apps[@]}"; do
    exclude_pattern="$exclude_pattern -e \"^/Applications/$app$\""
  done
  
  # Find user applications, handling spaces in names properly
  local app_list=$(find /Applications -maxdepth 2 -type d -name "*.app" -print | sort)
  if [[ -d "$HOME/Applications" ]]; then
    app_list="$app_list"$'\n'"$(find "$HOME/Applications" -maxdepth 2 -type d -name "*.app" -print | sort)"
  fi
  
  # Filter out system apps using grep -v
  app_list=$(echo "$app_list" | eval "grep -v $exclude_pattern")
  
  if [[ -z "$app_list" ]]; then
    log "No user-installed applications found."
    return
  fi
  
  # Build temporary file for app list
  local temp_file=$(mktemp)
  echo "$app_list" > "$temp_file"
  
  # Display applications with numbers
  echo "Installed Applications:"
  cat -n "$temp_file"
  
  # Ask for selection
  echo -n "Enter the number of the application to remove (or 0 to cancel): "
  read -r app_num
  
  if [[ $app_num -eq 0 || -z "$app_num" ]]; then
    rm "$temp_file"
    return
  fi
  
  # Get the selected app path
  local app_path=$(sed -n "${app_num}p" "$temp_file")
  rm "$temp_file"
  
  if [[ ! -d "$app_path" ]]; then
    log --warn "Invalid selection or application not found."
    return
  fi
  
  # Extract app name for searching related files
  local app_name=$(basename "$app_path" .app)
  local app_bundle_id=""
  
  # Try to get the bundle identifier for more accurate file association
  if [[ -f "$app_path/Contents/Info.plist" ]]; then
    app_bundle_id=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$app_path/Contents/Info.plist" 2>/dev/null)
  fi
  
  log "Selected app: $app_name (Bundle ID: ${app_bundle_id:-Unknown})"
  
  # Detailed app info to help user make an informed decision
  printf "\n${CYAN}=== App Details ===${NC}\n"
  echo "Name: $app_name"
  echo "Location: $app_path"
  echo "Size: $(du -sh "$app_path" | cut -f1)"
  echo "Last accessed: $(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$app_path")"
  if [[ -n "$app_bundle_id" ]]; then
    echo "Bundle ID: $app_bundle_id"
  fi
  
  if ! confirm "Are you sure you want to remove '$app_name' and all associated files?"; then
    return
  fi
  
  # First check if app is running
  local is_running=0
  pgrep -f "$app_path" >/dev/null && is_running=1
  
  if [[ $is_running -eq 1 ]]; then
    log --warn "Application '$app_name' appears to be running."
    if confirm "Attempt to quit the application?"; then
      osascript -e "tell application \"$app_name\" to quit" || {
        log --warn "Failed to quit the application. Try closing it manually."
        if ! confirm "Continue anyway? (may cause incomplete removal)"; then
          return
        fi
      }
    else
      if ! confirm "Continue anyway? (may cause incomplete removal)"; then
        return
      fi
    fi
  fi
  
  # Backup the app bundle
  backup_item "$app_path"
  
  # Remove the app bundle
  log "Removing application bundle: $app_path"
  run_command rm -rf "$app_path"
  
  # Find and remove associated files
  find_and_remove_associated_files "$app_name" "$app_bundle_id"
  
  # Remove launch agents and login items
  remove_launch_agents "$app_name" "$app_bundle_id"
  remove_login_items "$app_name"
  
  # Check for app receipt in App Store database
  if [[ -n "$app_bundle_id" ]]; then
    local receipt_path="/Library/Application Support/App Store/receipts/$app_bundle_id.receipt"
    if [[ -f "$receipt_path" ]]; then
      log "Found App Store receipt: $receipt_path"
      if confirm "Remove App Store receipt for this application?"; then
        backup_item "$receipt_path"
        run_command sudo rm -f "$receipt_path"
      fi
    fi
  fi
  
  # Second pass cleanup for stubborn leftovers
  cleanup_leftovers "$app_name" "$app_bundle_id"
  
  log "Application removal process completed for: $app_name"
}

# Find applications that haven't been used recently
find_unused_apps() {
  printf "\n${BLUE}--- Finding Unused Applications ---${NC}\n"
  
  # Ask for days threshold
  echo -n "Show applications not accessed in how many days? [30]: "
  read -r days
  days=${days:-30}  # Default to 30 days if empty
  
  local cutoff_date=$(date -v-${days}d +%s)
  local found_apps=0
  
  echo "Scanning for applications not accessed since $(date -r $cutoff_date)..."
  
  # Create a temporary file for results
  local temp_file=$(mktemp)
  echo "# Unused Applications Report - $(date)" > "$temp_file"
  echo "# Applications not accessed in $days days" >> "$temp_file"
  echo >> "$temp_file"
  
  # Scan Applications directories
  for dir in "/Applications" "$HOME/Applications"; do
    if [[ ! -d "$dir" ]]; then
      continue
    fi
    
    find "$dir" -maxdepth 2 -name "*.app" -type d -print0 2>/dev/null | 
    while IFS= read -r -d '' app; do
      # Get last accessed time in seconds since epoch
      local last_access=$(stat -f %a "$app")
      local app_name=$(basename "$app" .app)
      
      # Skip system apps
      if [[ "$dir" == "/Applications" && " ${system_apps[*]} " == *" ${app_name}.app "* ]]; then
        continue
      fi
      
      if [[ $last_access -lt $cutoff_date ]]; then
        # Get app size
        local size=$(du -sh "$app" | cut -f1)
        local last_access_date=$(date -r $last_access "+%Y-%m-%d %H:%M:%S")
        
        echo "$app ($size) - Last accessed: $last_access_date" >> "$temp_file"
        found_apps=$((found_apps + 1))
      fi
    done
  done
  
  if [[ $found_apps -eq 0 ]]; then
    log "No unused applications found."
    rm "$temp_file"
    return
  fi
  
  # Display results
  printf "\n${GREEN}Found $found_apps potentially unused applications:${NC}\n"
  cat "$temp_file" | grep -v "^#"
  
  # Offer to select an app to remove
  if confirm "Would you like to remove any of these applications?"; then
    remove_specific_app
  fi
  
  # Offer to save the report
  if confirm "Save this report to your Desktop?"; then
    cp "$temp_file" "$HOME/Desktop/unused_apps_report.txt"
    log "Report saved to $HOME/Desktop/unused_apps_report.txt"
  fi
  
  rm "$temp_file"
}

# Check for broken/corrupt app bundles
check_broken_apps() {
  printf "\n${BLUE}--- Checking for Broken App Bundles ---${NC}\n"
  
  # Create a temporary file for results
  local temp_file=$(mktemp)
  local found_broken=0
  
  for dir in "/Applications" "$HOME/Applications"; do
    if [[ ! -d "$dir" ]]; then
      continue
    fi
    
    find "$dir" -maxdepth 2 -name "*.app" -type d -print0 2>/dev/null | 
    while IFS= read -r -d '' app; do
      # Check for essential files
      if [[ ! -d "$app/Contents" || ! -d "$app/Contents/MacOS" || ! -f "$app/Contents/Info.plist" ]]; then
        echo "$app - Missing essential components" >> "$temp_file"
        found_broken=$((found_broken + 1))
        continue
      fi
      
      # Check Info.plist validity
      if ! plutil -lint "$app/Contents/Info.plist" >/dev/null 2>&1; then
        echo "$app - Invalid Info.plist" >> "$temp_file"
        found_broken=$((found_broken + 1))
        continue
      fi
      
      # Try to get main executable
      local exec_name=$(/usr/libexec/PlistBuddy -c "Print :CFBundleExecutable" "$app/Contents/Info.plist" 2>/dev/null)
      if [[ -n "$exec_name" && ! -f "$app/Contents/MacOS/$exec_name" ]]; then
        echo "$app - Missing main executable: $exec_name" >> "$temp_file"
        found_broken=$((found_broken + 1))
      fi
    done
  done
  
  if [[ $found_broken -eq 0 ]]; then
    log "No broken application bundles found."
    rm "$temp_file"
    return
  fi
  
  # Display results
  printf "\n${YELLOW}Found $found_broken potentially broken applications:${NC}\n"
  cat "$temp_file"
  
  # Offer to select an app to remove
  if confirm "Would you like to remove any of these broken applications?"; then
    remove_specific_app
  fi
  
  rm "$temp_file"
}

# Helper Function for finding and removing Associated Files
find_and_remove_associated_files() {
  local app_name="$1"
  local bundle_id="$2"
  
  printf "\n${BLUE}--- Finding Associated Files ---${NC}\n"
  
  local search_dirs=(
    "$HOME/Library/Preferences"
    "$HOME/Library/Application Support"
    "$HOME/Library/Caches"
    "$HOME/Library/Logs"
    "$HOME/Library/Saved Application State"
    "$HOME/Library/WebKit"
    "$HOME/Library/Cookies"
    "/Library/Preferences"
    "/Library/Application Support"
    "/Library/Caches"
    "/Library/Logs"
    "/Library/LaunchAgents"
    "$HOME/Library/LaunchAgents"
    "/Library/LaunchDaemons"
    "$HOME/Library/Containers"
    "$HOME/Library/Group Containers"
  )
  
  local search_patterns=("*$app_name*")
  
  # If we have a bundle ID, add it to search patterns
  if [[ -n "$bundle_id" ]]; then
    search_patterns+=("*$bundle_id*")
  fi
  
  # Create temp file for found items
  local found_file=$(mktemp)
  local found_count=0
  
  # Search for associated files
  for dir in "${search_dirs[@]}"; do
    if [[ ! -d "$dir" ]]; then
      continue
    fi
    
    for pattern in "${search_patterns[@]}"; do
      find "$dir" -iname "$pattern" -print0 2>/dev/null | 
      while IFS= read -r -d '' file; do
        # Skip if it's a directory and it contains other apps' data
        if [[ -d "$file" ]]; then
          # Check if directory contains non-matching items
          local non_matching=$(find "$file" -not -path "*$app_name*" -not -path "*$bundle_id*" | head -n1)
          if [[ -n "$non_matching" && ! $file == *"/Contents"* ]]; then
            # Better approach - instead of hardcoding app names, check if the directory 
            # is specifically named after the app or likely related to it
            
            # Convert to lowercase for case-insensitive comparison
            local file_basename=$(basename "$file" | tr '[:upper:]' '[:lower:]')
            local app_name_lower=$(echo "$app_name" | tr '[:upper:]' '[:lower:]')
            
            # Case 1: Directory name exactly matches app name (case insensitive)
            if [[ "$file_basename" == "$app_name_lower" ]]; then
              echo "$file" >> "$found_file"
              found_count=$((found_count + 1))
              continue
            fi
            
            # Case 2: Directory name contains app name as a whole word
            if [[ "$file_basename" == *"-$app_name_lower"* || 
                  "$file_basename" == *"$app_name_lower-"* || 
                  "$file_basename" == *"_$app_name_lower"* || 
                  "$file_basename" == *"$app_name_lower_"* ]]; then
              echo "$file" >> "$found_file"
              found_count=$((found_count + 1))
              continue
            fi
            
            # Case 3: Directory is in a standard application support location and named after the app
            if [[ "$file" == *"/Library/Application Support/$app_name"* || 
                  "$file" == *"/Library/Application Support/"*"$app_name"* ||
                  "$file" == *"/Library/Caches/$app_name"* || 
                  "$file" == *"/Library/Caches/"*"$app_name"* ||
                  "$file" == *"/Library/Logs/$app_name"* || 
                  "$file" == *"/Library/Logs/"*"$app_name"* ||
                  "$file" == *"/Library/Preferences/$app_name"* ||
                  "$file" == *"/Library/Preferences/"*"$app_name"* ||
                  "$file" == *"/Library/Containers/$app_name"* ||
                  "$file" == *"/Library/Containers/"*"$app_name"* ||
                  "$file" == *"/Library/WebKit/$app_name"* ||
                  "$file" == *"/Library/Saved Application State/$app_name"* ||
                  "$file" == *"/Library/Application Scripts/$app_name"* ||
                  "$file" == *"/Library/Group Containers/"*"$app_name"* ]]; then
              echo "$file" >> "$found_file"
              found_count=$((found_count + 1))
              continue
            fi
            
            # Case 4: For bundle ID-based directories
            if [[ -n "$bundle_id" && 
                  ("$file" == *"$bundle_id"* || 
                   "$file" == *"$(echo "$bundle_id" | tr '.' '/')"*) ]]; then
              echo "$file" >> "$found_file"
              found_count=$((found_count + 1))
              continue
            fi
            
            # Skip directory with truly mixed content
            log --debug "Skipping directory with mixed content: $file"
            continue
          fi
        fi
        
        echo "$file" >> "$found_file"
        found_count=$((found_count + 1))
      done
    done
  done
  
  if [[ $found_count -eq 0 ]]; then
    log "No associated files found for $app_name."
    rm "$found_file"
    return
  fi
  
  # Sort and deduplicate results
  sort -u "$found_file" > "${found_file}.sorted"
  mv "${found_file}.sorted" "$found_file"
  
  # Display findings
  printf "\n${GREEN}Found $found_count associated files:${NC}\n"
  
  # Display with numbers for selection
  cat -n "$found_file"
  
  printf "\nOptions:\n"
  echo "1. Remove all files"
  echo "2. Select files to remove"
  echo "3. Skip file removal"
  echo -n "Select an option: "
  read -r file_choice
  
  case "$file_choice" in
    1)  # Remove all files
      while IFS= read -r file; do
        backup_item "$file"
        run_command sudo rm -rf "$file"
      done < "$found_file"
      log "Removed all $found_count associated files."
      ;;
    2)  # Select files
      echo "Enter file numbers to remove (space-separated, e.g., '1 3 5'), or 'all' for all:"
      read -r selections
      
      if [[ "$selections" == "all" ]]; then
        while IFS= read -r file; do
          backup_item "$file"
          run_command sudo rm -rf "$file"
        done < "$found_file"
        log "Removed all $found_count associated files."
      else
        # Process selected files
        for num in $selections; do
          if [[ "$num" =~ ^[0-9]+$ ]]; then
            local file=$(sed -n "${num}p" "$found_file")
            if [[ -n "$file" ]]; then
              backup_item "$file"
              run_command sudo rm -rf "$file"
              log "Removed: $file"
            fi
          fi
        done
      fi
      ;;
    3|*)  # Skip
      log "Skipping file removal."
      ;;
  esac
  
  rm "$found_file"
}

# Enhanced function for removing launch agents and daemons
remove_launch_agents() {
  local app_name="$1"
  local bundle_id="$2"
  
  printf "\n${BLUE}--- Managing Launch Agents ---${NC}\n"
  
  local launch_dirs=(
    "$HOME/Library/LaunchAgents"
    "/Library/LaunchAgents"
    "/Library/LaunchDaemons"
  )
  
  local search_patterns=("*$app_name*.plist")
  
  # If we have a bundle ID, add it to search patterns
  if [[ -n "$bundle_id" ]]; then
    search_patterns+=("*$bundle_id*.plist")
  fi
  
  local found_count=0
  local found_file=$(mktemp)
  
  for dir in "${launch_dirs[@]}"; do
    if [[ ! -d "$dir" ]]; then
      continue
    fi
    
    for pattern in "${search_patterns[@]}"; do
      find "$dir" -iname "$pattern" -print0 2>/dev/null | 
      while IFS= read -r -d '' plist; do
        # Check if it's loaded
        local is_loaded=0
        local label=$(/usr/libexec/PlistBuddy -c "Print :Label" "$plist" 2>/dev/null)
        
        if [[ -n "$label" ]]; then
          if [[ "$dir" == *"LaunchDaemons"* ]]; then
            sudo launchctl list "$label" >/dev/null 2>&1 && is_loaded=1
          else
            launchctl list "$label" >/dev/null 2>&1 && is_loaded=1
          fi
          
          echo "$plist ($([ $is_loaded -eq 1 ] && echo 'active' || echo 'inactive'))" >> "$found_file"
          found_count=$((found_count + 1))
        else
          echo "$plist (unknown status)" >> "$found_file"
          found_count=$((found_count + 1))
        fi
      done
    done
  done
  
  if [[ $found_count -eq 0 ]]; then
    log "No launch agents or daemons found for $app_name."
    rm "$found_file"
    return
  fi
  
  # Display findings
  printf "\n${GREEN}Found $found_count launch agents/daemons:${NC}\n"
  cat -n "$found_file"
  
  if ! confirm "Would you like to unload and remove these launch agents?"; then
    rm "$found_file"
    return
  fi
  
  # Unload and remove each found launch agent
  while IFS= read -r line; do
    local plist=$(echo "$line" | awk '{print $1}')
    local label=$(/usr/libexec/PlistBuddy -c "Print :Label" "$plist" 2>/dev/null)
    
    # Backup before removal
    backup_item "$plist"
    
    # Unload if it's loaded
    if [[ "$line" == *"(active)"* ]]; then
      log "Unloading: $label"
      if [[ "$plist" == *"LaunchDaemons"* ]]; then
        run_command sudo launchctl unload -w "$plist"
      else
        run_command launchctl unload -w "$plist"
      fi
    fi
    
    # Remove the plist
    log "Removing: $plist"
    run_command sudo rm -f "$plist"
    
  done < "$found_file"
  
  log "Launch agents cleanup completed."
  rm "$found_file"
}

# Function to remove app from login items
remove_login_items() {
  local app_name="$1"
  
  printf "\n${BLUE}--- Checking Login Items ---${NC}\n"
  
  # Check if app is in login items
  local login_items=$(osascript -e 'tell application "System Events" to get the name of every login item' 2>/dev/null)
  
  if [[ "$login_items" == *"$app_name"* ]]; then
    log "Found '$app_name' in login items."
    
    if confirm "Remove '$app_name' from login items?"; then
      osascript -e "tell application \"System Events\" to delete login item \"$app_name\"" 2>/dev/null
      log "Removed '$app_name' from login items."
    fi
  else
    log "Application not found in login items."
  fi
}

# Second-pass cleanup to find and remove stubborn leftovers
cleanup_leftovers() {
  local app_name="$1"
  local bundle_id="$2"
  
  printf "\n${BLUE}--- Finding Leftover Files (Second Pass) ---${NC}\n"
  
  # Specifically look in common locations where app leftovers might remain
  local leftover_dirs=(
    "/Applications"
    "$HOME/Applications"
    "$HOME/Library/Application Support"
    "/Library/Application Support"
    "$HOME/Library/Caches"
    "/Library/Caches"
    "$HOME/Library/Preferences"
    "/Library/Preferences"
    "$HOME/Library/LaunchAgents"
    "/Library/LaunchAgents"
    "/Library/LaunchDaemons"
    "$HOME/Library/Containers"
    "$HOME/Library/Group Containers"
    "$HOME/Library/Saved Application State"
  )
  
  # Convert app name to lowercase for case-insensitive matching
  local app_name_lower=$(echo "$app_name" | tr '[:upper:]' '[:lower:]')
  
  # Create temp file for found leftovers
  local leftovers_file=$(mktemp)
  local found_count=0
  
  # Direct search for app directory in Application Support
  # This is the most explicit and targeted approach for directories like "/Application Support/Claude/"
  if [[ -d "$HOME/Library/Application Support/$app_name" ]]; then
    echo "$HOME/Library/Application Support/$app_name" >> "$leftovers_file"
    found_count=$((found_count + 1))
  fi
  
  # Try with lowercase name as well
  if [[ -d "$HOME/Library/Application Support/$(echo "$app_name" | tr '[:upper:]' '[:lower:]')" ]]; then
    echo "$HOME/Library/Application Support/$(echo "$app_name" | tr '[:upper:]' '[:lower:]')" >> "$leftovers_file"
    found_count=$((found_count + 1))
  fi
  
  # Force more aggressive search patterns
  for dir in "${leftover_dirs[@]}"; do
    if [[ ! -d "$dir" ]]; then
      continue
    fi
    
    # Look for exact directory matches first (case insensitive)
    find "$dir" -type d -depth 1 2>/dev/null | while read -r item; do
      local item_basename=$(basename "$item" | tr '[:upper:]' '[:lower:]')
      
      # Exact match
      if [[ "$item_basename" == "$app_name_lower" || "$item_basename" == "${app_name_lower}.app" ]]; then
        echo "$item" >> "$leftovers_file"
        found_count=$((found_count + 1))
      # Partial/related match
      elif [[ "$item_basename" == *"$app_name_lower"* || 
              "$item_basename" == *"$(echo "$app_name_lower" | tr -d ' ')"* ]]; then
        # Verify it's likely related to our app
        if [[ ! -d "$item/Contents" || "$item" == *"/Application Support/"* || "$item" == *"/Caches/"* ]]; then
          echo "$item" >> "$leftovers_file"
          found_count=$((found_count + 1))
        fi
      fi
    done
    
    # For Application Support particularly, search more aggressively
    if [[ "$dir" == *"/Application Support" ]]; then
      # Use find with -name for better control
      find "$dir" -type d -name "*$app_name*" 2>/dev/null | while read -r item; do
        echo "$item" >> "$leftovers_file"
        found_count=$((found_count + 1))
      done
      
      # Try lowercase variations
      find "$dir" -type d -name "*$(echo "$app_name" | tr '[:upper:]' '[:lower:]')*" 2>/dev/null | while read -r item; do
        echo "$item" >> "$leftovers_file"
        found_count=$((found_count + 1))
      done
      
      # Also try without spaces
      find "$dir" -type d -name "*$(echo "$app_name" | tr -d ' ')*" 2>/dev/null | while read -r item; do
        echo "$item" >> "$leftovers_file"
        found_count=$((found_count + 1))
      done
      
      # Also look for bundle ID leftovers in Application Support
      if [[ -n "$bundle_id" ]]; then
        find "$dir" -type d -path "*$bundle_id*" 2>/dev/null | while read -r item; do
          echo "$item" >> "$leftovers_file"
          found_count=$((found_count + 1))
        done
      fi
    fi
  done
  
  # Special handling for browser stored data for web apps
  cleanup_browser_data "$app_name"
  
  # Special handling for bundle ID based folders in Library
  if [[ -n "$bundle_id" ]]; then
    # Convert bundle ID to possible directory path (com.example.app -> com/example/app)
    local bundle_path=$(echo "$bundle_id" | tr '.' '/')
    
    for dir in "${leftover_dirs[@]}"; do
      if [[ ! -d "$dir" ]]; then
        continue
      fi
      
      find "$dir" -type d -path "*$bundle_path*" 2>/dev/null | while read -r item; do
        echo "$item" >> "$leftovers_file"
        found_count=$((found_count + 1))
      done
    done
  fi
  
  # Sort and deduplicate results
  if [[ $found_count -gt 0 ]]; then
    sort -u "$leftovers_file" > "${leftovers_file}.sorted"
    mv "${leftovers_file}.sorted" "$leftovers_file"
    
    # Get final count
    found_count=$(wc -l < "$leftovers_file")
    
    # Display findings
    printf "\n${YELLOW}Found $found_count potential leftover files/directories:${NC}\n"
    cat -n "$leftovers_file"
    
    if confirm "Would you like to remove these leftover files?"; then
      while IFS= read -r file; do
        backup_item "$file"
        run_command sudo rm -rf "$file"
        log "Removed leftover: $file"
      done < "$leftovers_file"
      log "Leftover cleanup completed."
    else
      log "Skipping leftover removal."
    fi
  else
    log "No leftover files found."
  fi
  
  rm -f "$leftovers_file"
}

# Function to clean up browser storage related to the app
cleanup_browser_data() {
  local app_name="$1"
  local app_name_lower=$(echo "$app_name" | tr '[:upper:]' '[:lower:]')
  
  printf "\n${BLUE}--- Checking Browser Data ---${NC}\n"
  
  local browsers_dir=(
    "$HOME/Library/Application Support/Google/Chrome"
    "$HOME/Library/Application Support/Google/Chrome Beta"
    "$HOME/Library/Application Support/Google/Chrome Dev"
    "$HOME/Library/Application Support/Google/Chrome Canary"
    "$HOME/Library/Application Support/Chromium"
    "$HOME/Library/Application Support/BraveSoftware/Brave-Browser"
    "$HOME/Library/Application Support/Microsoft Edge"
    "$HOME/Library/Application Support/Firefox/Profiles"
    "$HOME/Library/Safari"
  )
  
  local browser_data_file=$(mktemp)
  local found_count=0
  
  # For each browser directory
  for browser_dir in "${browsers_dir[@]}"; do
    if [[ ! -d "$browser_dir" ]]; then
      continue
    fi
    
    # Different handling for Firefox which has a different structure
    if [[ "$browser_dir" == *"Firefox/Profiles"* ]]; then
      # Find in Firefox profile storage
      find "$browser_dir" -type d -path "*storage*" -name "*$app_name_lower*" 2>/dev/null | while read -r item; do
        echo "$item" >> "$browser_data_file"
        found_count=$((found_count + 1))
      done
    else
      # For Chrome-based browsers
      find "$browser_dir" -type d -path "*IndexedDB*$app_name_lower*" 2>/dev/null | while read -r item; do
        echo "$item" >> "$browser_data_file"
        found_count=$((found_count + 1))
      done
      
      find "$browser_dir" -type d -path "*Local Storage*$app_name_lower*" 2>/dev/null | while read -r item; do
        echo "$item" >> "$browser_data_file"
        found_count=$((found_count + 1))
      done
      
      find "$browser_dir" -type d -path "*Service Worker*$app_name_lower*" 2>/dev/null | while read -r item; do
        echo "$item" >> "$browser_data_file"
        found_count=$((found_count + 1))
      done
    fi
  done
  
  if [[ $found_count -gt 0 ]]; then
    # Display findings
    printf "\n${YELLOW}Found $found_count browser data items related to $app_name:${NC}\n"
    cat -n "$browser_data_file"
    
    if confirm "Would you like to remove browser data for $app_name?"; then
      while IFS= read -r file; do
        backup_item "$file"
        run_command rm -rf "$file"
        log "Removed browser data: $file"
      done < "$browser_data_file"
      log "Browser data cleanup completed."
    else
      log "Skipping browser data removal."
    fi
  else
    log "No browser data found for $app_name."
  fi
  
  rm -f "$browser_data_file"
} 