#!/bin/bash

# hidden_cleanup.sh - Functions for cleaning up hidden folders and configurations

# Main hidden cleanup function
hidden_cleanup() {
  echo -e "\n${BLUE}=== Hidden Folder Cleanup ===${NC}"
  check_privileges 0  # Does not require elevated privileges to start
  
  echo "1. Scan for unused hidden folders"
  echo "2. Clean up package manager caches"
  echo "3. Clean up development environment remnants"
  echo "4. Clean up application data"
  echo "5. Return to main menu"
  echo -n "Select an option: "
  read -r hidden_choice
  
  case "$hidden_choice" in
    1) scan_unused_hidden_folders ;;
    2) clean_package_caches ;;
    3) clean_dev_remnants ;;
    4) clean_app_data ;;
    5) return ;;
    *) log --warn "Invalid choice. Returning to main menu."; return ;;
  esac
}

# Scan for unused hidden folders
scan_unused_hidden_folders() {
  echo -e "\n${BLUE}--- Scanning for Unused Hidden Folders ---${NC}"
  
  log "Scanning your home directory for hidden folders from applications that may no longer be installed..."
  
  # Create temporary files
  local hidden_folders_file=$(mktemp)
  local results_file=$(mktemp)
  
  # Get list of hidden folders
  find "$HOME" -maxdepth 1 -type d -name ".*" ! -name ".Trash" ! -name "." ! -name ".." | sort > "$hidden_folders_file"
  
  # Header for results
  echo "Hidden Folders Analysis - $(date)" > "$results_file"
  echo "-------------------------------" >> "$results_file"
  echo "" >> "$results_file"
  
  # Check common development tools and their related folders
  local possibly_unused=()
  
  # Process each hidden folder
  while read -r folder; do
    local folder_name=$(basename "$folder")
    local folder_size=$(du -sh "$folder" 2>/dev/null | awk '{print $1}')
    local is_used=0
    local related_command=""
    local description=""
    
    case "$folder_name" in
      .npm | .node_repl_history | .node_modules)
        command -v node >/dev/null 2>&1 && is_used=1
        related_command="node/npm"
        description="Node.js and npm package manager files"
        ;;
      .nvm)
        command -v nvm >/dev/null 2>&1 && is_used=1
        related_command="nvm"
        description="Node Version Manager"
        ;;
      .yarn)
        command -v yarn >/dev/null 2>&1 && is_used=1
        related_command="yarn"
        description="Yarn package manager"
        ;;
      .expo)
        command -v expo >/dev/null 2>&1 && is_used=1
        related_command="expo"
        description="Expo CLI for React Native development"
        ;;
      .cache)
        # General cache directory used by many applications
        is_used=1
        related_command="various"
        description="General cache directory used by many applications"
        ;;
      .cargo | .rustup)
        command -v rustc >/dev/null 2>&1 && is_used=1
        related_command="rustc/cargo"
        description="Rust programming language and Cargo package manager"
        ;;
      .rbenv | .rubies | .gem)
        command -v ruby >/dev/null 2>&1 && is_used=1
        command -v rbenv >/dev/null 2>&1 && is_used=1
        related_command="ruby/rbenv"
        description="Ruby programming language and version manager"
        ;;
      .python_history | .jupyter | .ipython)
        command -v python >/dev/null 2>&1 && is_used=1
        command -v python3 >/dev/null 2>&1 && is_used=1
        related_command="python"
        description="Python programming language"
        ;;
      .deno)
        command -v deno >/dev/null 2>&1 && is_used=1
        related_command="deno"
        description="Deno JavaScript/TypeScript runtime"
        ;;
      .gradle | .m2)
        command -v gradle >/dev/null 2>&1 && is_used=1
        command -v mvn >/dev/null 2>&1 && is_used=1
        related_command="gradle/maven"
        description="Java build tools"
        ;;
      .vscode)
        command -v code >/dev/null 2>&1 && is_used=1
        related_command="code"
        description="Visual Studio Code editor"
        ;;
      .config)
        # General config directory used by many applications
        is_used=1
        related_command="various"
        description="General configuration directory used by many applications"
        ;;
      .docker)
        command -v docker >/dev/null 2>&1 && is_used=1
        related_command="docker"
        description="Docker containerization platform"
        ;;
      .local)
        # General local directory used by many applications
        is_used=1
        related_command="various"
        description="General user data directory used by many applications"
        ;;
      .ssh)
        # Important SSH config - always mark as used
        is_used=1
        related_command="ssh"
        description="SSH configuration and keys - IMPORTANT"
        ;;
      .zsh*)
        command -v zsh >/dev/null 2>&1 && is_used=1
        related_command="zsh"
        description="Zsh shell configuration"
        ;;
      .bash*)
        command -v bash >/dev/null 2>&1 && is_used=1
        related_command="bash"
        description="Bash shell configuration"
        ;;
      .oh-my-zsh)
        # If we have oh-my-zsh installed, mark as used
        [[ -f "$HOME/.zshrc" ]] && grep -q "oh-my-zsh" "$HOME/.zshrc" && is_used=1
        related_command="zsh"
        description="Oh My Zsh framework for Zsh shell"
        ;;
      .vim*)
        command -v vim >/dev/null 2>&1 && is_used=1
        related_command="vim"
        description="Vim editor configuration"
        ;;
      .git*)
        command -v git >/dev/null 2>&1 && is_used=1
        related_command="git"
        description="Git version control system"
        ;;
      .DS_Store)
        # macOS file system metadata
        is_used=1
        related_command="Finder"
        description="macOS Finder metadata"
        ;;
      *)
        # Unknown folder - mark as potentially unused
        is_used=0
        related_command="unknown"
        description="Unknown purpose"
        ;;
    esac
    
    # Check if related binary exists in Applications folder
    if [[ $is_used -eq 0 ]]; then
      # Extract app name from folder name (remove leading '.')
      local app_name=$(echo "${folder_name}" | sed 's/^\.//' | sed 's/-/ /g' | sed 's/_/ /g')
      
      # Check in Applications for similarly named app
      if find "/Applications" -maxdepth 2 -name "*${app_name}*.app" -print -quit 2>/dev/null | grep -q .; then
        is_used=1
        related_command="Application"
        description="Related to application found in /Applications"
      fi
    fi
    
    # Store status in results file
    if [[ $is_used -eq 0 ]]; then
      echo "[$folder_size] $folder (Potentially unused - $description)" >> "$results_file"
      possibly_unused+=("$folder")
    else
      echo "[$folder_size] $folder (In use by $related_command - $description)" >> "$results_file"
    fi
    
  done < "$hidden_folders_file"
  
  # Display results
  less "$results_file"
  
  # Ask if user wants to clean up the potentially unused folders
  if [[ ${#possibly_unused[@]} -gt 0 ]]; then
    echo -e "\n${YELLOW}Potentially unused hidden folders:${NC}"
    for i in "${!possibly_unused[@]}"; do
      echo "$((i+1)). $(basename "${possibly_unused[$i]}") - $(du -sh "${possibly_unused[$i]}" 2>/dev/null | awk '{print $1}')"
    done
    
    echo -e "\n${YELLOW}WARNING:${NC} Removing configuration folders may cause issues if the application is reinstalled later."
    echo "Select folders to clean up (space-separated numbers), or 0 to cancel:"
    read -r selections
    
    for num in $selections; do
      if [[ "$num" == "0" ]]; then
        break
      elif [[ "$num" =~ ^[0-9]+$ && "$num" -le "${#possibly_unused[@]}" ]]; then
        folder_to_remove="${possibly_unused[$((num-1))]}"
        folder_name=$(basename "$folder_to_remove")
        
        log "Preparing to remove $folder_name"
        
        if [[ $DRY_RUN -eq 1 ]]; then
          log "DRY RUN: Would remove $folder_to_remove"
        else
          # Backup the folder first
          log "Creating backup of $folder_name..."
          backup_item "$folder_to_remove"
          
          # Remove the folder
          log "Removing $folder_name..."
          rm -rf "$folder_to_remove"
          
          if [[ $? -eq 0 ]]; then
            log "Successfully removed $folder_name"
          else
            log --error "Failed to remove $folder_name"
          fi
        fi
      fi
    done
  else
    log "No potentially unused hidden folders found."
  fi
  
  # Clean up temporary files
  rm "$hidden_folders_file" "$results_file"
  
  echo
  read -n 1 -s -r -p "Press any key to continue..."
}

# Clean up package manager caches
clean_package_caches() {
  echo -e "\n${BLUE}--- Cleaning Package Manager Caches ---${NC}"
  
  log "This will clean up package manager caches and temporary files."
  log "This can free up significant disk space without affecting functionality."
  
  if ! confirm "Continue with cleaning package manager caches?"; then
    return
  fi
  
  # Create a list of available cleanups
  local cleanups=()
  local cleanup_descriptions=()
  
  # NPM cache
  if [[ -d "$HOME/.npm" ]]; then
    cleanups+=("npm")
    cleanup_descriptions+=("NPM package manager cache ($(du -sh "$HOME/.npm" 2>/dev/null | awk '{print $1}'))")
  fi
  
  # Yarn cache
  if [[ -d "$HOME/.yarn" ]]; then
    cleanups+=("yarn")
    cleanup_descriptions+=("Yarn package manager cache ($(du -sh "$HOME/.yarn" 2>/dev/null | awk '{print $1}'))")
  fi
  
  # Cargo cache
  if [[ -d "$HOME/.cargo/registry/cache" ]]; then
    cleanups+=("cargo")
    cleanup_descriptions+=("Rust Cargo package manager cache ($(du -sh "$HOME/.cargo/registry/cache" 2>/dev/null | awk '{print $1}'))")
  fi
  
  # Gem cache
  if [[ -d "$HOME/.gem" ]]; then
    cleanups+=("gem")
    cleanup_descriptions+=("Ruby Gem package manager cache ($(du -sh "$HOME/.gem" 2>/dev/null | awk '{print $1}'))")
  fi
  
  # Pip cache
  if [[ -d "$HOME/.cache/pip" ]]; then
    cleanups+=("pip")
    cleanup_descriptions+=("Python Pip package manager cache ($(du -sh "$HOME/.cache/pip" 2>/dev/null | awk '{print $1}'))")
  fi
  
  # Homebrew cache
  if [[ -d "$HOME/Library/Caches/Homebrew" ]]; then
    cleanups+=("brew")
    cleanup_descriptions+=("Homebrew package manager cache ($(du -sh "$HOME/Library/Caches/Homebrew" 2>/dev/null | awk '{print $1}'))")
  fi
  
  # CocoaPods cache
  if [[ -d "$HOME/Library/Caches/CocoaPods" ]]; then
    cleanups+=("cocoapods")
    cleanup_descriptions+=("CocoaPods package manager cache ($(du -sh "$HOME/Library/Caches/CocoaPods" 2>/dev/null | awk '{print $1}'))")
  fi
  
  # Display available cleanups
  if [[ ${#cleanups[@]} -eq 0 ]]; then
    log "No package manager caches found."
    return
  fi
  
  echo "Select package manager caches to clean (space-separated numbers), or 'all' for all:"
  for i in "${!cleanups[@]}"; do
    echo "$((i+1)). ${cleanup_descriptions[$i]}"
  done
  
  read -r selections
  
  # Process selections
  if [[ "$selections" == "all" ]]; then
    selections=$(seq 1 ${#cleanups[@]})
  fi
  
  for num in $selections; do
    if [[ "$num" =~ ^[0-9]+$ && "$num" -le "${#cleanups[@]}" ]]; then
      local cache_type="${cleanups[$((num-1))]}"
      
      log "Cleaning $cache_type cache..."
      
      if [[ $DRY_RUN -eq 1 ]]; then
        log "DRY RUN: Would clean $cache_type cache"
      else
        case "$cache_type" in
          npm)
            run_command npm cache clean --force
            ;;
          yarn)
            if command -v yarn >/dev/null 2>&1; then
              run_command yarn cache clean
            else
              log "Manually cleaning yarn cache..."
              backup_item "$HOME/.yarn"
              run_command rm -rf "$HOME/.yarn/cache"/*
            fi
            ;;
          cargo)
            if command -v cargo >/dev/null 2>&1; then
              run_command cargo cache --autoclean
            else
              log "Manually cleaning cargo cache..."
              backup_item "$HOME/.cargo/registry/cache"
              run_command rm -rf "$HOME/.cargo/registry/cache"/*
            fi
            ;;
          gem)
            if command -v gem >/dev/null 2>&1; then
              run_command gem cleanup
            else
              log "Manually cleaning gem cache..."
              backup_item "$HOME/.gem"
              run_command rm -rf "$HOME/.gem/cache"/*
            fi
            ;;
          pip)
            if command -v pip >/dev/null 2>&1; then
              run_command pip cache purge
            elif command -v pip3 >/dev/null 2>&1; then
              run_command pip3 cache purge
            else
              log "Manually cleaning pip cache..."
              backup_item "$HOME/.cache/pip"
              run_command rm -rf "$HOME/.cache/pip"/*
            fi
            ;;
          brew)
            if command -v brew >/dev/null 2>&1; then
              run_command brew cleanup --prune=all
            else
              log "Manually cleaning brew cache..."
              backup_item "$HOME/Library/Caches/Homebrew"
              run_command rm -rf "$HOME/Library/Caches/Homebrew"/*
            fi
            ;;
          cocoapods)
            if command -v pod >/dev/null 2>&1; then
              run_command pod cache clean --all
            else
              log "Manually cleaning cocoapods cache..."
              backup_item "$HOME/Library/Caches/CocoaPods"
              run_command rm -rf "$HOME/Library/Caches/CocoaPods"/*
            fi
            ;;
        esac
        
        log "$cache_type cache cleaned."
      fi
    fi
  done
  
  echo
  read -n 1 -s -r -p "Press any key to continue..."
}

# Clean up development environment remnants
clean_dev_remnants() {
  echo -e "\n${BLUE}--- Cleaning Development Environment Remnants ---${NC}"
  
  log "This will clean up remnants of development environments that may no longer be in use."
  log "WARNING: This may remove configuration files for development tools."
  
  if ! confirm "Continue with cleaning development environment remnants?"; then
    return
  fi
  
  # Create a list of development environment cleanups
  local cleanups=()
  local cleanup_descriptions=()
  
  # React Native / Expo
  if [[ -d "$HOME/.expo" && ! $(command -v expo >/dev/null 2>&1) ]]; then
    cleanups+=("expo")
    cleanup_descriptions+=("Expo CLI for React Native ($(du -sh "$HOME/.expo" 2>/dev/null | awk '{print $1}'))")
  fi
  
  # Android development
  if [[ -d "$HOME/.android" && ! $(command -v adb >/dev/null 2>&1) && ! $(command -v android >/dev/null 2>&1) ]]; then
    cleanups+=("android")
    cleanup_descriptions+=("Android development tools ($(du -sh "$HOME/.android" 2>/dev/null | awk '{print $1}'))")
  fi
  
  # VSCode extensions for uninstalled languages
  if [[ -d "$HOME/.vscode/extensions" ]]; then
    cleanups+=("vscodeext")
    cleanup_descriptions+=("Unused VSCode extensions")
  fi
  
  # Jupyter/IPython
  if [[ -d "$HOME/.jupyter" && ! $(command -v jupyter >/dev/null 2>&1) ]]; then
    cleanups+=("jupyter")
    cleanup_descriptions+=("Jupyter notebooks ($(du -sh "$HOME/.jupyter" 2>/dev/null | awk '{print $1}'))")
  fi
  
  # NVM old Node.js versions
  if [[ -d "$HOME/.nvm/versions" ]]; then
    cleanups+=("nvm")
    cleanup_descriptions+=("Old Node.js versions in NVM")
  fi
  
  # Display available cleanups
  if [[ ${#cleanups[@]} -eq 0 ]]; then
    log "No development environment remnants found."
    return
  fi
  
  echo "Select development environments to clean (space-separated numbers), or 'all' for all:"
  for i in "${!cleanups[@]}"; do
    echo "$((i+1)). ${cleanup_descriptions[$i]}"
  done
  
  read -r selections
  
  # Process selections
  if [[ "$selections" == "all" ]]; then
    selections=$(seq 1 ${#cleanups[@]})
  fi
  
  for num in $selections; do
    if [[ "$num" =~ ^[0-9]+$ && "$num" -le "${#cleanups[@]}" ]]; then
      local env_type="${cleanups[$((num-1))]}"
      
      log "Cleaning $env_type environment..."
      
      if [[ $DRY_RUN -eq 1 ]]; then
        log "DRY RUN: Would clean $env_type environment"
      else
        case "$env_type" in
          expo)
            log "Removing Expo CLI remnants..."
            backup_item "$HOME/.expo"
            run_command rm -rf "$HOME/.expo"
            ;;
          android)
            log "Removing Android development remnants..."
            backup_item "$HOME/.android"
            run_command rm -rf "$HOME/.android"
            ;;
          vscodeext)
            log "Removing unused VSCode extensions..."
            # This is more complex and would require knowledge of which extensions are unused
            # For now, just show information about extensions
            if [[ -d "$HOME/.vscode/extensions" ]]; then
              log "VSCode extensions directory size: $(du -sh "$HOME/.vscode/extensions" 2>/dev/null | awk '{print $1}')"
              log "To clean specific extensions, use VSCode's extension manager."
            fi
            ;;
          jupyter)
            log "Removing Jupyter/IPython remnants..."
            backup_item "$HOME/.jupyter"
            run_command rm -rf "$HOME/.jupyter"
            if [[ -d "$HOME/.ipython" ]]; then
              backup_item "$HOME/.ipython"
              run_command rm -rf "$HOME/.ipython"
            fi
            ;;
          nvm)
            log "Cleaning old Node.js versions in NVM..."
            if [[ -d "$HOME/.nvm" && -s "$HOME/.nvm/nvm.sh" ]]; then
              # Source NVM to use it
              source "$HOME/.nvm/nvm.sh" > /dev/null 2>&1
              
              # Get current version
              local current_version=$(nvm current 2>/dev/null)
              
              # List all versions except current
              log "Current Node.js version: $current_version"
              log "Available versions:"
              nvm ls
              
              echo "Enter space-separated Node.js versions to remove (e.g., 'v14.15.1 v12.22.7'), or 'all_old' to keep only current:"
              read -r node_versions
              
              if [[ "$node_versions" == "all_old" && -n "$current_version" ]]; then
                log "Keeping only $current_version, removing all others..."
                local versions=$(nvm ls --no-colors | grep -v "$current_version" | grep "v[0-9]" | awk '{print $2}')
                for version in $versions; do
                  run_command nvm uninstall $version
                done
              else
                for version in $node_versions; do
                  if [[ "$version" != "$current_version" ]]; then
                    run_command nvm uninstall $version
                  else
                    log --warn "Cannot remove current version $version"
                  fi
                done
              fi
            else
              log --warn "NVM not properly installed or initialized."
            fi
            ;;
        esac
        
        log "$env_type environment cleaned."
      fi
    fi
  done
  
  echo
  read -n 1 -s -r -p "Press any key to continue..."
}

# Clean up application data
clean_app_data() {
  echo -e "\n${BLUE}--- Cleaning Application Data ---${NC}"
  
  log "This will clean up data from applications that may no longer be installed."
  log "WARNING: This will remove application preferences and data. Use with caution."
  
  if ! confirm "Continue with cleaning application data?"; then
    return
  fi
  
  # App-specific data locations to check
  local app_data_locations=(
    "$HOME/Library/Application Support"
    "$HOME/Library/Containers"
    "$HOME/Library/Group Containers"
    "$HOME/Library/Preferences"
    "$HOME/Library/Saved Application State"
    "$HOME/Library/Caches"
  )
  
  # Get list of installed applications
  log "Gathering list of installed applications..."
  local installed_apps_file=$(mktemp)
  find /Applications -maxdepth 2 -name "*.app" | sed 's|.*/||' | sed 's|\.app$||' > "$installed_apps_file"
  
  # Find potential app data remnants
  local results_file=$(mktemp)
  local unused_data=()
  local unused_data_locations=()
  local unused_data_sizes=()
  
  echo "Application Data Analysis - $(date)" > "$results_file"
  echo "--------------------------------" >> "$results_file"
  echo "" >> "$results_file"
  
  # Search each location
  for location in "${app_data_locations[@]}"; do
    if [[ -d "$location" ]]; then
      log "Scanning $location..."
      
      # List potential app data
      find "$location" -maxdepth 1 -type d | while read -r app_folder; do
        local app_name=$(basename "$app_folder")
        
        # Skip system folders and obvious system services
        if [[ "$app_name" == "." || "$app_name" == ".." || 
              "$app_name" == "Apple" || "$app_name" == "iCloud" || 
              "$app_name" == "CloudDocs" || "$app_name" == "MobileSync" || 
              "$app_name" == "CoreSimulator" || "$app_name" == "Group Containers" || 
              "$app_name" == "Application Support" ]]; then
          continue
        fi
        
        # Check if corresponding app exists in Applications
        local is_installed=0
        
        # Convert app name to lowercase for case-insensitive matching
        local app_name_lower=$(echo "$app_name" | tr '[:upper:]' '[:lower:]')
        
        # Try different name variations to match apps
        for installed_app in $(cat "$installed_apps_file"); do
          local installed_app_lower=$(echo "$installed_app" | tr '[:upper:]' '[:lower:]')
          
          # Try variations of name comparisons
          if [[ "$installed_app_lower" == "$app_name_lower" || 
                "$installed_app_lower" == *"$app_name_lower"* || 
                "$app_name_lower" == *"$installed_app_lower"* ]]; then
            is_installed=1
            break
          fi
        done
        
        # Check bundle identifiers for more accurate matching
        if [[ $is_installed -eq 0 && -d "/Applications/$app_name.app" ]]; then
          is_installed=1
        elif [[ $is_installed -eq 0 && -d "/Applications/$app_name/$app_name.app" ]]; then
          is_installed=1
        fi
        
        # Get size of the folder
        local folder_size=$(du -sh "$app_folder" 2>/dev/null | awk '{print $1}')
        
        if [[ $is_installed -eq 0 ]]; then
          echo "[$folder_size] $app_folder (App not found)" >> "$results_file"
          unused_data+=("$app_name")
          unused_data_locations+=("$app_folder")
          unused_data_sizes+=("$folder_size")
        else
          echo "[$folder_size] $app_folder (App installed)" >> "$results_file"
        fi
      done
    fi
  done
  
  # Display results
  less "$results_file"
  
  # Ask if user wants to clean up the potentially unused app data
  if [[ ${#unused_data[@]} -gt 0 ]]; then
    echo -e "\n${YELLOW}Potentially unused application data:${NC}"
    for i in "${!unused_data[@]}"; do
      echo "$((i+1)). ${unused_data[$i]} - ${unused_data_sizes[$i]} - ${unused_data_locations[$i]}"
    done
    
    echo -e "\n${YELLOW}WARNING:${NC} Removing application data will delete preferences and settings."
    echo "If you reinstall these applications, you'll need to reconfigure them."
    echo "Select application data to clean up (space-separated numbers), or 0 to cancel:"
    read -r selections
    
    for num in $selections; do
      if [[ "$num" == "0" ]]; then
        break
      elif [[ "$num" =~ ^[0-9]+$ && "$num" -le "${#unused_data[@]}" ]]; then
        local app_name="${unused_data[$((num-1))]}"
        local data_path="${unused_data_locations[$((num-1))]}"
        
        log "Preparing to remove $app_name data from $data_path"
        
        if [[ $DRY_RUN -eq 1 ]]; then
          log "DRY RUN: Would remove $data_path"
        else
          # Additional confirmation for each item
          if confirm "Are you sure you want to remove $app_name data?"; then
            # Backup the folder first
            log "Creating backup of $app_name data..."
            backup_item "$data_path"
            
            # Remove the folder
            log "Removing $app_name data..."
            run_command rm -rf "$data_path"
            
            if [[ $? -eq 0 ]]; then
              log "Successfully removed $app_name data"
            else
              log --error "Failed to remove $app_name data"
            fi
          fi
        fi
      fi
    done
  else
    log "No potentially unused application data found."
  fi
  
  # Clean up temporary files
  rm "$installed_apps_file" "$results_file"
  
  echo
  read -n 1 -s -r -p "Press any key to continue..."
} 