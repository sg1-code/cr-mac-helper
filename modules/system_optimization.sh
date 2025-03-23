#!/bin/bash

# system_optimization.sh - System optimization functions

# Main system optimization function
system_optimization() {
  echo -e "\n${BLUE}=== System Optimization ===${NC}"
  check_privileges 1  # Recommend elevated privileges
  
  echo "1. Clear system swap files"
  echo "2. Optimize system animations"
  echo "3. Optimize application launch times"
  echo "4. Purge inactive memory"
  echo "5. Return to main menu"
  echo -n "Select an option: "
  read -r opt_choice
  
  case "$opt_choice" in
    1) clear_swap ;;
    2) optimize_animations ;;
    3) optimize_app_launch ;;
    4) purge_memory ;;
    5) return ;;
    *) log --warn "Invalid choice. Returning to main menu."; return ;;
  esac
}

# Clear system swap files
clear_swap() {
  echo -e "\n${BLUE}--- Clearing System Swap Files ---${NC}"
  
  # Check if running as root
  if [[ $EUID -ne 0 ]]; then
    log --warn "This operation requires root privileges."
    if ! confirm "Attempt to run with sudo?"; then
      return
    fi
  fi
  
  log "This will clear swap files and inactive memory to potentially improve system performance."
  log "Note: This operation might temporarily freeze your system for a few seconds."
  
  if ! confirm "Continue with clearing swap files?"; then
    return
  fi
  
  # Check current swap usage
  log "Current swap usage:"
  run_command sysctl vm.swapusage
  
  # Clear the swap files and inactive memory
  if [[ $DRY_RUN -eq 1 ]]; then
    log "DRY RUN: Would execute: sudo purge"
  else
    log "Clearing inactive memory and swap files..."
    run_command sudo purge
    
    # Dynamic pager is the macOS service that manages swap files
    log "Stopping and restarting the dynamic pager..."
    run_command sudo launchctl unload -w /System/Library/LaunchDaemons/com.apple.dynamic_pager.plist
    
    # Delete swap files
    log "Removing existing swap files..."
    run_command sudo rm -rf /private/var/vm/swapfile*
    
    # Restart dynamic pager
    log "Restarting dynamic pager service..."
    run_command sudo launchctl load -w /System/Library/LaunchDaemons/com.apple.dynamic_pager.plist
    
    # Check new swap usage
    log "New swap usage:"
    run_command sysctl vm.swapusage
    
    log "Swap files have been cleared and recreated."
  fi
  
  echo
  read -n 1 -s -r -p "Press any key to continue..."
}

# Optimize system animations
optimize_animations() {
  echo -e "\n${BLUE}--- Optimizing System Animations ---${NC}"
  
  log "This will adjust system animation settings to optimize performance."
  log "You can choose between different optimization levels."
  
  echo "1. Subtle optimization (faster animations)"
  echo "2. Medium optimization (minimal animations)"
  echo "3. Maximum optimization (disable most animations)"
  echo "4. Restore default animations"
  echo -n "Select an option: "
  read -r anim_choice
  
  # Create backup of current settings if needed
  if [[ ! -f "$BACKUP_DIR/com.apple.dock.plist.bak" && -f "$HOME/Library/Preferences/com.apple.dock.plist" ]]; then
    backup_item "$HOME/Library/Preferences/com.apple.dock.plist"
  fi
  
  case "$anim_choice" in
    1)  # Subtle optimization
      log "Applying subtle animation optimizations..."
      
      if [[ $DRY_RUN -eq 1 ]]; then
        log "DRY RUN: Would optimize animation speed and reduce transparency"
      else
        # Speed up animations
        run_command defaults write com.apple.dock autohide-time-modifier -float 0.4
        run_command defaults write com.apple.dock autohide-delay -float 0.1
        run_command defaults write NSGlobalDomain NSWindowResizeTime -float 0.1
        
        # Reduce transparency slightly
        run_command defaults write com.apple.universalaccess reduceTransparency -bool true
        
        log "Restarting Dock to apply changes..."
        run_command killall Dock
        
        log "Subtle animation optimizations applied."
      fi
      ;;
      
    2)  # Medium optimization
      log "Applying medium animation optimizations..."
      
      if [[ $DRY_RUN -eq 1 ]]; then
        log "DRY RUN: Would speed up animations and disable some effects"
      else
        # Speed up animations significantly
        run_command defaults write com.apple.dock autohide-time-modifier -float 0.2
        run_command defaults write com.apple.dock autohide-delay -float 0.0
        run_command defaults write NSGlobalDomain NSWindowResizeTime -float 0.05
        
        # Reduce transparency and other effects
        run_command defaults write com.apple.universalaccess reduceTransparency -bool true
        run_command defaults write com.apple.dock expose-animation-duration -float 0.15
        run_command defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool false
        
        log "Restarting UI services to apply changes..."
        run_command killall Dock
        run_command killall SystemUIServer
        
        log "Medium animation optimizations applied."
      fi
      ;;
      
    3)  # Maximum optimization
      log "Applying maximum animation optimizations..."
      
      if [[ $DRY_RUN -eq 1 ]]; then
        log "DRY RUN: Would disable most animations and visual effects"
      else
        # Disable most animations
        run_command defaults write com.apple.dock autohide-time-modifier -float 0.0
        run_command defaults write com.apple.dock autohide-delay -float 0.0
        run_command defaults write com.apple.dock expose-animation-duration -float 0.1
        run_command defaults write com.apple.dock launchanim -bool false
        run_command defaults write com.apple.dock mineffect -string scale
        run_command defaults write NSGlobalDomain NSWindowResizeTime -float 0.001
        run_command defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool false
        run_command defaults write -g QLPanelAnimationDuration -float 0
        
        # Disable transparency completely
        run_command defaults write com.apple.universalaccess reduceTransparency -bool true
        run_command defaults write com.apple.universalaccess reduceMotion -bool true
        
        log "Restarting UI services to apply changes..."
        run_command killall Dock
        run_command killall SystemUIServer
        run_command killall Finder
        
        log "Maximum animation optimizations applied."
        log "Note: Your system may appear less visually appealing but should feel more responsive."
      fi
      ;;
      
    4)  # Restore defaults
      log "Restoring default animation settings..."
      
      if [[ $DRY_RUN -eq 1 ]]; then
        log "DRY RUN: Would restore default animation settings"
      else
        # Reset animation settings
        run_command defaults delete com.apple.dock autohide-time-modifier 2>/dev/null
        run_command defaults delete com.apple.dock autohide-delay 2>/dev/null
        run_command defaults delete com.apple.dock expose-animation-duration 2>/dev/null
        run_command defaults delete com.apple.dock launchanim 2>/dev/null
        run_command defaults write com.apple.dock mineffect -string genie
        run_command defaults delete NSGlobalDomain NSWindowResizeTime 2>/dev/null
        run_command defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool true
        run_command defaults delete -g QLPanelAnimationDuration 2>/dev/null
        
        # Reset transparency settings
        run_command defaults write com.apple.universalaccess reduceTransparency -bool false
        run_command defaults write com.apple.universalaccess reduceMotion -bool false
        
        log "Restarting UI services to apply changes..."
        run_command killall Dock
        run_command killall SystemUIServer
        run_command killall Finder
        
        log "Default animation settings restored."
      fi
      ;;
      
    *)
      log --warn "Invalid choice."
      ;;
  esac
  
  echo
  read -n 1 -s -r -p "Press any key to continue..."
}

# Optimize application launch times
optimize_app_launch() {
  echo -e "\n${BLUE}--- Optimizing Application Launch Times ---${NC}"
  
  log "This will optimize application launch times and overall system responsiveness."
  
  if ! confirm "Continue with optimizing application launch times?"; then
    return
  fi
  
  # Menu of optimization options
  echo "1. Rebuild dyld shared cache (comprehensive optimization)"
  echo "2. Clear app caches (targeted cleanup)"
  echo "3. Preload frequently used applications"
  echo -n "Select an option: "
  read -r launch_choice
  
  case "$launch_choice" in
    1)  # Rebuild dyld shared cache
      log "Rebuilding dynamic linker shared cache..."
      
      # Check if running as root
      if [[ $EUID -ne 0 ]]; then
        log --warn "This operation requires root privileges."
        if ! confirm "Attempt to run with sudo?"; then
          return
        fi
      fi
      
      if [[ $DRY_RUN -eq 1 ]]; then
        log "DRY RUN: Would rebuild dynamic linker shared cache"
      else
        log "This operation may take several minutes and temporarily slow down your system."
        log "Do not interrupt this process or restart your computer until it completes."
        
        # Update dyld shared cache
        run_command sudo update_dyld_shared_cache -force
        
        if [[ $? -eq 0 ]]; then
          log "Dynamic linker shared cache rebuilt successfully."
          log "This should improve application launch times across the system."
        else
          log --error "Error rebuilding dynamic linker shared cache."
        fi
      fi
      ;;
      
    2)  # Clear app caches
      log "Clearing application caches..."
      
      if [[ $DRY_RUN -eq 1 ]]; then
        log "DRY RUN: Would clear application caches"
      else
        # Backup user caches directory
        backup_item "$HOME/Library/Caches"
        
        # Main app caches
        run_command rm -rf "$HOME/Library/Caches"/*
        
        # App container caches
        if [[ -d "$HOME/Library/Containers" ]]; then
          find "$HOME/Library/Containers" -path "*/Data/Library/Caches/*" -delete 2>/dev/null
        fi
        
        log "Application caches cleared."
        log "The next launch of applications may be slower while caches are rebuilt."
      fi
      ;;
      
    3)  # Preload frequently used applications
      log "Setting up application preloading..."
      
      # Get list of installed applications
      local app_list=$(find /Applications -maxdepth 1 -name "*.app" -print | sed 's|.*/||' | sed 's|\.app$||' | sort)
      
      echo "Select applications to preload at login (space-separated numbers):"
      local count=1
      for app in $app_list; do
        echo "$count. $app"
        count=$((count + 1))
      done
      
      read -r selections
      
      if [[ -z "$selections" ]]; then
        log "No applications selected."
        return
      fi
      
      # Create LaunchAgents directory if it doesn't exist
      if [[ ! -d "$HOME/Library/LaunchAgents" ]]; then
        run_command mkdir -p "$HOME/Library/LaunchAgents"
      fi
      
      # Create preload plist for each selected app
      for num in $selections; do
        if [[ "$num" =~ ^[0-9]+$ ]]; then
          local app_name=$(echo "$app_list" | sed -n "${num}p")
          
          if [[ -n "$app_name" ]]; then
            local plist_path="$HOME/Library/LaunchAgents/com.user.preload.$app_name.plist"
            
            log "Creating preload agent for $app_name..."
            
            if [[ $DRY_RUN -eq 1 ]]; then
              log "DRY RUN: Would create preload agent for $app_name"
            else
              # Create the plist file
              cat > "$plist_path" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.preload.$app_name</string>
    <key>ProgramArguments</key>
    <array>
        <string>open</string>
        <string>-a</string>
        <string>$app_name</string>
        <string>--hide</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
EOF
              
              # Set proper permissions
              run_command chmod 644 "$plist_path"
              
              # Load the agent
              run_command launchctl load "$plist_path"
              
              log "Preload agent created for $app_name. The app will be preloaded at login."
            fi
          fi
        fi
      done
      ;;
      
    *)
      log --warn "Invalid choice."
      ;;
  esac
  
  echo
  read -n 1 -s -r -p "Press any key to continue..."
}

# Purge inactive memory
purge_memory() {
  echo -e "\n${BLUE}--- Purging Inactive Memory ---${NC}"
  
  log "This will free up inactive memory that applications have used but are no longer actively using."
  log "Note: This might temporarily freeze your system as the memory is being reclaimed."
  
  # Check current memory usage
  log "Current memory usage:"
  vm_stat | perl -ne '/page size of (\d+)/ and $size=$1; /Pages\s+([^:]+)[^\d]+(\d+)/ and printf("%-16s % 16.2f MB\n", "$1:", $2 * $size / 1048576);'
  
  if ! confirm "Continue with memory purge?"; then
    return
  fi
  
  # Check if running as root
  if [[ $EUID -ne 0 ]]; then
    log --warn "This operation requires root privileges."
    if ! confirm "Attempt to run with sudo?"; then
      return
    fi
  fi
  
  if [[ $DRY_RUN -eq 1 ]]; then
    log "DRY RUN: Would purge inactive memory"
  else
    log "Purging inactive memory..."
    run_command sudo purge
    
    # Wait a moment for the system to stabilize
    sleep 2
    
    # Show updated memory usage
    log "Updated memory usage:"
    vm_stat | perl -ne '/page size of (\d+)/ and $size=$1; /Pages\s+([^:]+)[^\d]+(\d+)/ and printf("%-16s % 16.2f MB\n", "$1:", $2 * $size / 1048576);'
    
    log "Memory purge completed."
  fi
  
  echo
  read -n 1 -s -r -p "Press any key to continue..."
} 