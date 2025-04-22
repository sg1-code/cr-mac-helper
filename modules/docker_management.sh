#!/bin/bash

# docker_management.sh - Docker container, image, and volume management

# Main Docker management function
docker_management() {
  echo -e "\n${BLUE}=== Docker Management ===${NC}"
  check_privileges 0  # Doesn't absolutely require root
  
  # Check if Docker is installed
  if ! command -v docker &> /dev/null; then
    log --warn "Docker is not installed or not in your PATH."
    
    if confirm "Would you like to know how to install Docker for Mac?"; then
      echo -e "\n${BLUE}--- Docker Installation Guide ---${NC}"
      echo "Docker Desktop for Mac can be installed in several ways:"
      echo
      echo "1. Download from the official website:"
      echo "   https://www.docker.com/products/docker-desktop"
      echo
      echo "2. Using Homebrew:"
      echo "   brew install --cask docker"
      echo
      echo "3. Using Mac App Store (if available)"
      echo
      echo "After installation, launch Docker Desktop and complete the setup process."
      echo "Then run this module again to manage your Docker resources."
    fi
    
    echo
    read -n 1 -s -r -p "Press any key to return to main menu..."
    return
  fi
  
  # Check if Docker daemon is running
  if ! docker info &>/dev/null; then
    log --warn "Docker daemon is not running."
    
    if confirm "Would you like to start Docker?"; then
      log "Attempting to start Docker..."
      
      # Try to open Docker Desktop
      if [[ -d "/Applications/Docker.app" ]]; then
        run_command open -a Docker
        
        log "Docker Desktop is starting..."
        log "Please wait for Docker to fully start, then run this module again."
      else
        log --warn "Docker Desktop not found in /Applications."
        log --warn "Please start Docker manually and run this module again."
      fi
      
      echo
      read -n 1 -s -r -p "Press any key to return to main menu..."
      return
    else
      echo
      read -n 1 -s -r -p "Press any key to return to main menu..."
      return
    fi
  fi
  
  echo "1. Show Docker system information and disk usage"
  echo "2. Manage containers"
  echo "3. Manage images"
  echo "4. Manage volumes"
  echo "5. Clean unused Docker resources"
  echo "6. Manage Docker configuration"
  echo "7. Return to main menu"
  echo -n "Select an option: "
  read -r docker_choice
  
  case "$docker_choice" in
    1) show_docker_info ;;
    2) manage_containers ;;
    3) manage_images ;;
    4) manage_volumes ;;
    5) clean_docker_resources ;;
    6) manage_docker_config ;;
    7) return ;;
    *) log --warn "Invalid choice. Returning to main menu."; return ;;
  esac
}

# Show Docker system information and disk usage
show_docker_info() {
  echo -e "\n${BLUE}--- Docker System Information ---${NC}"
  
  log "Gathering Docker system information..."
  
  # Create temporary file for report
  local report_file=$(mktemp)
  echo "Docker System Report" > "$report_file"
  echo "Generated: $(date)" >> "$report_file"
  echo "====================" >> "$report_file"
  echo "" >> "$report_file"
  
  # System information
  echo "### Docker Version ###" >> "$report_file"
  docker version >> "$report_file"
  echo "" >> "$report_file"
  
  # Docker info
  echo "### Docker Info ###" >> "$report_file"
  docker info >> "$report_file"
  echo "" >> "$report_file"
  
  # Disk usage
  echo "### Docker Disk Usage ###" >> "$report_file"
  docker system df -v >> "$report_file"
  echo "" >> "$report_file"
  
  # Container summary
  echo "### Container Summary ###" >> "$report_file"
  echo "Running Containers: $(docker ps -q | wc -l | tr -d ' ')" >> "$report_file"
  echo "All Containers: $(docker ps -a -q | wc -l | tr -d ' ')" >> "$report_file"
  echo "" >> "$report_file"
  
  # Top 10 largest containers
  echo "### Top 10 Largest Containers ###" >> "$report_file"
  docker ps -a --size --format "table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Size}}" | head -11 >> "$report_file"
  echo "" >> "$report_file"
  
  # Image summary
  echo "### Image Summary ###" >> "$report_file"
  echo "Total Images: $(docker images -q | wc -l | tr -d ' ')" >> "$report_file"
  echo "Dangling Images: $(docker images -f dangling=true -q | wc -l | tr -d ' ')" >> "$report_file"
  echo "" >> "$report_file"
  
  # Top 10 largest images
  echo "### Top 10 Largest Images ###" >> "$report_file"
  docker images --format "table {{.Repository}}:{{.Tag}}\t{{.ID}}\t{{.Size}}" | head -11 >> "$report_file"
  echo "" >> "$report_file"
  
  # Volume summary
  echo "### Volume Summary ###" >> "$report_file"
  echo "Total Volumes: $(docker volume ls -q | wc -l | tr -d ' ')" >> "$report_file"
  echo "" >> "$report_file"
  
  # Build cache information
  echo "### Build Cache ###" >> "$report_file"
  docker builder prune -f --keep-storage 0 --dry-run 2>&1 | grep "Total" >> "$report_file" || echo "No build cache information available" >> "$report_file"
  echo "" >> "$report_file"
  
  # Display the report
  less "$report_file"
  
  # Offer to save the report
  if confirm "Would you like to save this Docker system report to your Desktop?"; then
    local report_path="$HOME/Desktop/docker_report_$(date +%Y%m%d_%H%M%S).txt"
    cp "$report_file" "$report_path"
    log "Docker system report saved to: $report_path"
  fi
  
  # Clean up
  rm "$report_file"
  
  echo
  read -n 1 -s -r -p "Press any key to continue..."
  docker_management
}

# Manage Docker containers
manage_containers() {
  echo -e "\n${BLUE}--- Docker Container Management ---${NC}"
  
  echo "1. List containers"
  echo "2. Start a stopped container"
  echo "3. Stop a running container"
  echo "4. Remove selected containers"
  echo "5. Remove all stopped containers"
  echo "6. View container logs"
  echo "7. Return to Docker menu"
  echo -n "Select an option: "
  read -r container_choice
  
  case "$container_choice" in
    1) list_containers ;;
    2) start_container ;;
    3) stop_container ;;
    4) remove_container ;;
    5) remove_stopped_containers ;;
    6) view_container_logs ;;
    7) docker_management ;;
    *) log --warn "Invalid choice."; manage_containers ;;
  esac
}

# List containers
list_containers() {
  echo -e "\n${BLUE}--- Docker Container List ---${NC}"
  
  echo "1. Show running containers"
  echo "2. Show all containers"
  echo "3. Show container stats"
  echo -n "Select an option: "
  read -r list_option
  
  case "$list_option" in
    1) 
      echo -e "\n${CYAN}Running Containers:${NC}"
      docker ps
      ;;
    2)
      echo -e "\n${CYAN}All Containers:${NC}"
      docker ps -a
      ;;
    3)
      echo -e "\n${CYAN}Container Stats:${NC}"
      echo "Press Ctrl+C to exit stats view"
      echo
      sleep 2
      docker stats
      ;;
    *) log --warn "Invalid choice." ;;
  esac
  
  echo
  read -n 1 -s -r -p "Press any key to continue..."
  manage_containers
}

# Start a stopped container
start_container() {
  echo -e "\n${BLUE}--- Start Docker Container ---${NC}"
  
  # Get list of stopped containers
  local containers=$(docker ps -a --filter "status=exited" --filter "status=created" --format "{{.ID}}|{{.Names}}|{{.Image}}|{{.Status}}")
  
  if [[ -z "$containers" ]]; then
    log "No stopped containers found."
    echo
    read -n 1 -s -r -p "Press any key to continue..."
    manage_containers
    return
  fi
  
  # Display containers with numbers
  echo -e "${CYAN}Stopped Containers:${NC}"
  echo -e "NUM\tCONTAINER ID\tNAME\t\tIMAGE\t\tSTATUS"
  
  local i=1
  echo "$containers" | while IFS="|" read -r id name image status; do
    printf "%d\t%s\t%s\t\t%s\t\t%s\n" $i "$id" "$name" "$image" "$status"
    ((i++))
  done
  
  echo -n "Enter the number of the container to start (or 0 to cancel): "
  read -r container_num
  
  if [[ $container_num -eq 0 || -z "$container_num" ]]; then
    manage_containers
    return
  fi
  
  # Get container ID from selection
  local selected_container=$(echo "$containers" | sed -n "${container_num}p" | cut -d'|' -f1)
  
  if [[ -n "$selected_container" ]]; then
    log "Starting container: $selected_container"
    run_command docker start "$selected_container"
  else
    log --warn "Invalid selection."
  fi
  
  echo
  read -n 1 -s -r -p "Press any key to continue..."
  manage_containers
}

# Stop a running container
stop_container() {
  echo -e "\n${BLUE}--- Stop Docker Container ---${NC}"
  
  # Get list of running containers
  local containers=$(docker ps --format "{{.ID}}|{{.Names}}|{{.Image}}|{{.Status}}")
  
  if [[ -z "$containers" ]]; then
    log "No running containers found."
    echo
    read -n 1 -s -r -p "Press any key to continue..."
    manage_containers
    return
  fi
  
  # Display containers with numbers
  echo -e "${CYAN}Running Containers:${NC}"
  echo -e "NUM\tCONTAINER ID\tNAME\t\tIMAGE\t\tSTATUS"
  
  local i=1
  echo "$containers" | while IFS="|" read -r id name image status; do
    printf "%d\t%s\t%s\t\t%s\t\t%s\n" $i "$id" "$name" "$image" "$status"
    ((i++))
  done
  
  echo -n "Enter the number of the container to stop (or 0 to cancel): "
  read -r container_num
  
  if [[ $container_num -eq 0 || -z "$container_num" ]]; then
    manage_containers
    return
  fi
  
  # Get container ID from selection
  local selected_container=$(echo "$containers" | sed -n "${container_num}p" | cut -d'|' -f1)
  
  if [[ -n "$selected_container" ]]; then
    log "Stopping container: $selected_container"
    run_command docker stop "$selected_container"
  else
    log --warn "Invalid selection."
  fi
  
  echo
  read -n 1 -s -r -p "Press any key to continue..."
  manage_containers
}

# Remove selected containers
remove_container() {
  echo -e "\n${BLUE}--- Remove Docker Container ---${NC}"
  
  # Get list of all containers
  local containers=$(docker ps -a --format "{{.ID}}|{{.Names}}|{{.Image}}|{{.Status}}")
  
  if [[ -z "$containers" ]]; then
    log "No containers found."
    echo
    read -n 1 -s -r -p "Press any key to continue..."
    manage_containers
    return
  fi
  
  # Display containers with numbers
  echo -e "${CYAN}All Containers:${NC}"
  echo -e "NUM\tCONTAINER ID\tNAME\t\tIMAGE\t\tSTATUS"
  
  local i=1
  echo "$containers" | while IFS="|" read -r id name image status; do
    printf "%d\t%s\t%s\t\t%s\t\t%s\n" $i "$id" "$name" "$image" "$status"
    ((i++))
  done
  
  echo -n "Enter the number of the container to remove (or 0 to cancel): "
  read -r container_num
  
  if [[ $container_num -eq 0 || -z "$container_num" ]]; then
    manage_containers
    return
  fi
  
  # Get container ID from selection
  local selected_container=$(echo "$containers" | sed -n "${container_num}p" | cut -d'|' -f1)
  
  if [[ -n "$selected_container" ]]; then
    if confirm "Are you sure you want to remove this container? This action cannot be undone."; then
      # Check if container is running
      if docker ps -q --filter "id=$selected_container" | grep -q .; then
        log "Container is running. Stopping first..."
        run_command docker stop "$selected_container"
      fi
      
      log "Removing container: $selected_container"
      run_command docker rm "$selected_container"
      
      if [[ $? -ne 0 ]]; then
        log --warn "Failed to remove container. Try using -f to force removal."
        if confirm "Force remove container?"; then
          run_command docker rm -f "$selected_container"
        fi
      fi
    fi
  else
    log --warn "Invalid selection."
  fi
  
  echo
  read -n 1 -s -r -p "Press any key to continue..."
  manage_containers
}

# Remove all stopped containers
remove_stopped_containers() {
  echo -e "\n${BLUE}--- Remove All Stopped Containers ---${NC}"
  
  # Count stopped containers
  local count=$(docker ps -a --filter "status=exited" --filter "status=created" -q | wc -l | tr -d ' ')
  
  if [[ $count -eq 0 ]]; then
    log "No stopped containers found."
    echo
    read -n 1 -s -r -p "Press any key to continue..."
    manage_containers
    return
  fi
  
  if confirm "Are you sure you want to remove all $count stopped containers?"; then
    log "Removing all stopped containers..."
    run_command docker container prune -f
  fi
  
  echo
  read -n 1 -s -r -p "Press any key to continue..."
  manage_containers
}

# View container logs
view_container_logs() {
  echo -e "\n${BLUE}--- View Container Logs ---${NC}"
  
  # Get list of all containers
  local containers=$(docker ps -a --format "{{.ID}}|{{.Names}}|{{.Image}}|{{.Status}}")
  
  if [[ -z "$containers" ]]; then
    log "No containers found."
    echo
    read -n 1 -s -r -p "Press any key to continue..."
    manage_containers
    return
  fi
  
  # Display containers with numbers
  echo -e "${CYAN}All Containers:${NC}"
  echo -e "NUM\tCONTAINER ID\tNAME\t\tIMAGE\t\tSTATUS"
  
  local i=1
  echo "$containers" | while IFS="|" read -r id name image status; do
    printf "%d\t%s\t%s\t\t%s\t\t%s\n" $i "$id" "$name" "$image" "$status"
    ((i++))
  done
  
  echo -n "Enter the number of the container to view logs (or 0 to cancel): "
  read -r container_num
  
  if [[ $container_num -eq 0 || -z "$container_num" ]]; then
    manage_containers
    return
  fi
  
  # Get container ID from selection
  local selected_container=$(echo "$containers" | sed -n "${container_num}p" | cut -d'|' -f1)
  
  if [[ -n "$selected_container" ]]; then
    echo "Options for viewing logs:"
    echo "1. View all logs"
    echo "2. View last 50 lines"
    echo "3. View logs since a specific time (e.g., '10m' for last 10 minutes)"
    echo "4. Follow logs (live updates)"
    echo -n "Select an option: "
    read -r log_option
    
    case "$log_option" in
      1)
        docker logs "$selected_container"
        ;;
      2)
        docker logs --tail 50 "$selected_container"
        ;;
      3)
        echo -n "Enter time specification (e.g., 10m, 2h, 1d): "
        read -r time_spec
        docker logs --since "$time_spec" "$selected_container"
        ;;
      4)
        echo "Showing live logs. Press Ctrl+C to exit."
        sleep 1
        docker logs -f "$selected_container"
        ;;
      *)
        log --warn "Invalid option. Showing default logs."
        docker logs "$selected_container"
        ;;
    esac
  else
    log --warn "Invalid selection."
  fi
  
  echo
  read -n 1 -s -r -p "Press any key to continue..."
  manage_containers
}

# Manage Docker images
manage_images() {
  echo -e "\n${BLUE}--- Docker Image Management ---${NC}"
  
  echo "1. List images"
  echo "2. Remove selected image"
  echo "3. Remove dangling images"
  echo "4. Remove unused images"
  echo "5. Pull latest version of an image"
  echo "6. Search Docker Hub for images"
  echo "7. Return to Docker menu"
  echo -n "Select an option: "
  read -r image_choice
  
  case "$image_choice" in
    1) list_images ;;
    2) remove_image ;;
    3) remove_dangling_images ;;
    4) remove_unused_images ;;
    5) pull_latest_image ;;
    6) search_docker_hub ;;
    7) docker_management ;;
    *) log --warn "Invalid choice."; manage_images ;;
  esac
}

# List images
list_images() {
  echo -e "\n${BLUE}--- Docker Image List ---${NC}"
  
  echo "1. Show all images"
  echo "2. Show dangling images"
  echo "3. Show images with size details"
  echo "4. Show image history for a specific image"
  echo -n "Select an option: "
  read -r list_option
  
  case "$list_option" in
    1) 
      echo -e "\n${CYAN}All Images:${NC}"
      docker images
      ;;
    2)
      echo -e "\n${CYAN}Dangling Images:${NC}"
      docker images --filter "dangling=true"
      ;;
    3)
      echo -e "\n${CYAN}Images with Size Details:${NC}"
      docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.Size}}\t{{.CreatedSince}}"
      ;;
    4)
      # Select image for history
      echo -e "\n${CYAN}All Images:${NC}"
      docker images
      
      echo -n "Enter the image ID or repository:tag to view history: "
      read -r image_id
      
      if [[ -n "$image_id" ]]; then
        echo -e "\n${CYAN}Image History:${NC}"
        docker history "$image_id"
      else
        log --warn "No image specified."
      fi
      ;;
    *) log --warn "Invalid choice." ;;
  esac
  
  echo
  read -n 1 -s -r -p "Press any key to continue..."
  manage_images
}

# Remove selected image
remove_image() {
  echo -e "\n${BLUE}--- Remove Docker Image ---${NC}"
  
  # Get list of all images
  local images=$(docker images --format "{{.Repository}}|{{.Tag}}|{{.ID}}|{{.Size}}")
  
  if [[ -z "$images" ]]; then
    log "No images found."
    echo
    read -n 1 -s -r -p "Press any key to continue..."
    manage_images
    return
  fi
  
  # Display images with numbers
  echo -e "${CYAN}All Images:${NC}"
  echo -e "NUM\tREPOSITORY\tTAG\t\tIMAGE ID\tSIZE"
  
  local i=1
  echo "$images" | while IFS="|" read -r repo tag id size; do
    printf "%d\t%s\t%s\t\t%s\t%s\n" $i "$repo" "$tag" "$id" "$size"
    ((i++))
  done
  
  echo -n "Enter the number of the image to remove (or 0 to cancel): "
  read -r image_num
  
  if [[ $image_num -eq 0 || -z "$image_num" ]]; then
    manage_images
    return
  fi
  
  # Get image ID from selection
  local selected_image=$(echo "$images" | sed -n "${image_num}p" | cut -d'|' -f3)
  
  if [[ -n "$selected_image" ]]; then
    if confirm "Are you sure you want to remove this image? This action cannot be undone."; then
      log "Removing image: $selected_image"
      run_command docker rmi "$selected_image"
      
      if [[ $? -ne 0 ]]; then
        log --warn "Failed to remove image. It may be in use by a container."
        if confirm "Force remove image? (This could break dependent containers)"; then
          run_command docker rmi -f "$selected_image"
        fi
      fi
    fi
  else
    log --warn "Invalid selection."
  fi
  
  echo
  read -n 1 -s -r -p "Press any key to continue..."
  manage_images
}

# Remove dangling images
remove_dangling_images() {
  echo -e "\n${BLUE}--- Remove Dangling Images ---${NC}"
  
  # Count dangling images
  local count=$(docker images -f "dangling=true" -q | wc -l | tr -d ' ')
  
  if [[ $count -eq 0 ]]; then
    log "No dangling images found."
    echo
    read -n 1 -s -r -p "Press any key to continue..."
    manage_images
    return
  fi
  
  if confirm "Are you sure you want to remove all $count dangling images?"; then
    log "Removing all dangling images..."
    run_command docker image prune -f
  fi
  
  echo
  read -n 1 -s -r -p "Press any key to continue..."
  manage_images
}

# Remove unused images
remove_unused_images() {
  echo -e "\n${BLUE}--- Remove Unused Images ---${NC}"
  
  log "This will remove all images that are not being used by any container."
  
  if confirm "Are you sure you want to remove all unused images? This may include many images."; then
    if confirm "Remove all untagged images as well? (More disk space savings)"; then
      log "Removing all unused images..."
      run_command docker image prune -a -f
    else
      log "Removing dangling images only..."
      run_command docker image prune -f
    fi
  fi
  
  echo
  read -n 1 -s -r -p "Press any key to continue..."
  manage_images
}

# Pull latest version of an image
pull_latest_image() {
  echo -e "\n${BLUE}--- Pull Latest Image ---${NC}"
  
  echo -n "Enter the image name to pull (e.g., ubuntu, mysql:8.0): "
  read -r image_name
  
  if [[ -z "$image_name" ]]; then
    log --warn "No image specified."
  else
    log "Pulling image: $image_name"
    run_command docker pull "$image_name"
  fi
  
  echo
  read -n 1 -s -r -p "Press any key to continue..."
  manage_images
}

# Search Docker Hub for images
search_docker_hub() {
  echo -e "\n${BLUE}--- Search Docker Hub ---${NC}"
  
  echo -n "Enter search term: "
  read -r search_term
  
  if [[ -z "$search_term" ]]; then
    log --warn "No search term specified."
  else
    log "Searching Docker Hub for: $search_term"
    docker search "$search_term" --limit 25
  fi
  
  echo
  read -n 1 -s -r -p "Press any key to continue..."
  manage_images
}

# Manage Docker volumes
manage_volumes() {
  echo -e "\n${BLUE}--- Docker Volume Management ---${NC}"
  
  echo "1. List volumes"
  echo "2. Remove selected volume"
  echo "3. Remove all unused volumes"
  echo "4. Inspect volume details"
  echo "5. Return to Docker menu"
  echo -n "Select an option: "
  read -r volume_choice
  
  case "$volume_choice" in
    1) list_volumes ;;
    2) remove_volume ;;
    3) remove_unused_volumes ;;
    4) inspect_volume ;;
    5) docker_management ;;
    *) log --warn "Invalid choice."; manage_volumes ;;
  esac
}

# List volumes
list_volumes() {
  echo -e "\n${BLUE}--- Docker Volume List ---${NC}"
  
  local volumes=$(docker volume ls)
  echo "$volumes"
  
  echo
  read -n 1 -s -r -p "Press any key to continue..."
  manage_volumes
}

# Remove selected volume
remove_volume() {
  echo -e "\n${BLUE}--- Remove Docker Volume ---${NC}"
  
  # Get list of all volumes
  local volumes=$(docker volume ls --format "{{.Name}}|{{.Driver}}|{{.Mountpoint}}")
  
  if [[ -z "$volumes" ]]; then
    log "No volumes found."
    echo
    read -n 1 -s -r -p "Press any key to continue..."
    manage_volumes
    return
  fi
  
  # Display volumes with numbers
  echo -e "${CYAN}All Volumes:${NC}"
  echo -e "NUM\tNAME\t\tDRIVER\t\tMOUNTPOINT"
  
  local i=1
  echo "$volumes" | while IFS="|" read -r name driver mount; do
    printf "%d\t%s\t\t%s\t\t%s\n" $i "$name" "$driver" "$mount"
    ((i++))
  done
  
  echo -n "Enter the number of the volume to remove (or 0 to cancel): "
  read -r volume_num
  
  if [[ $volume_num -eq 0 || -z "$volume_num" ]]; then
    manage_volumes
    return
  fi
  
  # Get volume name from selection
  local selected_volume=$(echo "$volumes" | sed -n "${volume_num}p" | cut -d'|' -f1)
  
  if [[ -n "$selected_volume" ]]; then
    # Check if the volume is in use
    local in_use=0
    if docker ps -a --filter "volume=$selected_volume" -q | grep -q .; then
      in_use=1
      log --warn "WARNING: This volume appears to be in use by one or more containers."
      docker ps -a --filter "volume=$selected_volume" --format "table {{.ID}}\t{{.Names}}\t{{.Status}}"
    fi
    
    if [[ $in_use -eq 1 ]]; then
      log --warn "Removing a volume in use can cause data loss for running containers."
      if ! confirm "Are you REALLY sure you want to remove this volume? This action cannot be undone."; then
        manage_volumes
        return
      fi
    else
      if ! confirm "Are you sure you want to remove this volume? This action cannot be undone."; then
        manage_volumes
        return
      fi
    fi
    
    log "Removing volume: $selected_volume"
    run_command docker volume rm "$selected_volume"
    
    if [[ $? -ne 0 ]]; then
      log --warn "Failed to remove volume. It may be in use by a container."
      if confirm "Force remove volume? (This could break dependent containers)"; then
        run_command docker volume rm -f "$selected_volume"
      fi
    fi
  else
    log --warn "Invalid selection."
  fi
  
  echo
  read -n 1 -s -r -p "Press any key to continue..."
  manage_volumes
}

# Remove all unused volumes
remove_unused_volumes() {
  echo -e "\n${BLUE}--- Remove Unused Volumes ---${NC}"
  
  log "This will remove all volumes not being used by any container."
  
  if confirm "Are you sure you want to remove all unused volumes? This could delete important data."; then
    log "Removing all unused volumes..."
    run_command docker volume prune -f
  fi
  
  echo
  read -n 1 -s -r -p "Press any key to continue..."
  manage_volumes
}

# Inspect volume details
inspect_volume() {
  echo -e "\n${BLUE}--- Inspect Docker Volume ---${NC}"
  
  # Get list of all volumes
  local volumes=$(docker volume ls --format "{{.Name}}")
  
  if [[ -z "$volumes" ]]; then
    log "No volumes found."
    echo
    read -n 1 -s -r -p "Press any key to continue..."
    manage_volumes
    return
  fi
  
  # Display volumes with numbers
  echo -e "${CYAN}All Volumes:${NC}"
  local i=1
  echo "$volumes" | while read -r name; do
    printf "%d\t%s\n" $i "$name"
    ((i++))
  done
  
  echo -n "Enter the number of the volume to inspect (or 0 to cancel): "
  read -r volume_num
  
  if [[ $volume_num -eq 0 || -z "$volume_num" ]]; then
    manage_volumes
    return
  fi
  
  # Get volume name from selection
  local selected_volume=$(echo "$volumes" | sed -n "${volume_num}p")
  
  if [[ -n "$selected_volume" ]]; then
    log "Inspecting volume: $selected_volume"
    docker volume inspect "$selected_volume"
    
    # Show containers using this volume
    echo
    echo -e "${CYAN}Containers using this volume:${NC}"
    local containers=$(docker ps -a --filter "volume=$selected_volume" --format "table {{.ID}}\t{{.Names}}\t{{.Status}}")
    
    if [[ -n "$containers" ]]; then
      echo "$containers"
    else
      echo "No containers are using this volume."
    fi
  else
    log --warn "Invalid selection."
  fi
  
  echo
  read -n 1 -s -r -p "Press any key to continue..."
  manage_volumes
}

# Clean unused Docker resources
clean_docker_resources() {
  echo -e "\n${BLUE}--- Clean Docker Resources ---${NC}"
  
  echo "1. Clean everything (system prune)"
  echo "2. Clean build cache only"
  echo "3. Clean containers only"
  echo "4. Clean images only"
  echo "5. Clean volumes only"
  echo "6. Return to Docker menu"
  echo -n "Select an option: "
  read -r clean_choice
  
  case "$clean_choice" in
    1)
      echo -e "\n${CYAN}System Prune Options:${NC}"
      echo "This will remove:"
      echo "- All stopped containers"
      echo "- All networks not used by at least one container"
      echo "- All dangling images"
      echo "- All dangling build cache"
      
      if confirm "Do you want to include unused images as well? (More aggressive cleaning)"; then
        if confirm "Are you sure you want to perform a complete system prune? This cannot be undone."; then
          log "Performing complete system prune including unused images..."
          run_command docker system prune -a -f
        fi
      else
        if confirm "Are you sure you want to perform a system prune? This cannot be undone."; then
          log "Performing system prune..."
          run_command docker system prune -f
        fi
      fi
      ;;
    2)
      log "Cleaning build cache..."
      
      # Show cache size first
      docker builder prune -f --keep-storage 0 --dry-run
      
      if confirm "Are you sure you want to clean all build cache?"; then
        run_command docker builder prune -f
      fi
      ;;
    3)
      log "Cleaning containers..."
      if confirm "Are you sure you want to remove all stopped containers?"; then
        run_command docker container prune -f
      fi
      ;;
    4)
      log "Cleaning images..."
      if confirm "Remove just dangling images?"; then
        run_command docker image prune -f
      else
        if confirm "Are you sure you want to remove ALL unused images? This is more aggressive."; then
          run_command docker image prune -a -f
        fi
      fi
      ;;
    5)
      log "Cleaning volumes..."
      if confirm "Are you sure you want to remove all unused volumes? This could delete important data."; then
        run_command docker volume prune -f
      fi
      ;;
    6) docker_management ;;
    *) log --warn "Invalid choice." ;;
  esac
  
  echo
  read -n 1 -s -r -p "Press any key to continue..."
  docker_management
}

# Manage Docker configuration
manage_docker_config() {
  echo -e "\n${BLUE}--- Docker Configuration Management ---${NC}"
  
  echo "1. Show Docker disk image location and size"
  echo "2. Change Docker resource limits"
  echo "3. Reset Docker to default settings"
  echo "4. Return to Docker menu"
  echo -n "Select an option: "
  read -r config_choice
  
  case "$config_choice" in
    1) show_docker_disk_location ;;
    2) change_docker_resources ;;
    3) reset_docker_settings ;;
    4) docker_management ;;
    *) log --warn "Invalid choice."; manage_docker_config ;;
  esac
}

# Show Docker disk image location and size
show_docker_disk_location() {
  echo -e "\n${BLUE}--- Docker Disk Image Location ---${NC}"
  
  log "Checking Docker data location..."
  
  # Check common Docker data locations
  local docker_data_locations=(
    "$HOME/Library/Containers/com.docker.docker/Data/vms/0/data/Docker.raw"  # Docker Desktop
    "/Users/Shared/Docker/volumes"                                          # Older Docker Desktop
    "/var/lib/docker"                                                       # Linux-like location
  )
  
  local found=0
  for location in "${docker_data_locations[@]}"; do
    if [[ -e "$location" ]]; then
      found=1
      local size=$(du -sh "$location" 2>/dev/null | cut -f1)
      echo "Docker data found at: $location"
      echo "Size: $size"
    fi
  done
  
  if [[ $found -eq 0 ]]; then
    log "Could not find Docker data location automatically."
    log "Docker Desktop for Mac typically stores its data in a VM disk image."
    log "You can configure Docker's resource usage through Docker Desktop preferences."
  fi
  
  echo
  echo "Docker for Mac stores its data in a disk image that can grow as needed."
  echo "To change resource limits, use Docker Desktop's preferences panel:"
  echo "1. Click on the Docker icon in the menu bar"
  echo "2. Select 'Preferences' or 'Settings'"
  echo "3. Go to 'Resources' to adjust CPU, RAM, and disk limits"
  
  echo
  read -n 1 -s -r -p "Press any key to continue..."
  manage_docker_config
}

# Change Docker resource limits
change_docker_resources() {
  echo -e "\n${BLUE}--- Change Docker Resources ---${NC}"
  
  log "Docker resource limits on macOS are managed through Docker Desktop."
  log "This script cannot directly modify these settings, but can show you how to do it."
  
  echo
  echo "To change Docker resource limits:"
  echo "1. Click on the Docker Desktop icon in the menu bar"
  echo "2. Select 'Preferences' or 'Settings'"
  echo "3. Go to the 'Resources' tab"
  echo "4. Adjust the sliders for:"
  echo "   - CPU: Number of cores Docker can use"
  echo "   - Memory: RAM allocated to Docker"
  echo "   - Swap: Additional virtual memory for Docker"
  echo "   - Disk image size: Maximum size for Docker data"
  echo "5. Click 'Apply & Restart' to save changes"
  
  echo
  echo "Would you like to open Docker Desktop preferences now?"
  if confirm "Open Docker Desktop preferences?"; then
    open -a Docker
    log "Opening Docker Desktop. Please navigate to Settings/Preferences."
  fi
  
  echo
  read -n 1 -s -r -p "Press any key to continue..."
  manage_docker_config
}

# Reset Docker to default settings
reset_docker_settings() {
  echo -e "\n${BLUE}--- Reset Docker Settings ---${NC}"
  
  log --warn "This will reset Docker Desktop to its default settings."
  log --warn "Warning: This will remove all containers, images, volumes, and other Docker data!"
  
  if confirm "Are you ABSOLUTELY SURE you want to reset Docker to default settings? ALL DATA WILL BE LOST!"; then
    if confirm "Last chance: This is irreversible. Continue with reset?"; then
      log "Attempting to reset Docker Desktop..."
      
      # First try to reset via Docker Desktop
      if [[ -d "/Applications/Docker.app" ]]; then
        log "Stopping Docker Desktop..."
        run_command osascript -e 'quit app "Docker"'
        
        log "Removing Docker data..."
        
        # Reset Docker for Mac data
        run_command rm -rf ~/Library/Group\ Containers/group.com.docker/
        run_command rm -rf ~/Library/Containers/com.docker.docker/
        run_command rm -rf ~/Library/Application\ Support/Docker\ Desktop/
        run_command rm -rf ~/.docker/
        
        log "Docker has been reset to default settings."
        log "You will need to relaunch Docker Desktop and complete the initial setup again."
        
        if confirm "Would you like to launch Docker Desktop now?"; then
          run_command open -a Docker
        fi
      else
        log --error "Docker Desktop not found in /Applications."
        log "Please reset Docker manually by removing Docker data directories and reinstalling."
      fi
    fi
  fi
  
  echo
  read -n 1 -s -r -p "Press any key to continue..."
  manage_docker_config
}