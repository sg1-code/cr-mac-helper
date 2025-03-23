#!/bin/bash

# cache_cleanup.sh - Cache and temporary file management functions

# Main cache cleanup function
cache_temp_cleanup() {
  echo -e "\n${BLUE}=== Cache and Temp File Management ===${NC}"
  check_privileges 1  # Recommend elevated privileges
  
  # Menu for cache management options
  echo "1. Clean user application caches"
  echo "2. Clean system caches (requires sudo)"
  echo "3. Clean temporary files"
  echo "4. Clean browser caches"
  echo "5. Clean development build artifacts"
  echo "6. Return to main menu"
  echo -n "Select an option: "
  read -r cache_choice
  
  case "$cache_choice" in
    1) clean_user_caches ;;
    2) clean_system_caches ;;
    3) clean_temp_files ;;
    4) clean_browser_caches ;;
    5) clean_dev_artifacts ;;
    6) return ;;
    *) log --warn "Invalid choice. Returning to main menu."; return ;;
  esac
}

# Clean user application caches
clean_user_caches() {
  echo -e "\n${BLUE}--- Cleaning User Application Caches ---${NC}"
  
  # Calculate current cache size
  local cache_size=$(du -sh "$HOME/Library/Caches" 2>/dev/null | cut -f1)
  log "Current user cache size: $cache_size"
  
  # Get top space users
  log "Top cache space users:"
  du -sh "$HOME/Library/Caches"/* 2>/dev/null | sort -hr | head -n 5
  
  if ! confirm "Clean user application caches?"; then
    return
  fi
  
  # Backup selective caches instead of everything (which could be huge)
  if confirm "Create backup of cache directories? (Can be large)"; then
    backup_item "$HOME/Library/Caches"
  fi
  
  # Options for cleaning
  echo "1. Clean all user caches"
  echo "2. Clean selected caches only"
  echo -n "Select an option: "
  read -r uc_choice
  
  case "$uc_choice" in
    1)
      # Clean all caches with safety checks
      log "Cleaning all user caches..."
      
      # Find processes using cache files
      local using_procs=$(lsof +D "$HOME/Library/Caches" 2>/dev/null | awk '{print $1}' | sort -u | tr '\n' ' ')
      
      if [[ -n "$using_procs" ]]; then
        log --warn "These processes are currently using cache files: $using_procs"
        if ! confirm "Continue anyway? (Some apps may need to be restarted)"; then
          return
        fi
      fi
      
      # Clean caches with safety exclusions
      find "$HOME/Library/Caches" -depth 1 -not -name "com.apple.*" -print0 | 
      while IFS= read -r -d '' item; do
        # Skip critical cache directories
        if [[ "$item" == *"Metadata"* || "$item" == *"CloudKit"* || "$item" == *"com.apple.Safari"* ]]; then
          log --debug "Skipping critical cache: $item"
          continue
        fi
        run_command rm -rf "$item"
      done
      
      # Special handling for Safari cache (don't wipe cookies/data)
      if [[ -d "$HOME/Library/Caches/com.apple.Safari" ]]; then
        find "$HOME/Library/Caches/com.apple.Safari" -name "Cache.db*" -print0 |
        while IFS= read -r -d '' cache_file; do
          run_command rm -f "$cache_file"
        done
      fi
      ;;
    2)
      # List top caches for selection
      local temp_file=$(mktemp)
      du -sh "$HOME/Library/Caches"/* 2>/dev/null | sort -hr | head -n 20 > "$temp_file"
      
      echo "Top cache directories:"
      cat -n "$temp_file"
      
      echo "Enter numbers of caches to clean (space-separated, e.g., '1 3 5'), or 'all' for all listed:"
      read -r selections
      
      if [[ "$selections" == "all" ]]; then
        while IFS= read -r line; do
          local dir=$(echo "$line" | awk '{print $2}')
          log "Cleaning: $dir"
          run_command rm -rf "$dir"
        done < "$temp_file"
      else
        for num in $selections; do
          if [[ "$num" =~ ^[0-9]+$ ]]; then
            local line=$(sed -n "${num}p" "$temp_file")
            local dir=$(echo "$line" | awk '{print $2}')
            if [[ -n "$dir" ]]; then
              log "Cleaning: $dir"
              run_command rm -rf "$dir"
            fi
          fi
        done
      fi
      
      rm "$temp_file"
      ;;
    *)
      log "No caches cleaned."
      return
      ;;
  esac
  
  # Final size calculation
  local new_cache_size=$(du -sh "$HOME/Library/Caches" 2>/dev/null | cut -f1)
  log "New user cache size: $new_cache_size (was $cache_size)"
}

# Clean system caches with thorough safety checks
clean_system_caches() {
  echo -e "\n${BLUE}--- Cleaning System Caches ---${NC}"
  
  # Check if running with sudo
  if [[ $EUID -ne 0 ]]; then
    log --warn "This operation requires root privileges."
    if ! confirm "Attempt to run with sudo?"; then
      return
    fi
  fi
  
  # Show detailed warning
  echo -e "${RED}WARNING: Cleaning system caches can affect system stability.${NC}"
  echo -e "${RED}This is a high-risk operation and should be performed with caution.${NC}"
  echo -e "${RED}Do NOT clean system caches before important work or presentations.${NC}"
  
  if ! confirm "I understand the risks and want to proceed with cleaning system caches"; then
    return
  fi
  
  # Calculate current cache size
  local system_cache_size=$(sudo du -sh /Library/Caches 2>/dev/null | cut -f1)
  log "Current system cache size: $system_cache_size"
  
  # Backup system caches (important)
  if confirm "Create backup of system caches before cleaning? (Recommended)"; then
    backup_item "/Library/Caches"
  fi
  
  # Safety list of directories NOT to clean
  local safety_list=(
    "/Library/Caches/com.apple.cachedelete"
    "/Library/Caches/com.apple.coresymbolicationd"
    "/Library/Caches/com.apple.kext.caches"
    "/Library/Caches/com.apple.bootstamps"
    "/Library/Caches/com.apple.dyld"
    "/Library/Caches/Metadata"
    "/Library/Caches/com.apple.restored"
  )
  
  # Clean system caches with exclusions
  log "Cleaning system caches (excluding critical system files)..."
  find "/Library/Caches" -depth 1 -print0 2>/dev/null | 
  while IFS= read -r -d '' cache_dir; do
    # Check if this is a safety-listed directory
    local skip=0
    for safe_dir in "${safety_list[@]}"; do
      if [[ "$cache_dir" == "$safe_dir" ]]; then
        log --debug "Skipping critical system cache: $cache_dir"
        skip=1
        break
      fi
    done
    
    if [[ $skip -eq 1 ]]; then
      continue
    fi
    
    # Clean other caches
    log "Cleaning: $cache_dir"
    run_command sudo rm -rf "$cache_dir"
  done
  
  log "System cache cleaning completed."
  
  # Final size calculation
  local new_system_cache_size=$(sudo du -sh /Library/Caches 2>/dev/null | cut -f1)
  log "New system cache size: $new_system_cache_size (was $system_cache_size)"
  
  # Flush DNS cache
  if confirm "Flush DNS cache?"; then
    run_command sudo dscacheutil -flushcache
    run_command sudo killall -HUP mDNSResponder
    log "DNS cache flushed."
  fi
}

# Clean temporary files
clean_temp_files() {
  echo -e "\n${BLUE}--- Cleaning Temporary Files ---${NC}"
  
  local tmp_dirs=(
    "/tmp"
    "$TMPDIR"
    "$HOME/Library/Logs"
    "$HOME/Downloads"
  )
  
  # Show temporary directory sizes
  echo "Current temporary directory sizes:"
  for dir in "${tmp_dirs[@]}"; do
    if [[ -d "$dir" ]]; then
      du -sh "$dir" 2>/dev/null
    fi
  done
  
  # Options menu
  echo "Select which temporary files to clean:"
  echo "1. Clean system /tmp directory (files older than 3 days)"
  echo "2. Clean user TMPDIR (files older than 3 days)"
  echo "3. Clean log files (files older than 7 days)"
  echo "4. Organize Downloads folder"
  echo "5. All of the above"
  echo "6. Return to cache menu"
  echo -n "Select an option: "
  read -r tmp_choice
  
  case "$tmp_choice" in
    1) clean_system_tmp ;;
    2) clean_user_tmp ;;
    3) clean_logs ;;
    4) organize_downloads ;;
    5) 
      clean_system_tmp
      clean_user_tmp
      clean_logs
      organize_downloads
      ;;
    6|*) return ;;
  esac
}

# Helper to clean system tmp directory
clean_system_tmp() {
  if confirm "Clean system /tmp directory (files older than 3 days)?"; then
    log "Cleaning system /tmp directory..."
    if [[ $EUID -ne 0 ]]; then
      log --warn "Using sudo for /tmp cleanup"
      run_command sudo find /tmp -type f -mtime +3 -print0 | xargs -0 sudo rm -f 2>/dev/null
      run_command sudo find /tmp -type d -mtime +3 -empty -print0 | xargs -0 sudo rmdir 2>/dev/null
    else
      run_command find /tmp -type f -mtime +3 -print0 | xargs -0 rm -f 2>/dev/null
      run_command find /tmp -type d -mtime +3 -empty -print0 | xargs -0 rmdir 2>/dev/null
    fi
    log "System /tmp directory cleaned."
  fi
}

# Clean user temporary directory
clean_user_tmp() {
  if confirm "Clean user temporary directory (files older than 3 days)?"; then
    log "Cleaning user temporary directory..."
    run_command find "$TMPDIR" -type f -mtime +3 -print0 | xargs -0 rm -f 2>/dev/null
    run_command find "$TMPDIR" -type d -mtime +3 -empty -print0 | xargs -0 rmdir 2>/dev/null
    log "User temporary directory cleaned."
  fi
}

# Clean log files
clean_logs() {
  if confirm "Clean log files older than 7 days?"; then
    log "Cleaning log files..."
    run_command find "$HOME/Library/Logs" -type f -mtime +7 -print0 | xargs -0 rm -f 2>/dev/null
    log "Log files cleaned."
  fi
}

# Organize downloads folder
organize_downloads() {
  if confirm "Organize Downloads folder?"; then
    local downloads_dir="$HOME/Downloads"
    
    if [[ ! -d "$downloads_dir" ]]; then
      log --warn "Downloads directory not found."
      return
    fi
    
    log "Organizing Downloads folder..."
    
    # Create category directories
    local categories=(
      "Images" "Documents" "Archives" "Videos" "Audio" "Applications" "Other"
    )
    
    for category in "${categories[@]}"; do
      if [[ ! -d "$downloads_dir/$category" ]]; then
        run_command mkdir -p "$downloads_dir/$category"
      fi
    done
    
    # Move files to appropriate directories
    local file_count=0
    
    # Process files directly in the Downloads directory (not in subdirectories)
    find "$downloads_dir" -type f -maxdepth 1 -print0 | 
    while IFS= read -r -d '' file; do
      local filename=$(basename "$file")
      local ext="${filename##*.}"
      local target_dir=""
      
      case $(echo "$ext" | tr '[:upper:]' '[:lower:]') in
        jpg|jpeg|png|gif|bmp|svg|tiff|webp)
          target_dir="$downloads_dir/Images" ;;
        pdf|doc|docx|txt|rtf|odt|pages|md|xls|xlsx|csv|ppt|pptx|key|numbers)
          target_dir="$downloads_dir/Documents" ;;
        zip|rar|tar|gz|7z|bz2|xz|tgz)
          target_dir="$downloads_dir/Archives" ;;
        mp4|avi|mov|wmv|flv|mkv|m4v|webm)
          target_dir="$downloads_dir/Videos" ;;
        mp3|wav|ogg|flac|aac|m4a)
          target_dir="$downloads_dir/Audio" ;;
        app|dmg|pkg|exe|msi|deb|rpm)
          target_dir="$downloads_dir/Applications" ;;
        *)
          target_dir="$downloads_dir/Other" ;;
      esac
      
      if [[ -n "$target_dir" && "$file" != "$target_dir"* ]]; then
        run_command mv "$file" "$target_dir/"
        file_count=$((file_count + 1))
      fi
    done
    
    log "Organized $file_count files in Downloads folder."
    
    # Offer to show old downloads
    if confirm "Would you like to see downloads older than 30 days?"; then
      echo "Downloads older than 30 days:"
      find "$downloads_dir" -type f -mtime +30 -print0 | 
      while IFS= read -r -d '' old_file; do
        local mod_time=$(stat -f "%Sm" -t "%Y-%m-%d" "$old_file")
        echo "$(basename "$old_file") - Last modified: $mod_time"
      done
      
      if confirm "Would you like to archive old downloads older than 30 days?"; then
        local archive_dir="$downloads_dir/Archives/OldDownloads_$(date +%Y%m%d)"
        run_command mkdir -p "$archive_dir"
        
        find "$downloads_dir" -type f -mtime +30 -print0 | 
        while IFS= read -r -d '' old_file; do
          if [[ "$old_file" != "$archive_dir"* ]]; then
            run_command mv "$old_file" "$archive_dir/"
          fi
        done
        
        log "Old downloads archived to $archive_dir"
      fi
    fi
  fi
}

# Clean browser caches
clean_browser_caches() {
  echo -e "\n${BLUE}--- Cleaning Browser Caches ---${NC}"
  
  # First close browsers
  local browsers_running=0
  for browser in "Safari" "Firefox" "Google Chrome" "Chromium" "Opera" "Microsoft Edge" "Brave Browser"; do
    if pgrep -x "$browser" > /dev/null; then
      browsers_running=1
      break
    fi
  done
  
  if [[ $browsers_running -eq 1 ]]; then
    log --warn "Browsers are currently running."
    if confirm "Close all browsers before proceeding?"; then
      for browser in "Safari" "Firefox" "Google Chrome" "Chromium" "Opera" "Microsoft Edge" "Brave Browser"; do
        osascript -e "tell application \"$browser\" to quit" 2>/dev/null
      done
      sleep 2
    else
      log --warn "Some browser caches may not be fully cleaned if browsers are running."
    fi
  fi
  
  # Display browser options
  echo "Select browsers to clean:"
  echo "1. Safari"
  echo "2. Google Chrome"
  echo "3. Firefox"
  echo "4. Microsoft Edge"
  echo "5. Brave"
  echo "6. All browsers"
  echo "7. Return to cache menu"
  echo -n "Select an option: "
  read -r browser_choice
  
  case "$browser_choice" in
    1) clean_safari ;;
    2) clean_chrome ;;
    3) clean_firefox ;;
    4) clean_edge ;;
    5) clean_brave ;;
    6) 
      clean_safari
      clean_chrome
      clean_firefox
      clean_edge
      clean_brave
      ;;
    7|*) return ;;
  esac
}

# (Other browser-specific cleaning functions would be implemented here)

# Clean development build artifacts
clean_dev_artifacts() {
  echo -e "\n${BLUE}--- Cleaning Development Build Artifacts ---${NC}"
  
  # Detect development environments
  local dev_dirs=(
    "$HOME/node_modules"
    "$HOME/.gradle"
    "$HOME/.m2"
    "$HOME/.ivy2"
    "$HOME/.sbt"
    "$HOME/Library/Developer/Xcode/DerivedData"
    "$HOME/Library/Developer/Xcode/iOS DeviceSupport"
    "$HOME/Library/Developer/Xcode/Archives"
    "$HOME/Library/Caches/CocoaPods"
    "$HOME/.cocoapods"
    "$HOME/.npm"
    "$HOME/.yarn-cache"
    "$HOME/.pub-cache"
    "$HOME/go/pkg"
    "$HOME/.cargo/registry"
  )
  
  # Check which ones exist and calculate sizes
  local found_dirs=()
  local dir_sizes=()
  
  for dir in "${dev_dirs[@]}"; do
    if [[ -d "$dir" ]]; then
      found_dirs+=("$dir")
      dir_sizes+=("$(du -sh "$dir" 2>/dev/null | cut -f1)")
    fi
  done
  
  if [[ ${#found_dirs[@]} -eq 0 ]]; then
    log "No development artifact directories found."
    return
  fi
  
  # Display results with sizes
  echo "Found the following development artifact directories:"
  for i in "${!found_dirs[@]}"; do
    echo "$((i+1)). ${found_dirs[$i]} (${dir_sizes[$i]})"
  done
  
  echo "Select directories to clean (space-separated, e.g., '1 3 5'), 'all' for all, or 0 to cancel:"
  read -r selections
  
  if [[ "$selections" == "0" ]]; then
    return
  elif [[ "$selections" == "all" ]]; then
    for dir in "${found_dirs[@]}"; do
      clean_dev_directory "$dir"
    done
  else
    for num in $selections; do
      if [[ "$num" =~ ^[0-9]+$ && $num -le ${#found_dirs[@]} ]]; then
        clean_dev_directory "${found_dirs[$num-1]}"
      fi
    done
  fi
}

# Helper to clean a development directory
clean_dev_directory() {
  local dir="$1"
  local name=$(basename "$dir")
  
  if [[ ! -d "$dir" ]]; then
    log --warn "Directory does not exist: $dir"
    return
  fi
  
  # Specific handling based on directory type
  case "$name" in
    "node_modules")
      if confirm "Clean all node_modules directories in your user folder?"; then
        log "Searching for node_modules directories..."
        find "$HOME" -type d -name "node_modules" -print0 2>/dev/null | 
        while IFS= read -r -d '' node_dir; do
          if [[ "$node_dir" == "$HOME/node_modules" ]]; then
            log "Cleaning: $node_dir"
            run_command rm -rf "$node_dir"
          else
            local parent_dir=$(dirname "$node_dir")
            if [[ -f "$parent_dir/package.json" ]]; then
              log "Cleaning: $node_dir"
              run_command rm -rf "$node_dir"
            fi
          fi
        done
      fi
      ;;
    "DerivedData")
      log "Cleaning Xcode DerivedData..."
      run_command rm -rf "$dir"/*
      ;;
    *)
      if confirm "Clean $dir?"; then
        log "Cleaning: $dir"
        run_command rm -rf "$dir"/*
      fi
      ;;
  esac
  
  # Recheck size
  if [[ -d "$dir" ]]; then
    local new_size=$(du -sh "$dir" 2>/dev/null | cut -f1)
    log "New size of $dir: $new_size"
  else
    log "Directory removed: $dir"
  fi
}