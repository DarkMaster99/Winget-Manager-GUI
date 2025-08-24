# Winget Manager GUI

**An intuitive and powerful PowerShell-based Graphical User Interface (GUI) to manage your Windows applications using the Winget package manager.**

This script provides a user-friendly desktop window that abstracts away the complexity of the Winget command line, making software installation, updates, and management a simple and visual process.



---

## General Description

**Winget Manager GUI** was created as a solution for those who prefer a visual approach to application management. Instead of typing commands into a terminal, you can view all your installed programs in a clean, organized grid, check for updates with a single click, and search for new software to install—all from one interface. The script is designed to be responsive, running longer tasks (like checking for updates) in the background to keep the user interface from freezing.

---

## Key Features

The script offers a comprehensive set of features for managing the entire application lifecycle:

### Viewing and Management
* **Complete Program List**: On launch, the application loads and displays all programs installed and recognized by Winget.
* **Automatic Update Check**: Immediately after loading the list, it starts a background process to check which programs have a newer version available. The status is visually updated in the grid (e.g., "⬆️ Update Available").
* **Quick Filter and Search**: A search box allows you to filter the program list by name in real-time, making it easy to find a specific application.
* **Clean, Dark Interface**: The UI uses a modern and visually appealing dark theme, with accent colors that highlight important actions.

### Application Operations
* **Single and Bulk Updates**:
    * Select one or more programs using the checkboxes and click **"Install/Update Selected"** to update them.
    * Click **"Update All"** to begin updating every application for which a new version is available.
* **Install New Software**:
    * The **"Install New..."** button opens a dedicated window where you can search for programs in the Winget repositories.
    * Search results show the name, ID, version, and whether the program is already installed.
    * You can select one or more programs from the search results and install them all at once.
* **Specific Version Management**:
    * On both the main screen and the installation window, you can right-click a program to find and select a **specific version** to install. This is useful for downgrading if a new version causes issues.
* **Uninstall and Repair**:
    * The context menu (right-click) on an installed application allows you to:
        * **Uninstall** the program silently.
        * **Repair** the installation (the script will perform an uninstall followed by a reinstall of the exact same version).

### Advanced Functionality
* **Import/Export Application List**:
    * From the `File > Export List...` menu, you can save a JSON file containing a list of all your installed programs.
    * From the `File > Import and Install...` menu, you can select a previously exported JSON file to automatically reinstall all the listed programs, which is ideal for setting up a new PC.
* **Queued Task Management**: All actions (install, update, etc.) are added to a task queue. The script processes them one by one, displaying the current status in the bottom status bar. This prevents conflicts and keeps the interface responsive.
* **Detailed Logging**: From the `View > Show Log...` menu, you can open a log window that shows all executed commands, the output from Winget, and internal script messages in real-time. This is an extremely useful tool for troubleshooting.

---

## Prerequisites

To run the script correctly, you will need:

1.  **Windows 10 (version 1809 or later) or Windows 11**.
2.  **Winget Package Manager**: It must be installed and functional. It is usually included with Windows as the "App Installer".
3.  **PowerShell**: The script is compatible with Windows PowerShell 5.1 (included with Windows) and later versions.
4.  **Administrator Permissions**: The script requires to be run as an administrator to install and modify system software. It performs a check on startup and will exit if it doesn't have the necessary permissions.

---

## How to Run the Script

1.  Save the provided code into a file with a `.ps1` extension, for example, `Winget-GUI.ps1`.
2.  Right-click the file and select **"Run with PowerShell"**.
3.  If prompted, grant administrator permissions.

**Note on Execution Policy**: If the script fails to start, you may need to change the PowerShell execution policy. Open a PowerShell window as an administrator and type the following command:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process
