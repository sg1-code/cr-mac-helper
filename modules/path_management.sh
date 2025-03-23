#!/bin/bash

# path_management.sh - Path management functions

# Main path management function
path_management() {
  echo -e "\n${BLUE}=== Path Management ===${NC}"
  
  # Menu for path management options
  echo "1. Detect and cleanup broken PATH entries"
  echo "2. Remove references to uninstalled tools"
  echo "3. Fix common PATH issues"
  echo "4. Return to main menu"
  echo -n "Select an option: "
  read -r path_choice
  
  case "$path_choice" in
    1) cleanup_broken_path ;;
    2) remove_tool_references ;;
    3) fix_path_issues ;;
    4) return ;;
    *) log --warn "Invalid choice. Returning to main menu."; return ;;
  esac
}

# Clean up broken PATH entries
cleanup_broken_path() {
  echo -e "\n${BLUE}--- Detecting Broken PATH Entries ---${NC}"
  
  local original_path="$PATH"
  local new_path=""
  local broken_count=0
  local broken_list=""
  
  IFS=':' read -r -a path_array <<< "$original_path"
  for dir in "${path_array[@]}"; do
    if [[ -d "$dir" ]]; then
      if [[ -n "$new_path" ]]; then
        new_path="$new_path:$dir"
      else
        new_path="$dir"
      fi
    else
      log --warn "Broken PATH entry: $dir"
      broken_count=$((broken_count + 1))
      broken_list="$broken_list\n- $dir"
    fi
  done
  
  if [[ $broken_count -eq 0 ]]; then
    log "No broken PATH entries found."
    return
  fi
  
  echo -e "\nFound $broken_count broken PATH entries:$broken_list"
  
  if confirm "Remove these broken PATH entries?"; then
    # Find shell config files
    local shell_files=(
      "$HOME/.bash_profile"
      "$HOME/.bashrc"
      "$HOME/.zshrc"
      "$HOME/.profile"
    )
    
    # Check which config files exist
    local config_files=()
    for file in "${shell_files[@]}"; do
      if [[ -f "$file" ]]; then
        config_files+=("$file")
      fi
    done
    
    if [[ ${#config_files[@]} -eq 0 ]]; then
      log --warn "No shell configuration files found."
      return
    fi
    
    # Display config files with numbers for selection
    echo "Found the following configuration files:"
    for i in "${!config_files[@]}"; do
      echo "$((i+1)). ${config_files[$i]}"
    done
    
    echo -n "Select file to edit (or 0 for all): "
    read -r file_num
    
    if [[ $file_num -eq 0 ]]; then
      # Edit all found config files
      for config_file in "${config_files[@]}"; do
        cleanup_path_in_file "$config_file" "$broken_list"
      done
    elif [[ $file_num -le ${#config_files[@]} ]]; then
      # Edit selected config file
      cleanup_path_in_file "${config_files[$file_num-1]}" "$broken_list"
    else
      log --warn "Invalid selection."
    fi
    
    # Handle current session
    if confirm "Update current session PATH?"; then
      export PATH="$new_path"
      log "Current session PATH updated."
    fi
  fi
}

# Helper function to clean PATH in a specific file
cleanup_path_in_file() {
  local file="$1"
  local broken_entries="$2"
  
  log "Examining $file for PATH modifications..."
  
  # Create backup
  backup_item "$file"
  
  # Process file line by line, adjust PATH entries
  local tmp_file=$(mktemp)
  local modified=0
  
  while IFS= read -r line; do
    if [[ "$line" == *"PATH="* || "$line" == *"export PATH"* ]]; then
      log --debug "Found PATH definition: $line"
      
      # Check if line contains any of the broken entries
      local skip=0
      while read -r broken_entry; do
        if [[ "$line" == *"$broken_entry"* && -n "$broken_entry" ]]; then
          log "Modifying line containing broken entry: $broken_entry"
          
          # Handle different PATH formats
          if [[ "$line" == *"PATH=\"\$PATH:"* ]]; then
            # Format: PATH="$PATH:/broken/path"
            # Remove the broken entry from the line
            local broken_pattern=$(echo "$broken_entry" | sed 's/[\/&]/\\&/g')
            local modified_line=$(echo "$line" | sed "s/:$broken_pattern//" | sed "s/$broken_pattern://")
            echo "$modified_line" >> "$tmp_file"
          elif [[ "$line" == *"PATH="* && "$line" == *":"* ]]; then
            # Format: PATH="/path:/broken/path:/other/path"
            local broken_pattern=$(echo "$broken_entry" | sed 's/[\/&]/\\&/g')
            local modified_line=$(echo "$line" | sed "s/:$broken_pattern//" | sed "s/$broken_pattern://")
            echo "$modified_line" >> "$tmp_file"
          else
            # Unknown format, better not to modify
            echo "$line" >> "$tmp_file"
          fi
          
          modified=1
          skip=1
          break
        fi
      done <<< "$broken_entries"
      
      if [[ $skip -eq 0 ]]; then
        echo "$line" >> "$tmp_file"
      fi
    else
      echo "$line" >> "$tmp_file"
    fi
  done < "$file"
  
  if [[ $modified -eq 1 ]]; then
    # Replace original file with modified version
    run_command mv "$tmp_file" "$file"
    log "Modified PATH definitions in $file"
  else
    rm "$tmp_file"
    log "No PATH modifications found in $file"
  fi
}

# Remove references to uninstalled tools
remove_tool_references() {
  echo -e "\n${BLUE}--- Removing References to Uninstalled Tools ---${NC}"
  
  # Common locations for tool references
  local tool_ref_locations=(
    "$HOME/.bash_profile"
    "$HOME/.bashrc"
    "$HOME/.zshrc"
    "$HOME/.profile"
    "$HOME/.config/fish/config.fish"
  )
  
  # Common tool prefixes to detect
  local tool_prefixes=(
    "brew"
    "nvm"
    "rvm"
    "pyenv"
    "rbenv"
    "nodenv"
    "jenv"
    "goenv"
    "phpenv"
    "plenv"
    "cargo"
    "rustup"
    "conda"
    "heroku"
    "kubectl"
    "docker"
    "composer"
    "yarn"
    "npm"
    "pod"
    "gem"
    "pip"
  )
  
  # Map of tool prefixes to installation paths
  declare -A tool_paths
  tool_paths["brew"]="/usr/local/bin/brew /opt/homebrew/bin/brew"
  tool_paths["nvm"]="$HOME/.nvm/nvm.sh"
  tool_paths["rvm"]="$HOME/.rvm/scripts/rvm"
  tool_paths["pyenv"]="$HOME/.pyenv/bin/pyenv"
  tool_paths["rbenv"]="$HOME/.rbenv/bin/rbenv"
  tool_paths["nodenv"]="$HOME/.nodenv/bin/nodenv"
  tool_paths["jenv"]="$HOME/.jenv/bin/jenv"
  tool_paths["goenv"]="$HOME/.goenv/bin/goenv"
  tool_paths["phpenv"]="$HOME/.phpenv/bin/phpenv"
  tool_paths["plenv"]="$HOME/.plenv/bin/plenv"
  tool_paths["cargo"]="$HOME/.cargo/bin/cargo"
  tool_paths["rustup"]="$HOME/.cargo/bin/rustup"
  tool_paths["conda"]="/usr/local/anaconda3/bin/conda $HOME/anaconda3/bin/conda $HOME/miniconda3/bin/conda"
  tool_paths["heroku"]="/usr/local/bin/heroku"
  tool_paths["kubectl"]="/usr/local/bin/kubectl"
  tool_paths["docker"]="/usr/local/bin/docker"
  tool_paths["composer"]="/usr/local/bin/composer $HOME/.composer/vendor/bin/composer"
  tool_paths["yarn"]="/usr/local/bin/yarn"
  tool_paths["npm"]="/usr/local/bin/npm"
  tool_paths["pod"]="/usr/local/bin/pod"
  tool_paths["gem"]="/usr/bin/gem /usr/local/bin/gem"
  tool_paths["pip"]="/usr/local/bin/pip /usr/bin/pip"
  
  # Check which tools are missing
  local missing_tools=()
  for tool in "${tool_prefixes[@]}"; do
    local found=0
    for path in ${tool_paths[$tool]}; do
      if [[ -e "$path" ]]; then
        found=1
        break
      fi
    done
    
    if [[ $found -eq 0 ]]; then
      missing_tools+=("$tool")
    fi
  done
  
  if [[ ${#missing_tools[@]} -eq 0 ]]; then
    log "No missing tools detected."
    return
  fi
  
  echo -e "\nThe following tools appear to be missing or uninstalled:"
  for tool in "${missing_tools[@]}"; do
    echo "- $tool"
  done
  
  # Check for references in config files
  local found_refs=0
  
  for tool in "${missing_tools[@]}"; do
    for config_file in "${tool_ref_locations[@]}"; do
      if [[ -f "$config_file" ]]; then
        # Check for tool references
        if grep -q "$tool" "$config_file"; then
          echo "Found references to '$tool' in $config_file"
          found_refs=1
        fi
      fi
    done
  done
  
  if [[ $found_refs -eq 0 ]]; then
    log "No references to uninstalled tools found in config files."
    return
  fi
  
  if confirm "Would you like to remove references to these uninstalled tools?"; then
    for tool in "${missing_tools[@]}"; do
      for config_file in "${tool_ref_locations[@]}"; do
        if [[ -f "$config_file" && -w "$config_file" ]]; then
          # Check for tool references
          if grep -q "$tool" "$config_file"; then
            log "Removing references to '$tool' in $config_file"
            
            # Create backup
            backup_item "$config_file"
            
            # Create temporary file
            local tmp_file=$(mktemp)
            
            # Process file line by line
            while IFS= read -r line; do
              if [[ "$line" != *"$tool"* ]]; then
                echo "$line" >> "$tmp_file"
              else
                # Comment out the line instead of deleting
                echo "# $line # Disabled by cleanup script - tool appears to be uninstalled" >> "$tmp_file"
              fi
            done < "$config_file"
            
            # Replace original with modified file
            run_command mv "$tmp_file" "$config_file"
          fi
        fi
      done
    done
    
    log "References to uninstalled tools have been commented out in config files."
  fi
}

# Fix common PATH issues
fix_path_issues() {
  echo -e "\n${BLUE}--- Fixing Common PATH Issues ---${NC}"
  
  # Check for PATH duplication
  local original_path="$PATH"
  local unique_path=""
  local seen=()
  local duplicates=0
  
  IFS=':' read -r -a path_array <<< "$original_path"
  for dir in "${path_array[@]}"; do
    if [[ " ${seen[*]} " != *" $dir "* ]]; then
      seen+=("$dir")
      
      if [[ -n "$unique_path" ]]; then
        unique_path="$unique_path:$dir"
      else
        unique_path="$dir"
      fi
    else
      log "Duplicate PATH entry: $dir"
      duplicates=$((duplicates + 1))
    fi
  done
  
  if [[ $duplicates -gt 0 ]]; then
    log "Found $duplicates duplicate PATH entries."
    if confirm "Remove duplicate PATH entries?"; then
      export PATH="$unique_path"
      
      # Update shell config files
      fix_duplicates_in_config
    fi
  else
    log "No duplicate PATH entries found."
  fi
  
  # Check for problematic PATH order
  echo -e "\n${CYAN}Checking PATH order...${NC}"
  
  # Common PATH order issues to check
  if [[ "$PATH" == "/usr/bin:"* ]]; then
    echo "${YELLOW}System paths appear before user paths, which might prevent custom tool versions from being used.${NC}"
    if confirm "Fix PATH order to prioritize user paths?"; then
      fix_path_order_in_config
    fi
  fi
  
  # Check for missing important directories
  local important_dirs=(
    "$HOME/bin"
    "$HOME/.local/bin"
    "/usr/local/bin"
    "/opt/homebrew/bin"
  )
  
  local missing=()
  for dir in "${important_dirs[@]}"; do
    if [[ -d "$dir" && "$PATH" != *"$dir"* ]]; then
      missing+=("$dir")
    fi
  done
  
  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "${YELLOW}Some important directories are missing from your PATH:${NC}"
    for dir in "${missing[@]}"; do
      echo "- $dir"
    done
    
    if confirm "Add these directories to your PATH?"; then
      add_missing_dirs_to_path "${missing[@]}"
    fi
  else
    log "No missing important directories in PATH."
  fi
}

# Helper function to fix duplicates in config files
fix_duplicates_in_config() {
  local shell_files=(
    "$HOME/.bash_profile"
    "$HOME/.bashrc"
    "$HOME/.zshrc"
    "$HOME/.profile"
  )
  
  for file in "${shell_files[@]}"; do
    if [[ -f "$file" && -w "$file" ]]; then
      log "Checking $file for PATH duplications..."
      
      # Create backup
      backup_item "$file"
      
      # Check if file contains PATH manipulation
      if grep -q "PATH=" "$file"; then
        log "Found PATH settings in $file"
        
        # Create temporary file for modified contents
        local tmp_file=$(mktemp)
        
        # Add a new optimized PATH setting at the end of the file
        cat "$file" > "$tmp_file"
        
        echo -e "\n# Optimized PATH setting added by cleanup script" >> "$tmp_file"
        echo "export PATH=\"$(echo "$unique_path" | sed 's/:/\\:/g')\"  # Deduplicated by cleanup script" >> "$tmp_file"
        
        # Replace original with modified file
        run_command mv "$tmp_file" "$file"
        log "Updated PATH in $file"
      fi
    fi
  done
}

# Helper function to fix PATH order in config files
fix_path_order_in_config() {
  local shell_files=(
    "$HOME/.bash_profile"
    "$HOME/.bashrc"
    "$HOME/.zshrc"
    "$HOME/.profile"
  )
  
  # Define ideal PATH order
  local ideal_path=""
  local user_dirs=(
    "$HOME/bin"
    "$HOME/.local/bin"
    "$HOME/.cargo/bin"
    "$HOME/go/bin"
    "$HOME/.npm/bin"
    "/usr/local/bin"
    "/usr/local/sbin"
    "/opt/homebrew/bin"
    "/opt/homebrew/sbin"
  )
  
  # Start with user directories that exist
  for dir in "${user_dirs[@]}"; do
    if [[ -d "$dir" ]]; then
      if [[ -n "$ideal_path" ]]; then
        ideal_path="$ideal_path:$dir"
      else
        ideal_path="$dir"
      fi
    fi
  done
  
  # Add system directories
  ideal_path="$ideal_path:/usr/bin:/bin:/usr/sbin:/sbin"
  
  # Add any other directories from original PATH not covered above
  IFS=':' read -r -a path_array <<< "$PATH"
  for dir in "${path_array[@]}"; do
    if [[ "$ideal_path" != *"$dir"* && -d "$dir" ]]; then
      ideal_path="$ideal_path:$dir"
    fi
  done
  
  for file in "${shell_files[@]}"; do
    if [[ -f "$file" && -w "$file" ]]; then
      # Create backup
      backup_item "$file"
      
      # Create temporary file
      local tmp_file=$(mktemp)
      
      # Add content without PATH manipulations
      grep -v "PATH=" "$file" > "$tmp_file"
      
      # Add optimized PATH at the end
      echo -e "\n# Optimized PATH with user paths prioritized - added by cleanup script" >> "$tmp_file"
      echo "export PATH=\"$ideal_path\"" >> "$tmp_file"
      
      # Replace original with modified file
      run_command mv "$tmp_file" "$file"
      log "Updated PATH order in $file"
    fi
  done
  
  # Update current session
  export PATH="$ideal_path"
  log "Current session PATH order updated."
}

# Helper function to add missing directories to PATH
add_missing_dirs_to_path() {
  local missing_dirs=("$@")
  local current_path="$PATH"
  
  # Add missing directories to PATH
  for dir in "${missing_dirs[@]}"; do
    current_path="$dir:$current_path"
  done
  
  # Update current session
  export PATH="$current_path"
  
  # Update shell config files
  local shell_files=(
    "$HOME/.bash_profile"
    "$HOME/.bashrc"
    "$HOME/.zshrc"
    "$HOME/.profile"
  )
  
  # Determine primary shell config
  local primary_config=""
  if [[ "$SHELL" == *"zsh"* && -f "$HOME/.zshrc" ]]; then
    primary_config="$HOME/.zshrc"
  elif [[ "$SHELL" == *"bash"* ]]; then
    if [[ -f "$HOME/.bash_profile" ]]; then
      primary_config="$HOME/.bash_profile"
    elif [[ -f "$HOME/.bashrc" ]]; then
      primary_config="$HOME/.bashrc"
    fi
  elif [[ -f "$HOME/.profile" ]]; then
    primary_config="$HOME/.profile"
  fi
  
  if [[ -n "$primary_config" ]]; then
    # Create backup
    backup_item "$primary_config"
    
    # Add missing directories to PATH in config
    local tmp_file=$(mktemp)
    cat "$primary_config" > "$tmp_file"
    
    echo -e "\n# Additional directories added to PATH by cleanup script" >> "$tmp_file"
    for dir in "${missing_dirs[@]}"; do
      echo "export PATH=\"$dir:\$PATH\"" >> "$tmp_file"
    done
    
    # Replace original with modified file
    run_command mv "$tmp_file" "$primary_config"
    log "Updated PATH in $primary_config"
  else
    log --warn "Could not determine primary shell config file to update."
  fi
} 