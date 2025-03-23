#!/bin/bash

# login_items.sh - Login items management functions

# Main login items management function
login_items_management() {
  echo -e "\n${BLUE}=== Login Items Management ===${NC}"
  
  echo "1. View current login items"
  echo "2. Add a new login item"
  echo "3. Remove login items"
  echo "4. Return to main menu"
  echo -n "Select an option: "
  read -r login_choice
  
  case "$login_choice" in
    1) view_login_items ;;
    2) add_login_item ;;
    3) remove_login_items ;;
    4) return ;;
    *) log --warn "Invalid choice. Returning to main menu."; return ;;
  esac
}

# Display current login items
view_login_items() {
  echo -e "\n${BLUE}--- Current Login Items ---${NC}"
  
  # Use AppleScript to get login items
  osascript -e 'tell application "System Events" to get the name of every login item' 2>/dev/null
  
  echo
  read -n 1 -s -r -p "Press any key to continue..."
}

# Add a new login item
add_login_item() {
  echo -e "\n${BLUE}--- Add New Login Item ---${NC}"
  
  echo "Enter the full path to the application (or drag and drop it here):"
  read -r app_path
  
  # Clean up path if drag and drop was used
  app_path=$(echo "$app_path" | sed 's/^[ \t]*//;s/[ \t]*$//')
  
  if [[ ! -e "$app_path" ]]; then
    log --warn "Application not found: $app_path"
    return
  fi
  
  # Add to login items using AppleScript
  osascript -e "tell application \"System Events\" to make login item at end with properties {path:\"$app_path\", hidden:false}" 2>/dev/null
  
  if [[ $? -eq 0 ]]; then
    log "Added $(basename "$app_path") to login items."
  else
    log --error "Failed to add $(basename "$app_path") to login items."
  fi
}

# Remove login items
remove_login_items() {
  echo -e "\n${BLUE}--- Remove Login Items ---${NC}"
  
  # Get login items using AppleScript
  local login_items=$(osascript -e 'tell application "System Events" to get the name of every login item' 2>/dev/null)
  
  if [[ -z "$login_items" ]]; then
    log "No login items found."
    return
  fi
  
  # Display login items with numbers
  echo "Current login items:"
  local count=1
  IFS=', ' read -r -a item_array <<< "$login_items"
  for item in "${item_array[@]}"; do
    item=$(echo "$item" | sed 's/^"//;s/"$//')  # Remove quotes if present
    echo "$count. $item"
    count=$((count + 1))
  done
  
  echo
  echo "Enter the number of the login item to remove (or 0 to cancel):"
  read -r item_num
  
  if [[ "$item_num" == "0" ]]; then
    return
  fi
  
  if [[ "$item_num" =~ ^[0-9]+$ && "$item_num" -le "${#item_array[@]}" ]]; then
    local item_to_remove="${item_array[$item_num-1]}"
    item_to_remove=$(echo "$item_to_remove" | sed 's/^"//;s/"$//')  # Remove quotes if present
    
    # Remove login item using AppleScript
    osascript -e "tell application \"System Events\" to delete login item \"$item_to_remove\"" 2>/dev/null
    
    if [[ $? -eq 0 ]]; then
      log "Removed $item_to_remove from login items."
    else
      log --error "Failed to remove $item_to_remove from login items."
    fi
  else
    log --warn "Invalid selection."
  fi
} 