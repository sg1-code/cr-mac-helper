#!/bin/bash

# swift_package_management.sh - Swift Package Manager and development tools management

# Main Swift Package Manager function
swift_package_management() {
  echo -e "\n${BLUE}=== Swift Package Management ===${NC}"
  check_privileges 0  # Doesn't absolutely require root
  
  # Check if Xcode or Command Line Tools are installed
  if ! command -v xcodebuild &> /dev/null && ! command -v swift &> /dev/null; then
    log --warn "Xcode or Command Line Tools are not installed."
    
    if confirm "Would you like to install Command Line Tools for Xcode?"; then
      log "Attempting to install Command Line Tools for Xcode..."
      run_command xcode-select --install
      
      log "Command Line Tools installation initiated."
      log "Please follow the prompt that appears to complete installation."
      log "Run this module again after installation is complete."
      
      echo
      read -n 1 -s -r -p "Press any key to continue..."
      return
    else
      log "Xcode or Command Line Tools are required for Swift Package Manager functionality."
      echo
      read -n 1 -s -r -p "Press any key to return to main menu..."
      return
    fi
  fi
  
  echo "1. Clean Swift Package Manager caches"
  echo "2. Manage global Swift packages"
  echo "3. Clean Xcode derived data and archives"
  echo "4. Check for Swift toolchain updates"
  echo "5. Scan for abandoned Swift packages"
  echo "6. Return to main menu"
  echo -n "Select an option: "
  read -r swift_choice
  
  case "$swift_choice" in
    1) clean_swift_caches ;;
    2) manage_global_packages ;;
    3) clean_xcode_data ;;
    4) check_swift_updates ;;
    5) scan_abandoned_packages ;;
    6) return ;;
    *) log --warn "Invalid choice. Returning to main menu."; return ;;
  esac
}

# Clean Swift Package Manager caches
clean_swift_caches() {
  echo -e "\n${BLUE}--- Cleaning Swift Package Manager Caches ---${NC}"
  
  # Swift Package Manager cache locations
  local spm_cache_dirs=(
    "$HOME/Library/Caches/org.swift.swiftpm"
    "$HOME/.swiftpm"
  )
  
  # Find cache sizes
  local cache_sizes=()
  local total_size=0
  local i=0
  
  for dir in "${spm_cache_dirs[@]}"; do
    if [[ -d "$dir" ]]; then
      local size=$(du -sh "$dir" 2>/dev/null | cut -f1)
      cache_sizes[i]="$size"
      log "Found Swift Package Manager cache: $dir ($size)"
      ((i++))
    fi
  done
  
  if [[ ${#cache_sizes[@]} -eq 0 ]]; then
    log "No Swift Package Manager caches found."
    echo
    read -n 1 -s -r -p "Press any key to continue..."
    return
  fi
  
  echo
  echo "The following actions will be performed:"
  echo "1. Clear Swift Package Manager caches"
  echo "2. Clean downloaded package sources"
  echo "3. Remove temporary build products"
  echo
  
  if ! confirm "Do you want to proceed with cleaning Swift Package Manager caches?"; then
    return
  fi
  
  # Clean each cache location
  for dir in "${spm_cache_dirs[@]}"; do
    if [[ -d "$dir" ]]; then
      log "Cleaning cache at $dir..."
      
      # Backup first
      backup_item "$dir"
      
      if [[ $DRY_RUN -eq 0 ]]; then
        # Main cache directories to clean
        if [[ -d "$dir/cache" ]]; then
          run_command rm -rf "$dir/cache"
        fi
        
        # Clean package sources for older versions of SwiftPM
        if [[ -d "$dir/repositories" ]]; then
          run_command rm -rf "$dir/repositories"
        fi
        
        # Clean package builds
        if [[ -d "$dir/build" ]]; then
          run_command rm -rf "$dir/build"
        fi
      else
        log "DRY RUN: Would clean cache directories in $dir"
      fi
    fi
  done
  
  log "Swift Package Manager caches cleaned successfully."
  
  echo
  read -n 1 -s -r -p "Press any key to continue..."
}

# Manage global Swift packages
manage_global_packages() {
  echo -e "\n${BLUE}--- Manage Global Swift Packages ---${NC}"
  
  # Check if swift package command is available
  if ! command -v swift &> /dev/null; then
    log --warn "Swift command not found. Cannot manage global packages."
    echo
    read -n 1 -s -r -p "Press any key to continue..."
    return
  fi
  
  echo "1. List installed global packages"
  echo "2. Install a global package"
  echo "3. Remove a global package"
  echo "4. Update all global packages"
  echo "5. Return to previous menu"
  echo -n "Select an option: "
  read -r packages_choice
  
  case "$packages_choice" in
    1) list_global_packages ;;
    2) install_global_package ;;
    3) remove_global_package ;;
    4) update_global_packages ;;
    5) return ;;
    *) log --warn "Invalid choice."; manage_global_packages ;;
  esac
}

# List installed global Swift packages
list_global_packages() {
  echo -e "\n${BLUE}--- Installed Global Swift Packages ---${NC}"
  
  # First check in modern location
  local global_bin="$HOME/.local/bin"
  local found=0
  
  if [[ -d "$global_bin" ]]; then
    log "Checking for Swift tools in $global_bin"
    local tools=$(find "$global_bin" -type f -perm +111 2>/dev/null)
    
    if [[ -n "$tools" ]]; then
      echo "Installed Swift tools:"
      echo "$tools" | while read -r tool; do
        echo "- $(basename "$tool")"
        found=1
      done
    fi
  fi
  
  # Check in older locations
  local old_bin="$HOME/.swiftpm/bin"
  if [[ -d "$old_bin" ]]; then
    log "Checking for Swift tools in $old_bin"
    local old_tools=$(find "$old_bin" -type f -perm +111 2>/dev/null)
    
    if [[ -n "$old_tools" ]]; then
      if [[ $found -eq 1 ]]; then
        echo ""
      fi
      echo "Installed Swift tools (older location):"
      echo "$old_tools" | while read -r tool; do
        echo "- $(basename "$tool")"
        found=1
      done
    fi
  fi
  
  if [[ $found -eq 0 ]]; then
    log "No globally installed Swift packages found."
  fi
  
  echo
  read -n 1 -s -r -p "Press any key to continue..."
  manage_global_packages
}

# Install a global Swift package
install_global_package() {
  echo -e "\n${BLUE}--- Install Global Swift Package ---${NC}"
  
  echo "Enter the package URL to install (GitHub URL or full git URL):"
  read -r package_url
  
  if [[ -z "$package_url" ]]; then
    log --warn "No package URL provided."
    echo
    read -n 1 -s -r -p "Press any key to continue..."
    manage_global_packages
    return
  fi
  
  # Check if it's a GitHub shorthand
  if [[ "$package_url" =~ ^[^/]+/[^/]+$ ]]; then
    package_url="https://github.com/$package_url.git"
    log "Using GitHub URL: $package_url"
  fi
  
  log "Installing global Swift package from $package_url..."
  
  if [[ $DRY_RUN -eq 0 ]]; then
    run_command swift package --allow-writing-to-directory ~/.local/bin install $package_url --force
    
    if [[ $? -eq 0 ]]; then
      # Provide a hint about PATH configuration
      if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
        log --warn "Note: You may need to add $HOME/.local/bin to your PATH."
        log --warn "Add the following line to your ~/.zshrc or ~/.bash_profile:"
        log "export PATH=\"\$HOME/.local/bin:\$PATH\""
      fi
    fi
  else
    log "DRY RUN: Would install $package_url"
  fi
  
  echo
  read -n 1 -s -r -p "Press any key to continue..."
  manage_global_packages
}

# Remove a global Swift package
remove_global_package() {
  echo -e "\n${BLUE}--- Remove Global Swift Package ---${NC}"
  
  # First check in modern location
  local global_bin="$HOME/.local/bin"
  local old_bin="$HOME/.swiftpm/bin"
  local tools=()
  local found=0
  
  # Collect tools from both locations
  if [[ -d "$global_bin" ]]; then
    while IFS= read -r tool; do
      if [[ -n "$tool" ]]; then
        tools+=("$tool")
        found=1
      fi
    done < <(find "$global_bin" -type f -perm +111 2>/dev/null)
  fi
  
  if [[ -d "$old_bin" ]]; then
    while IFS= read -r tool; do
      if [[ -n "$tool" ]]; then
        tools+=("$tool")
        found=1
      fi
    done < <(find "$old_bin" -type f -perm +111 2>/dev/null)
  fi
  
  if [[ $found -eq 0 ]]; then
    log "No globally installed Swift packages found."
    echo
    read -n 1 -s -r -p "Press any key to continue..."
    manage_global_packages
    return
  fi
  
  # Display tools with numbers
  echo "Available tools to remove:"
  for i in "${!tools[@]}"; do
    echo "$((i+1)). $(basename "${tools[$i]}") (${tools[$i]})"
  done
  
  echo -n "Enter the number of the tool to remove (or 0 to cancel): "
  read -r tool_num
  
  if [[ $tool_num -eq 0 || -z "$tool_num" ]]; then
    manage_global_packages
    return
  fi
  
  if [[ $tool_num -le ${#tools[@]} ]]; then
    local tool_to_remove="${tools[$((tool_num-1))]}"
    local tool_name=$(basename "$tool_to_remove")
    
    if confirm "Are you sure you want to remove $tool_name?"; then
      log "Removing $tool_to_remove..."
      
      if [[ $DRY_RUN -eq 0 ]]; then
        run_command rm -f "$tool_to_remove"
        log "Tool $tool_name removed."
      else
        log "DRY RUN: Would remove $tool_to_remove"
      fi
    fi
  else
    log --warn "Invalid selection."
  fi
  
  echo
  read -n 1 -s -r -p "Press any key to continue..."
  manage_global_packages
}

# Update all global Swift packages
update_global_packages() {
  echo -e "\n${BLUE}--- Update Global Swift Packages ---${NC}"
  
  log "This feature is not fully automated as Swift Package Manager doesn't directly support updating global packages."
  log "To update a global package, you'll need to reinstall it using the same URL."
  
  list_global_packages
  
  echo "Would you like to install/update a specific package now?"
  if confirm "Proceed to package installation?"; then
    install_global_package
  else
    manage_global_packages
  fi
}

# Clean Xcode derived data and archives
clean_xcode_data() {
  echo -e "\n${BLUE}--- Clean Xcode Data ---${NC}"
  
  # Define directories to check
  local derived_data="$HOME/Library/Developer/Xcode/DerivedData"
  local archives="$HOME/Library/Developer/Xcode/Archives"
  local ios_device_logs="$HOME/Library/Developer/Xcode/iOS DeviceSupport"
  local watchos_device_logs="$HOME/Library/Developer/Xcode/watchOS DeviceSupport"
  local device_logs="$HOME/Library/Logs/CoreSimulator"
  local preview_cache="$HOME/Library/Developer/Xcode/UserData/Previews/Simulator Devices"
  
  # Check sizes
  local dd_size="Not found"
  local archives_size="Not found"
  local ios_logs_size="Not found"
  local watchos_logs_size="Not found"
  local device_logs_size="Not found"
  local preview_size="Not found"
  
  if [[ -d "$derived_data" ]]; then
    dd_size=$(du -sh "$derived_data" 2>/dev/null | cut -f1)
  fi
  
  if [[ -d "$archives" ]]; then
    archives_size=$(du -sh "$archives" 2>/dev/null | cut -f1)
  fi
  
  if [[ -d "$ios_device_logs" ]]; then
    ios_logs_size=$(du -sh "$ios_device_logs" 2>/dev/null | cut -f1)
  fi
  
  if [[ -d "$watchos_device_logs" ]]; then
    watchos_logs_size=$(du -sh "$watchos_device_logs" 2>/dev/null | cut -f1)
  fi
  
  if [[ -d "$device_logs" ]]; then
    device_logs_size=$(du -sh "$device_logs" 2>/dev/null | cut -f1)
  fi
  
  if [[ -d "$preview_cache" ]]; then
    preview_size=$(du -sh "$preview_cache" 2>/dev/null | cut -f1)
  fi
  
  # Display information
  echo "Xcode data locations and sizes:"
  echo "1. DerivedData: $dd_size"
  echo "2. Archives: $archives_size"
  echo "3. iOS Device Support logs: $ios_logs_size"
  echo "4. watchOS Device Support logs: $watchos_logs_size"
  echo "5. Core Simulator logs: $device_logs_size"
  echo "6. SwiftUI Preview cache: $preview_size"
  echo "7. Clean all"
  echo "8. Return to previous menu"
  echo -n "Select an option to clean (or 8 to cancel): "
  read -r xcode_choice
  
  case "$xcode_choice" in
    1)
      if [[ -d "$derived_data" ]]; then
        if confirm "Are you sure you want to clean all Derived Data ($dd_size)?"; then
          backup_item "$derived_data"
          log "Cleaning Derived Data..."
          if [[ $DRY_RUN -eq 0 ]]; then
            run_command rm -rf "$derived_data"/*
          else
            log "DRY RUN: Would clean Derived Data"
          fi
          log "Derived Data cleaned."
        fi
      else
        log "Derived Data directory not found."
      fi
      ;;
    2)
      if [[ -d "$archives" ]]; then
        if confirm "Are you sure you want to clean all Archives ($archives_size)?"; then
          backup_item "$archives"
          log "Cleaning Archives..."
          if [[ $DRY_RUN -eq 0 ]]; then
            run_command rm -rf "$archives"/*
          else
            log "DRY RUN: Would clean Archives"
          fi
          log "Archives cleaned."
        fi
      else
        log "Archives directory not found."
      fi
      ;;
    3)
      if [[ -d "$ios_device_logs" ]]; then
        if confirm "Are you sure you want to clean iOS Device Support logs ($ios_logs_size)?"; then
          backup_item "$ios_device_logs"
          log "Cleaning iOS Device Support logs..."
          if [[ $DRY_RUN -eq 0 ]]; then
            run_command rm -rf "$ios_device_logs"/*
          else
            log "DRY RUN: Would clean iOS Device Support logs"
          fi
          log "iOS Device Support logs cleaned."
        fi
      else
        log "iOS Device Support logs directory not found."
      fi
      ;;
    4)
      if [[ -d "$watchos_device_logs" ]]; then
        if confirm "Are you sure you want to clean watchOS Device Support logs ($watchos_logs_size)?"; then
          backup_item "$watchos_device_logs"
          log "Cleaning watchOS Device Support logs..."
          if [[ $DRY_RUN -eq 0 ]]; then
            run_command rm -rf "$watchos_device_logs"/*
          else
            log "DRY RUN: Would clean watchOS Device Support logs"
          fi
          log "watchOS Device Support logs cleaned."
        fi
      else
        log "watchOS Device Support logs directory not found."
      fi
      ;;
    5)
      if [[ -d "$device_logs" ]]; then
        if confirm "Are you sure you want to clean Core Simulator logs ($device_logs_size)?"; then
          backup_item "$device_logs"
          log "Cleaning Core Simulator logs..."
          if [[ $DRY_RUN -eq 0 ]]; then
            run_command rm -rf "$device_logs"/*
          else
            log "DRY RUN: Would clean Core Simulator logs"
          fi
          log "Core Simulator logs cleaned."
        fi
      else
        log "Core Simulator logs directory not found."
      fi
      ;;
    6)
      if [[ -d "$preview_cache" ]]; then
        if confirm "Are you sure you want to clean SwiftUI Preview cache ($preview_size)?"; then
          backup_item "$preview_cache"
          log "Cleaning SwiftUI Preview cache..."
          if [[ $DRY_RUN -eq 0 ]]; then
            run_command rm -rf "$preview_cache"/*
          else
            log "DRY RUN: Would clean SwiftUI Preview cache"
          fi
          log "SwiftUI Preview cache cleaned."
        fi
      else
        log "SwiftUI Preview cache directory not found."
      fi
      ;;
    7)
      if confirm "Are you sure you want to clean ALL Xcode data? This will clear all temporary build data."; then
        local dirs=("$derived_data" "$archives" "$ios_device_logs" "$watchos_device_logs" "$device_logs" "$preview_cache")
        
        for dir in "${dirs[@]}"; do
          if [[ -d "$dir" ]]; then
            backup_item "$dir"
            log "Cleaning $dir..."
            if [[ $DRY_RUN -eq 0 ]]; then
              run_command rm -rf "$dir"/*
            else
              log "DRY RUN: Would clean $dir"
            fi
          fi
        done
        
        log "All Xcode data cleaned."
      fi
      ;;
    8) return ;;
    *) log --warn "Invalid choice." ;;
  esac
  
  echo
  read -n 1 -s -r -p "Press any key to continue..."
  swift_package_management
}

# Check for Swift toolchain updates
check_swift_updates() {
  echo -e "\n${BLUE}--- Check for Swift Toolchain Updates ---${NC}"
  
  # Get current Swift version
  local swift_version="Unknown"
  if command -v swift &> /dev/null; then
    swift_version=$(swift --version | head -n 1)
    log "Current Swift version: $swift_version"
  else
    log --warn "Swift command not found. Cannot check for updates."
    echo
    read -n 1 -s -r -p "Press any key to continue..."
    return
  fi
  
  echo "Swift update options:"
  echo "1. Check for Xcode updates (Apple's Swift)"
  echo "2. Check Swift.org for alternative toolchains"
  echo "3. Return to previous menu"
  echo -n "Select an option: "
  read -r update_choice
  
  case "$update_choice" in
    1)
      # Check for Xcode updates via softwareupdate
      log "Checking for Xcode updates..."
      if [[ $DRY_RUN -eq 0 ]]; then
        run_command softwareupdate -l | grep -i xcode
      else
        log "DRY RUN: Would check for Xcode updates"
      fi
      
      echo
      echo "To update Xcode, use the App Store application or run:"
      echo "sudo softwareupdate -i [Xcode update name]"
      ;;
    2)
      # Provide information about Swift.org toolchains
      echo
      echo "Alternative Swift toolchains can be downloaded from Swift.org:"
      echo "https://www.swift.org/download/"
      echo
      echo "After downloading a toolchain, you can install it by:"
      echo "1. Double-clicking the downloaded .pkg file"
      echo "2. Following the installation instructions"
      echo
      echo "You can switch between installed toolchains using Xcode's preferences:"
      echo "Xcode > Preferences > Components > Toolchains"
      ;;
    3) return ;;
    *) log --warn "Invalid choice." ;;
  esac
  
  echo
  read -n 1 -s -r -p "Press any key to continue..."
  swift_package_management
}

# Scan for abandoned Swift packages
scan_abandoned_packages() {
  echo -e "\n${BLUE}--- Scan for Abandoned Swift Packages ---${NC}"
  
  log "This will scan for Swift package directories that may be leftover from old projects."
  log "Note: This operation may take some time depending on the number of files in your home directory."
  
  if ! confirm "Proceed with scanning for abandoned Swift packages?"; then
    return
  fi
  
  # Create a temporary file for results
  local report_file=$(mktemp)
  echo "Abandoned Swift Package Scan Report" > "$report_file"
  echo "Generated: $(date)" >> "$report_file"
  echo "====================================" >> "$report_file"
  echo "" >> "$report_file"
  
  # Look for Package.swift files outside of ~/.swiftpm
  log "Searching for Package.swift files in home directory..."
  
  if [[ $DRY_RUN -eq 0 ]]; then
    local found_packages=0
    local suspicious_packages=0
    
    find "$HOME" -name "Package.swift" -type f -not -path "*/\.git/*" -not -path "*/\.swiftpm/*" 2>/dev/null | 
    while read -r package_file; do
      local package_dir=$(dirname "$package_file")
      ((found_packages++))
      
      # Check if the directory has been modified recently
      local last_modified=$(stat -f "%m" "$package_dir")
      local current_time=$(date +%s)
      local days_since_modified=$(( (current_time - last_modified) / 86400 ))
      
      if [[ $days_since_modified -gt 90 ]]; then
        ((suspicious_packages++))
        echo "Possible abandoned package: $package_dir" >> "$report_file"
        echo "  Last modified: $(date -r $last_modified '+%Y-%m-%d')" >> "$report_file"
        echo "  Days since modified: $days_since_modified" >> "$report_file"
        
        # Check if it has a .build directory
        if [[ -d "$package_dir/.build" ]]; then
          local build_size=$(du -sh "$package_dir/.build" 2>/dev/null | cut -f1)
          echo "  Build directory size: $build_size" >> "$report_file"
        fi
        
        echo "" >> "$report_file"
      fi
    done
    
    if [[ $suspicious_packages -gt 0 ]]; then
      echo "Found $suspicious_packages potential abandoned Swift packages (not modified in 90+ days)." >> "$report_file"
      echo "" >> "$report_file"
      echo "Recommendations:" >> "$report_file"
      echo "1. Review each package directory and delete if no longer needed" >> "$report_file"
      echo "2. For packages you want to keep, consider removing just the .build directory" >> "$report_file"
      echo "   to free up space while preserving the package code" >> "$report_file"
      echo "3. Run 'swift package clean' in the package directory to clean build artifacts" >> "$report_file"
    else
      echo "No abandoned Swift packages found." >> "$report_file"
    fi
    
    # Also look for orphaned .build directories without Package.swift
    echo "" >> "$report_file"
    echo "Searching for orphaned build directories..." >> "$report_file"
    
    local orphaned_builds=0
    find "$HOME" -name ".build" -type d -not -path "*/\.git/*" 2>/dev/null |
    while read -r build_dir; do
      local parent_dir=$(dirname "$build_dir")
      
      # Check if it has a Package.swift
      if [[ ! -f "$parent_dir/Package.swift" ]]; then
        ((orphaned_builds++))
        local build_size=$(du -sh "$build_dir" 2>/dev/null | cut -f1)
        echo "Orphaned build directory: $build_dir" >> "$report_file"
        echo "  Size: $build_size" >> "$report_file"
        echo "" >> "$report_file"
      fi
    done
    
    if [[ $orphaned_builds -gt 0 ]]; then
      echo "Found $orphaned_builds orphaned .build directories (no Package.swift present)." >> "$report_file"
      echo "These can be safely removed to free up disk space." >> "$report_file"
    else
      echo "No orphaned build directories found." >> "$report_file"
    fi
  else
    log "DRY RUN: Would scan for abandoned Swift packages"
    echo "This scan would find Package.swift files older than 90 days and orphaned .build directories." >> "$report_file"
  fi
  
  # Display the report
  less "$report_file"
  
  # Offer to save the report
  if confirm "Would you like to save this scan report to your Desktop?"; then
    local report_path="$HOME/Desktop/swift_packages_scan_$(date +%Y%m%d_%H%M%S).txt"
    cp "$report_file" "$report_path"
    log "Report saved to: $report_path"
  fi
  
  # Clean up
  rm "$report_file"
  
  # Offer to clean build directories if any found
  if [[ $DRY_RUN -eq 0 && ( $suspicious_packages -gt 0 || $orphaned_builds -gt 0 ) ]]; then
    if confirm "Would you like to clean all orphaned .build directories?"; then
      find "$HOME" -name ".build" -type d -not -path "*/\.git/*" 2>/dev/null |
      while read -r build_dir; do
        local parent_dir=$(dirname "$build_dir")
        
        # Check if it has a Package.swift
        if [[ ! -f "$parent_dir/Package.swift" ]]; then
          local build_size=$(du -sh "$build_dir" 2>/dev/null | cut -f1)
          log "Removing orphaned build directory: $build_dir ($build_size)"
          run_command rm -rf "$build_dir"
        fi
      done
      
      log "Orphaned build directories cleaned."
    fi
  fi
  
  echo
  read -n 1 -s -r -p "Press any key to continue..."
}