# CR - Mac Helper

## Overview

CR - Mac Helper is a personal project designed to streamline Mac maintenance and management.  It's born out of the need to automate cleaning, auditing, and optimizing my macOS environment after years of installing, uninstalling, and experimenting with countless applications and tools. This script helps keep track of system health, remove unnecessary files, and generally keep my Mac running smoothly. Sharing is caring, so here it is!

**Disclaimer:** This is a personal tool, use it at your own risk.  While efforts have been made to ensure safety, I (Caio Ricciuti) am not responsible for any data loss or system instability resulting from the use of this script.
** Always back up your system before making changes. ** 

## Why This Script?

As a data engineer and developer, I've installed a world collection of apps, software, tools, and frameworks on my Mac. Over time, this led to a cluttered (most of the time for my mistakes and lack of organization/knowledge about a tool or application), system that was difficult to maintain. Existing tools often lacked the customization and specific functionalities I needed. Plus, I wanted to avoid installing even *more* software if possible! This script is my solution for a tailored, hands-on approach to my Mac maintenance.

## Key Features

*   **App Cleanup and Management:** Thoroughly remove applications and their associated files, including preferences, caches, and support documents.

*   **Path Management:**  Inspect and repair broken or redundant entries in your system's PATH environment variable, ensuring commands are found correctly.

*   **Cache and Temp File Management:** Clear out accumulated system and application caches, as well as temporary files, to free up disk space and improve performance.

*   **Login Items Management:**  Review and control which applications launch automatically at startup, reducing boot times and improving system responsiveness. (Needs more work, I'm not getting it quite right yet...)

*   **System Maintenance:** Execute essential system maintenance tasks such as verifying disk permissions, running periodic maintenance scripts, and rebuilding Launch Services database.

*   **System Optimization:** Fine-tune system settings to enhance performance, including animation speed adjustments and memory management tweaks.

*   **Network Optimization:** Reset network configurations, optimize DNS settings for faster browsing, and scan for devices on your local network.

*   **Battery Optimization (for MacBooks):**  Implement power-saving measures to extend battery life on MacBook devices.

*   **Security Cleanup:** Audit and enhance system security settings to mitigate potential vulnerabilities and remove potentially harmful files.

*   **Hidden Folders Cleanup:** Identify and remove leftover files and directories from previously uninstalled applications located in hidden folders within your home directory.

*   **System Audit and Reports:** Generate comprehensive HTML reports, including interactive charts, to visualize system status, disk usage, and potential issues.

## Project Structure

The project is structured into modular shell scripts for improved organization and maintainability:

```
.
├── clean_mac.sh        # Main script: entry point that orchestrates module loading and execution
├── modules/
│   ├── helpers.sh      # Collection of common utility functions used across modules
│   ├── app_cleanup.sh  # Functions for application management and removal
│   ├── path_management.sh # Functions for managing the system's PATH environment variable
│   ├── cache_cleanup.sh # Functions for cleaning system and application caches and temporary files
│   ├── login_items.sh  # Functions for managing startup applications and login items
│   ├── system_maintenance.sh # Functions for performing system maintenance tasks
│   ├── system_optimization.sh # Functions for optimizing system performance
│   ├── network_optimization.sh # Functions for network configuration and optimization
│   ├── battery_optimization.sh # Functions for battery optimization (MacBooks)
│   ├── security_cleanup.sh # Functions for security auditing and cleanup
│   ├── hidden_cleanup.sh # Functions for cleaning remnants in hidden folders
│   └── system_audit.sh # Functions for system auditing and report generation
```

## Usage

1.  **Clone or Download:** Obtain the repository using Git or download the ZIP archive.

    ```bash
    git clone https://github.com/cricciuti/cr-mac-helper.git
    cd cr-mac-helper
    ```

2.  **Make Executable:** Grant execute permissions to the main script.

    ```bash
    chmod +x clean_mac.sh
    ```

3.  **Run the Script:** Execute the script from your terminal.

    ```bash
    ./clean_mac.sh
    ```

4.  **Follow the Prompts:**  The script will guide you through the available modules and features via interactive prompts.

## Important Notes and Warnings

*   **Backups are Crucial:**  *Always* create a full backup of your system before running this script. Data loss is *always* a possibility, no matter how carefully the script is designed.  **You are responsible for your data.**

*   **Privileges:** Some operations require `root` or `sudo` privileges. The script will prompt you when elevated access is needed. Be cautious when granting these privileges.

*   **Dry Run Mode:** Utilize "Dry Run" mode (if available for a specific function) to preview the changes that *would* be made without actually modifying the system. This helps prevent unintended consequences.

*   **Understand the Code:**  Review the code in the modules you plan to use.  Understanding what the script is doing is the best way to prevent problems.

## Development

### Contributing

Contributions are **VERY** welcome! Feel free to submit pull requests with new features, bug fixes, or improvements.

### Adding New Features

1.  **Create a Module:** Create a new `.sh` file in the `modules/` directory for your feature.

2.  **Implement Functions:** Add your shell functions to the new module.

3.  **Integrate:**  Source the new module in the main `clean_mac.sh` script to make its functions available.

### Coding Standards

*   **Descriptive Names:** Use meaningful and descriptive names for functions and variables.

*   **Comments:**  Comment your code, especially for complex or critical operations.  Explain the *why* not just the *what*.

*   **Safety Checks:** Implement robust safety checks and confirmations before performing any destructive operations.

*   **Dry Run:**  Provide a "Dry Run" or "Preview" mode for functions that modify the system, allowing users to see the intended changes before they are applied.

*   **Error Handling:** Include error handling to gracefully manage unexpected situations.

## License

This project is licensed under the MIT License - see the [LICENCE](LICENCE) file for details.