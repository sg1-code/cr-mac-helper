# CR - Mac Helper

**Version 1.1**

## Overview

CR - Mac Helper is a personal project designed to streamline Mac maintenance and management. It's born out of the need to automate cleaning, auditing, and optimizing my macOS environment after years of installing, uninstalling, and experimenting with countless applications and tools. This script helps keep track of system health, remove unnecessary files, and generally keep my Mac running smoothly. Sharing is caring, so here it is!

**Disclaimer:** This is a personal tool, use it at your own risk. While efforts have been made to ensure safety, I (Caio Ricciuti) am not responsible for any data loss or system instability resulting from the use of this script.
**Always back up your system before making changes.**

## Why This Script?

As a data engineer and developer, I've installed a world collection of apps, software, tools, and frameworks on my Mac. Over time, this led to a cluttered system that was difficult to maintain, often due to leftover files or lack of knowledge about proper uninstallation. Existing tools often lacked the customization and specific functionalities I needed. Plus, I wanted to avoid installing even *more* software if possible! This script is my solution for a tailored, hands-on approach to my Mac maintenance.

## Key Features

### System Management

*   **App Cleanup and Management:** *Improved in v1.1!* Thoroughly remove applications and their associated files, including preferences, caches, support documents, browser data, and other leftovers across standard system locations. Uses smarter detection logic for better results.
*   **Path Management:** Inspect and repair broken or redundant entries in your system's PATH environment variable.
*   **Cache and Temp File Management:** Clear out accumulated system and application caches, as well as temporary files.
*   **Login Items Management:** Review and control applications launching automatically at startup.
*   **System Maintenance:** Execute essential maintenance tasks like verifying disk permissions and running periodic scripts.
*   **System Optimization:** Fine-tune system settings for performance enhancement.

### Network & Power

*   **Network Optimization:** Reset network configurations and optimize DNS settings.
*   **Battery Optimization (for MacBooks):** Implement power-saving measures.

### Security & Privacy (New in v1.1)

*   **Security Cleanup:** Audit and enhance system security settings.
*   **Privacy Permissions Management:** Review and control application access to sensitive data.

### Storage & Cleanup

*   **Hidden Folders Cleanup:** Identify and remove remnants from uninstalled applications in hidden home directory folders.
*   **System Audit and Reports:** *Enhanced in v1.1!* Generate comprehensive HTML reports with interactive charts for system visualization.
*   **Cloud Storage Management (New in v1.1):** Optimize local storage used by iCloud, Dropbox, Google Drive, and OneDrive.

### Developer Tools (New in v1.1)

*   **Swift & Xcode Management:** Clean Swift Package Manager caches, manage global Swift packages, and clean Xcode build data.
*   **Docker Management:** Manage Docker containers, images, volumes, and clean up resources.

## Project Structure

The project is structured into modular shell scripts:

```
.
├── clean_mac.sh        # Main script: entry point and menu
├── modules/
│   ├── helpers.sh      # Common utility functions
│   │
│   ├── # System Management
│   ├── app_cleanup.sh  # Application management and removal
│   ├── path_management.sh # PATH environment variable management
│   ├── cache_cleanup.sh # Cache and temporary file cleaning
│   ├── login_items.sh  # Startup/login item management
│   ├── system_maintenance.sh # System maintenance tasks
│   ├── system_optimization.sh # System performance optimization
│   │
│   ├── # Network & Power
│   ├── network_optimization.sh # Network configuration and optimization
│   ├── battery_optimization.sh # Battery optimization (MacBooks)
│   │
│   ├── # Security & Privacy (New in v1.1)
│   ├── security_cleanup.sh # Security auditing and cleanup
│   │
│   ├── # Storage & Cleanup
│   ├── hidden_cleanup.sh # Cleanup of remnants in hidden folders
│   ├── system_audit.sh # System auditing and report generation
│   ├── cloud_storage_management.sh # Cloud storage optimization (New in v1.1)
│   │
│   ├── # Developer Tools (New in v1.1)
│   ├── swift_package_management.sh # Swift/Xcode cleanup and management
│   └── docker_management.sh # Docker management and optimization
```

## Usage

1.  **Clone or Download:**
    ```bash
    git clone https://github.com/caioricciuti/cr-mac-helper.git
    cd cr-mac-helper
    ```
2.  **Make Executable:**
    ```bash
    chmod +x clean_mac.sh
    ```
3.  **Run the Script:**
    ```bash
    ./clean_mac.sh
    ```
4.  **Follow the Prompts:** The script guides you through modules via interactive prompts.

## Important Notes and Warnings

*   **Backups are Crucial:** *Always* create a full backup of your system before running this script. Data loss is *always* a possibility. **You are responsible for your data.**
*   **Privileges:** Some operations require `root` or `sudo`. The script prompts when needed. Be cautious.
*   **Dry Run Mode:** Use "Dry Run" mode (where available) to preview changes without applying them.
*   **Understand the Code:** Review the code in the modules you intend to use.

## Development

### Contributing

Contributions are **VERY** welcome! Submit pull requests with new features, bug fixes, or improvements.

### Adding New Features

1.  **Create a Module:** Add a new `.sh` file in `modules/`.
2.  **Implement Functions:** Add your shell functions.
3.  **Integrate:** Source the new module in `clean_mac.sh`.

### Coding Standards

*   **Descriptive Names:** Use meaningful function and variable names.
*   **Comments:** Explain the *why*, not just the *what*.
*   **Safety Checks:** Implement robust safety checks and confirmations before destructive operations.
*   **Dry Run:** Provide a "Dry Run" or "Preview" mode where applicable.
*   **Error Handling:** Include error handling for unexpected situations.

## License

This project is licensed under the MIT License - see the [LICENCE](LICENCE) file for details.