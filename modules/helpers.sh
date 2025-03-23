#!/bin/bash

# helpers.sh - Helper functions for the CR - Mac Helper

# Initialize log file with proper permissions
init_log() {
  mkdir -p "$(dirname "$LOGFILE")" 2>/dev/null
  touch "$LOGFILE" 2>/dev/null || {
    LOGFILE="/tmp/cr_mac_helper_$(date +%s).log"
    echo "Warning: Could not write to original log location. Using $LOGFILE instead."
    touch "$LOGFILE"
  }
  echo "=== CR - Mac Helper Log Started $(date) ===" >> "$LOGFILE"
}

# Logging function with verbosity control
log() {
  local level="INFO"
  if [[ "$1" == "--warn" ]]; then
    level="WARNING"
    shift
  elif [[ "$1" == "--error" ]]; then
    level="ERROR"
    shift
  elif [[ "$1" == "--debug" ]]; then
    level="DEBUG"
    shift
    # Only print debug messages when verbose
    if [[ $VERBOSE -eq 0 ]]; then
      echo "$(date +%Y-%m-%d\ %H:%M:%S) - [$level] $1" >> "$LOGFILE"
      return
    fi
  fi
  
  echo "$(date +%Y-%m-%d\ %H:%M:%S) - [$level] $1" >> "$LOGFILE"
  
  # Terminal output with color based on log level
  case "$level" in
    WARNING) echo -e "${YELLOW}$1${NC}" ;;
    ERROR) echo -e "${RED}$1${NC}" ;;
    DEBUG) echo -e "${CYAN}$1${NC}" ;;
    *) echo -e "$1" ;;
  esac
}

# Error handling function with improved context
error_exit() {
  log --error "$1"
  log --error "Last command exit code: $?"
  log --error "Script terminated at line ${BASH_LINENO[0]}"
  exit 1
}

# Check if running as root and warn if not
check_privileges() {
  if [[ $EUID -ne 0 && $1 -eq 1 ]]; then
    log --warn "Some operations may require elevated privileges. Consider running with sudo for full functionality."
    if confirm "Continue anyway?"; then
      return 0
    else
      exit 0
    fi
  fi
}

# Enhanced confirmation function with timeout
confirm() {
  local prompt="$1"
  local timeout="${2:-0}"  # Default no timeout
  local default="${3:-n}"  # Default answer
  
  # Add color to prompt based on operation risk
  if [[ "$prompt" == *"dangerous"* || "$prompt" == *"remove"* || "$prompt" == *"delete"* ]]; then
    prompt="${RED}$prompt${NC}"
  fi
  
  if [[ $timeout -gt 0 ]]; then
    prompt="$prompt (${timeout}s timeout, default: $default)"
  fi
  
  while true; do
    if [[ $timeout -gt 0 ]]; then
      read -r -t "$timeout" -p "$prompt [y/N] " response || {
        echo
        echo "Timeout reached, using default: $default"
        [[ "$default" == "y" ]] && return 0 || return 1
      }
    else
      read -r -p "$prompt [y/N] " response
    fi
    
    case "$response" in
      [yY][eE][sS]|[yY])
        return 0
        ;;
      [nN][oO]|[nN]|"")
        return 1
        ;;
      *)
        echo "Please answer yes or no."
        ;;
    esac
  done
}

# Dry-run wrapper with improved output
run_command() {
  # Save command for logging
  local cmd_str=""
  for arg in "$@"; do
    if [[ "$arg" == *" "* ]]; then
      cmd_str+="\"$arg\" "
    else
      cmd_str+="$arg "
    fi
  done
  
  log --debug "Executing: $cmd_str"
  
  if [[ $DRY_RUN -eq 1 ]]; then
    echo -e "${YELLOW}DRY RUN: $cmd_str${NC}"
    return 0
  else
    # Run with error catching
    "$@"
    local ret=$?
    if [[ $ret -ne 0 ]]; then
      log --warn "Command returned non-zero exit code: $ret"
    fi
    return $ret
  fi
}

# Enhanced backup function with size estimation and compression
backup_item() {
  local item="$1"
  local force="${2:-0}"  # Force backup even if file doesn't exist
  
  if [[ ! -e "$item" && $force -eq 0 ]]; then
    log --debug "Skipping backup of non-existent item: $item"
    return 0
  fi
  
  # Create backup directory structure
  local item_path=$(dirname "$item")
  local backup_path="$BACKUP_DIR/${item_path#/}"
  
  log "Backing up $item"
  if [[ $DRY_RUN -eq 0 ]]; then
    mkdir -p "$backup_path" || {
      log --warn "Failed to create backup directory at $backup_path. Trying alternate location."
      backup_path="$BACKUP_DIR/fallback/$(basename "$item")"
      mkdir -p "$(dirname "$backup_path")" || error_exit "Failed to create backup directory."
    }
    
    # Check if it's a directory - if so, use tar with compression
    if [[ -d "$item" ]]; then
      local archive_name="$(basename "$item").tar.gz"
      log --debug "Compressing directory for backup: $item -> $backup_path/$archive_name"
      run_command tar -czf "$backup_path/$archive_name" -C "$(dirname "$item")" "$(basename "$item")" 2>/dev/null
      if [[ $? -ne 0 ]]; then
        log --warn "Failed to compress backup of '$item'. Attempting direct copy."
        # Fall back to cp if tar fails
        run_command cp -Rp "$item" "$backup_path/" 2>/dev/null
        if [[ $? -ne 0 ]]; then
          log --warn "Failed to backup '$item'. Some files may have permission issues."
        fi
      fi
    else
      # Regular file copy
      run_command cp -p "$item" "$backup_path/" 2>/dev/null
      if [[ $? -ne 0 ]]; then
        log --warn "Failed to backup '$item'. File may have permission issues."
      fi
    fi
  fi
}

# Check disk space before performing operations
check_disk_space() {
  local required=$1  # Required space in MB
  local available=$(df -m / | awk 'NR==2 {print $4}')
  
  if [[ $available -lt $required ]]; then
    log --warn "Low disk space: ${available}MB available, ${required}MB recommended."
    if ! confirm "Continue despite low disk space?"; then
      return 1
    fi
  fi
  return 0
} 