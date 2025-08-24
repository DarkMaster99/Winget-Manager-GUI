# ===================================================================

# Winget Manager GUI

#

# Description:
# A graphical interface (GUI) for the Winget command-line utility
# to simply and intuitively view, update, and install applications.

# ===================================================================


# --- REGION: Initial Settings & Permission Check ---

[System.Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$OutputEncoding = [System.Text.Encoding]::UTF8

chcp 65001 > $null

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {

    Add-Type -AssemblyName System.Windows.Forms

    [System.Windows.Forms.MessageBox]::Show("This script requires Administrator permissions to run correctly.", "Permission Error", "OK", "Error")

    exit

}

Add-Type -AssemblyName System.Windows.Forms; Add-Type -AssemblyName System.Drawing

# --- ENDREGION ---


# --- REGION: Global Settings & Theme ---

$Theme = @{

    FormBackground     = [System.Drawing.Color]::FromArgb(45, 45, 48); Text = [System.Drawing.Color]::White

    GridBackground     = [System.Drawing.Color]::FromArgb(30, 30, 30); GridCellBackground = [System.Drawing.Color]::FromArgb(51, 51, 55)

    GridHeader         = [System.Drawing.Color]::FromArgb(63, 63, 70); ButtonBackground = [System.Drawing.Color]::FromArgb(63, 63, 70)

    AccentBlue         = [System.Drawing.Color]::FromArgb(0, 122, 204); HighlightYellow = [System.Drawing.Color]::FromArgb(80, 80, 40)

}

$script:TaskQueue = [System.Collections.Generic.List[object]]::new(); $script:AllAppsCache = @(); $script:ActiveJob = $null

# --- ENDREGION ---


# --- REGION: Helper Function Definitions ---

function Append-Log($text) {

    # Adds a timestamp to each log message

    $timestamp = Get-Date -Format "HH:mm:ss"

    if ($logForm.IsHandleCreated) {

        $logForm.Invoke([Action[string]]{ $logTextBox.AppendText("[$timestamp] $text`r`n") }, $text)

    }

}

function Invoke-WingetJob { param([string]$Arguments) $scriptBlock = [scriptblock]::Create("chcp 65001 > `$null; winget $Arguments"); return Start-Job -ScriptBlock $scriptBlock }

function Set-ControlsEnabled($enabled) {

    Append-Log "[Set-ControlsEnabled] Setting controls to: $enabled"

    $allButtons | ForEach-Object { $_.Enabled = $enabled }

    $menuStrip.Enabled = $enabled

    $dataGridView.Enabled = $enabled

    $searchBox.Enabled = $enabled

}

function Start-ProcessingQueue {

    if ($script:TaskQueue.Count -eq 0) {

        Append-Log "[Start-ProcessingQueue] Queue is empty. No action taken."

        return

    }

    Append-Log "[Start-ProcessingQueue] Starting processing of $($script:TaskQueue.Count) tasks."

    Set-ControlsEnabled $false

    Get-Job -Name "OperationJob" -ErrorAction SilentlyContinue | Remove-Job -Force

    $operationTimer.Start()

}

# --- ENDREGION ---


# --- REGION: GUI Creation ---

$form = New-Object System.Windows.Forms.Form; $form.Text = "Winget Manager GUI"; $form.Size = '950,700'; $form.StartPosition = "CenterScreen"; $form.MinimumSize = '800,500'; $form.BackColor = $Theme.FormBackground; $form.ForeColor = $Theme.Text

$menuStrip = New-Object System.Windows.Forms.MenuStrip; $menuStrip.BackColor = $Theme.FormBackground; $menuStrip.ForeColor = $Theme.Text; $fileMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem("&File"); $exportMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem("&Export List..."); $importMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem("&Import and Install..."); $fileMenuItem.DropDownItems.AddRange(@($exportMenuItem, $importMenuItem)); $viewMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem("&View"); $showLogMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem("Show &Log..."); $viewMenuItem.DropDownItems.Add($showLogMenuItem); $menuStrip.Items.AddRange(@($fileMenuItem, $viewMenuItem))

$searchLabel = New-Object System.Windows.Forms.Label; $searchLabel.Text = "Filter by name:"; $searchLabel.Location = '10,35'; $searchLabel.AutoSize = $true

$searchBox = New-Object System.Windows.Forms.TextBox; $searchBox.Location = '110,32'; $searchBox.Size = '300,20'; $searchBox.BackColor = $Theme.GridCellBackground; $searchBox.ForeColor = $Theme.Text

$dataGridView = New-Object System.Windows.Forms.DataGridView; $dataGridView.Location = '10,60'; $dataGridView.Size = '910,530'; $dataGridView.Anchor = 'Top,Bottom,Left,Right'; $dataGridView.AllowUserToAddRows = $false; $dataGridView.MultiSelect = $false; $dataGridView.SelectionMode = "FullRowSelect"; $dataGridView.AutoSizeColumnsMode = "Fill"; $dataGridView.BackgroundColor = $Theme.GridBackground; $dataGridView.ForeColor = $Theme.Text; $dataGridView.BorderStyle = "None"; $dataGridView.GridColor = $Theme.GridHeader; $dataGridView.EnableHeadersVisualStyles = $false; $dataGridView.ColumnHeadersDefaultCellStyle.BackColor = $Theme.GridHeader; $dataGridView.ColumnHeadersDefaultCellStyle.ForeColor = $Theme.Text; $dataGridView.DefaultCellStyle.BackColor = $Theme.GridCellBackground; $dataGridView.DefaultCellStyle.ForeColor = $Theme.Text; $dataGridView.DefaultCellStyle.SelectionBackColor = $Theme.AccentBlue; $dataGridView.DefaultCellStyle.SelectionForeColor = $Theme.Text; $dataGridView.ReadOnly = $true

$checkboxColumn = New-Object System.Windows.Forms.DataGridViewCheckBoxColumn; $checkboxColumn.Name = "Select"; $checkboxColumn.HeaderText = "✓"; $checkboxColumn.Width = 30; $checkboxColumn.ReadOnly = $false; $dataGridView.Columns.Add($checkboxColumn)

$dataGridView.Columns.Add("Name", "Program Name"); $dataGridView.Columns.Add("InstalledVersion", "Installed Version"); $dataGridView.Columns.Add("AvailableVersion", "Latest Version"); $dataGridView.Columns.Add("Status", "Status")

$idColumn = New-Object System.Windows.Forms.DataGridViewTextBoxColumn; $idColumn.Name = "Id"; $idColumn.Visible = $false; $dataGridView.Columns.Add($idColumn)

$contextMenuStrip = New-Object System.Windows.Forms.ContextMenuStrip; $specificVersionMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem("Install specific version..."); $uninstallMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem("Uninstall..."); $repairMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem("Repair..."); $contextMenuStrip.Items.AddRange(@($specificVersionMenuItem, $uninstallMenuItem, $repairMenuItem)); $dataGridView.ContextMenuStrip = $contextMenuStrip

$allButtons = @();

$buttonNames = @("Install/Update Selected", "Update All", "Install New...", "↻ Reload Data")

foreach ($name in $buttonNames) { $btn = New-Object System.Windows.Forms.Button; $btn.Name = $name -replace '[^a-zA-Z0-9]'; $btn.Text = $name; $btn.FlatStyle = 'Flat'; $btn.BackColor = $Theme.ButtonBackground; $btn.FlatAppearance.BorderColor = $Theme.GridHeader; $allButtons += $btn }

$updateSelectedButton, $updateAllButton, $installNewButton, $refreshButton = $allButtons; $updateSelectedButton.Location = '10,600'; $updateSelectedButton.Size = '180,30'; $updateSelectedButton.Anchor = 'Bottom,Left'; $updateAllButton.Location = '200,600'; $updateAllButton.Size = '120,30'; $updateAllButton.Anchor = 'Bottom,Left'; $installNewButton.Location = '330,600'; $installNewButton.Size = '120,30'; $installNewButton.Anchor = 'Bottom,Left'; $refreshButton.Location = '790,600'; $refreshButton.Size = '130,30'; $refreshButton.Anchor = 'Bottom,Right'

$statusStrip = New-Object System.Windows.Forms.StatusStrip; $statusStrip.BackColor = $Theme.GridHeader; $statusBarLabel = New-Object System.Windows.Forms.ToolStripStatusLabel "Ready."; $statusBarLabel.ForeColor = $Theme.Text; $statusStrip.Items.Add($statusBarLabel) | Out-Null

$logForm = New-Object System.Windows.Forms.Form; $logForm.Text = "Operation Log"; $logForm.Size = '800,400'; $logForm.StartPosition = 'CenterScreen'; $logForm.BackColor = $Theme.GridBackground; $logTextBox = New-Object System.Windows.Forms.TextBox; $logTextBox.Dock = "Fill"; $logTextBox.Multiline = $true; $logTextBox.ScrollBars = "Vertical"; $logTextBox.ReadOnly = $true; $logTextBox.BackColor = $Theme.GridBackground; $logTextBox.ForeColor = $Theme.Text; $logTextBox.Font = New-Object System.Drawing.Font("Consolas", 10); $logForm.Controls.Add($logTextBox)

$form.Controls.AddRange(@($menuStrip, $searchLabel, $searchBox, $dataGridView, $statusStrip) + $allButtons)

# --- ENDREGION ---


# --- REGION: Data Loading & Update Logic ---

function Load-Data {

    Append-Log "--- [Load-Data] Starting Data Reload ---"

    Set-ControlsEnabled $false

    $dataGridView.Rows.Clear()

    $statusBarLabel.Text = "Loading installed programs..."

    Get-Job -Name "UpdateSearch" -ErrorAction SilentlyContinue | Remove-Job -Force

    Append-Log "[Load-Data] Executing 'winget list' for program list..."

    $installed = winget list | Where-Object { $_ -notmatch '^(Nome|Name|--)' -and $_.Trim() } | ForEach-Object {

        $parts = $_ -split '\s{2,}' | ForEach-Object { $_.Trim() }

        if ($parts.Count -ge 3) { [PSCustomObject]@{ Name = $parts[0]; Id = $parts[1]; InstalledVersion = $parts[2] } }

    }

    if (-not $installed) {

        Append-Log "[Load-Data] ERROR: 'winget list' returned no results."

        [System.Windows.Forms.MessageBox]::Show("Could not get the list of programs from Winget.", "Critical Error", "OK", "Error")

        Set-ControlsEnabled $true; $statusBarLabel.Text = "Error loading data."; return

    }

    Append-Log "[Load-Data] Found $($installed.Count) installed programs."

    $script:AllAppsCache = $installed

    foreach ($app in $script:AllAppsCache) { $dataGridView.Rows.Add($false, $app.Name, $app.InstalledVersion, "", "🔍 Checking...", $app.Id) | Out-Null }

    Append-Log "[Load-Data] Grid populated."

    $statusBarLabel.Text = "Ready. Starting background update check..."

    Set-ControlsEnabled $true

    Append-Log "[Load-Data] Starting background job..."

    $scriptBlock = {

        Write-Output "[Job] Started."

        chcp 65001 > $null

        try {

            Write-Output "[Job] Executing 'winget upgrade'..."

            $upgradeOutputLines = winget upgrade --accept-source-agreements --include-unknown --disable-interactivity | Out-String -Stream

            Write-Output "[Job] 'winget upgrade' command completed. Starting parse."

            $regex = '^(.+?)\s{2,}(\S+\.\S+)\s+(\S+)\s+(\S+)'

            $upgradable = $upgradeOutputLines | ForEach-Object { if ($_ -match $regex) { [PSCustomObject]@{ Id = $matches[2]; AvailableVersion = $matches[4] } } }

            Write-Output "[Job] Parsing complete. Found $($upgradable.Count) updates."

            return $upgradable

        } catch { Write-Error "[Job] Critical error: $($_.Exception.Message)"; return $null }

    }

    $updateJob = Start-Job -Name "UpdateSearch" -ScriptBlock $scriptBlock

    $checkUpdateJobTimer = New-Object System.Windows.Forms.Timer

    $checkUpdateJobTimer.Interval = 1000

    $checkUpdateJobTimer.Add_Tick({

        param($sender, $e)

        $job = Get-Job -Name "UpdateSearch" -ErrorAction SilentlyContinue

        if ($null -eq $job -or $job.State -in @('NotStarted', 'Running')) { return }

        $sender.Stop(); $sender.Dispose()

        $jobResults = Receive-Job -Job $job

        $logMessages = $jobResults | Where-Object { $_ -is [string] }

        $allUpgradable = $jobResults | Where-Object { $_ -isnot [string] } | Select-Object -Last 1

        $form.Invoke([Action]{

            Append-Log "--- [Job] Internal Log from Background Process ---"

            $logMessages | ForEach-Object { Append-Log $_ }

            Append-Log "--- [Job] End Log ---"

            if ($job.State -eq 'Completed') {

                Append-Log "[Load-Data] Job completed successfully. Updating grid."

                $updateHash = @{}

                if ($allUpgradable) { $allUpgradable | ForEach-Object { $updateHash[$_.Id] = $_.AvailableVersion } }

                foreach ($row in $dataGridView.Rows) {

                    $appId = $row.Cells["Id"].Value

                    if ($updateHash.ContainsKey($appId)) { $row.Cells["AvailableVersion"].Value = $updateHash[$appId]; $row.Cells["Status"].Value = "⬆️ Update Available" }

                    else { $row.Cells["Status"].Value = "✅ Up to date" }

                }

                $statusBarLabel.Text = "Update check complete."

                Append-Log "[Load-Data] Grid update complete."

            } else {

                Append-Log "[Load-Data] ERROR: Job finished with state: $($job.State)"

                $statusBarLabel.Text = "Error during update check.";

                foreach ($row in $dataGridView.Rows) { if ($row.Cells["Status"].Value -eq "🔍 Checking...") { $row.Cells["Status"].Value = "⚠️ Error" } }

            }

        })

        Remove-Job -Job $job -ErrorAction SilentlyContinue

    })

    $checkUpdateJobTimer.Start()

}

# --- ENDREGION ---


# --- REGION: Event Handlers ---

function Show-SearchInstallWindow {

    Append-Log "[Show-SearchInstallWindow] Opening 'Search and Install' window."

    $searchForm = New-Object System.Windows.Forms.Form; $searchForm.Text = "Search and Install New Programs"; $searchForm.Size = '800,600'; $searchForm.StartPosition = 'CenterParent'; $searchForm.BackColor = $Theme.FormBackground; $searchForm.ForeColor = $Theme.Text; $searchTermBox = New-Object System.Windows.Forms.TextBox; $searchTermBox.Location = '10,10'; $searchTermBox.Size = '300,20'; $searchTermBox.BackColor = $Theme.GridCellBackground; $searchTermBox.ForeColor = $Theme.Text; $searchButton = New-Object System.Windows.Forms.Button; $searchButton.Text = "Search"; $searchButton.Location = '320,8'; $searchButton.Size = '80,25'; $searchButton.FlatStyle = 'Flat'; $searchButton.BackColor = $Theme.ButtonBackground; $searchButton.FlatAppearance.BorderColor = $Theme.GridHeader; $hintLabel = New-Object System.Windows.Forms.Label; $hintLabel.Text = "(Search is more effective with an exact ID)"; $hintLabel.Location = '410,12'; $hintLabel.AutoSize = $true; $hintLabel.ForeColor = [System.Drawing.Color]::Gray; $resultsGrid = New-Object System.Windows.Forms.DataGridView; $resultsGrid.Location = '10,40'; $resultsGrid.Size = '760,450'; $resultsGrid.Anchor = 'Top,Bottom,Left,Right'; $resultsGrid.AllowUserToAddRows = $false; $resultsGrid.ReadOnly = $false; $resultsGrid.AutoSizeColumnsMode = "Fill"; $resultsGrid.BackgroundColor = $Theme.GridBackground; $resultsGrid.ForeColor = $Theme.Text; $resultsGrid.BorderStyle = "None"; $resultsGrid.GridColor = $Theme.GridHeader; $resultsGrid.EnableHeadersVisualStyles = $false; $resultsGrid.ColumnHeadersDefaultCellStyle.BackColor = $Theme.GridHeader; $resultsGrid.ColumnHeadersDefaultCellStyle.ForeColor = $Theme.Text; $resultsGrid.DefaultCellStyle.BackColor = $Theme.GridCellBackground; $resultsGrid.DefaultCellStyle.ForeColor = $Theme.Text; $resultsGrid.DefaultCellStyle.SelectionBackColor = $Theme.AccentBlue; $resultsGrid.DefaultCellStyle.SelectionForeColor = $Theme.Text; $installSelectedButton = New-Object System.Windows.Forms.Button; $installSelectedButton.Text = "Install Selected"; $installSelectedButton.Location = '10,500'; $installSelectedButton.Size = '150,30'; $installSelectedButton.Anchor = 'Bottom,Left'; $installSelectedButton.FlatStyle = 'Flat'; $installSelectedButton.BackColor = $Theme.ButtonBackground; $installSelectedButton.FlatAppearance.BorderColor = $Theme.GridHeader; $searchContextMenu = New-Object System.Windows.Forms.ContextMenuStrip; $showVersionsMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem("Show available versions..."); $searchContextMenu.Items.Add($showVersionsMenuItem); $resultsGrid.ContextMenuStrip = $searchContextMenu; $selectCol = New-Object System.Windows.Forms.DataGridViewCheckBoxColumn; $selectCol.Name = "Select"; $selectCol.HeaderText = "✓"; $selectCol.Width = 30; $resultsGrid.Columns.Add($selectCol); $resultsGrid.Columns.Add("Name", "Name"); $resultsGrid.Columns.Add("Id", "ID"); $resultsGrid.Columns.Add("Version", "Version"); $resultsGrid.Columns.Add("Source", "Source"); $statusCol = New-Object System.Windows.Forms.DataGridViewTextBoxColumn; $statusCol.Name = "Status"; $statusCol.HeaderText = "Status"; $statusCol.Width = 100; $resultsGrid.Columns.Add($statusCol); $resultsGrid.Columns["Name"].ReadOnly = $true; $resultsGrid.Columns["Id"].ReadOnly = $true; $resultsGrid.Columns["Version"].ReadOnly = $true; $resultsGrid.Columns["Status"].ReadOnly = $true; $resultsGrid.Columns["Source"].ReadOnly = $true; $searchForm.Controls.AddRange(@($searchTermBox, $searchButton, $hintLabel, $resultsGrid, $installSelectedButton));

    $searchButton.Add_Click({ $searchTerm = $searchTermBox.Text; Append-Log "[Search] Search button clicked. Term: '$searchTerm'."; if (-not $searchTerm) { return }; $resultsGrid.Rows.Clear(); $searchForm.Cursor = "WaitCursor"; Append-Log "[Search] Executing 'winget search'..."; $foundIds = New-Object System.Collections.Generic.HashSet[string]; $installedIds = $script:AllAppsCache.Id; $allSearchResults = @(); foreach ($source in @("winget", "msstore")) { $allSearchResults += winget search "$searchTerm" --source $source --accept-source-agreements }; try { $allSearchResults += winget show --id "$searchTerm" --accept-source-agreements } catch {}; $filteredResults = $allSearchResults | Where-Object { $_ -notmatch '^(Nessun|No package|Nome|Name|--)' -and $_ } | Select-Object -Unique; foreach ($line in $filteredResults) { $parts = $line -split '\s{2,}' | ForEach-Object { $_.Trim() }; if ($parts.Count -ge 3) { $appId = $parts[1]; if (-not $foundIds.Contains($appId)) { [void]$foundIds.Add($appId); $source = if ($parts.Count -ge 4) { $parts[3] } else { "winget" }; $status = ""; if ($installedIds -contains $appId) { $status = "✅ Installed" }; $newRowIndex = $resultsGrid.Rows.Add($false, $parts[0], $appId, $parts[2], $source, $status); if ($status -eq "✅ Installed") { $row = $resultsGrid.Rows[$newRowIndex]; $row.ReadOnly = $true; $row.DefaultCellStyle.BackColor = [System.Drawing.Color]::Gray } } } }; $searchForm.Cursor = "Default"; Append-Log "[Search] Search complete. Found $($resultsGrid.Rows.Count) results."; if ($resultsGrid.Rows.Count -eq 0) { [System.Windows.Forms.MessageBox]::Show("No programs found for '$searchTerm'.", "No Results") } })

    $installSelectedButton.Add_Click({

        $selectedApps = $resultsGrid.Rows | Where-Object { $_.Cells["Select"].Value -eq $true }

        if ($selectedApps.Count -eq 0) { [System.Windows.Forms.MessageBox]::Show("No programs selected."); return }

        $confirmation = [System.Windows.Forms.MessageBox]::Show("Are you sure you want to install the $($selectedApps.Count) selected programs?", "Confirm Installation", "YesNo", "Question")

        if ($confirmation -eq 'Yes') {

            Append-Log "[Search] 'Install Selected' clicked. Confirmed: $($selectedApps.Count) programs."

            $searchForm.Close(); $script:TaskQueue.Clear()

            foreach ($row in $selectedApps) {

                $appId = $row.Cells["Id"].Value; $appName = $row.Cells["Name"].Value; $version = $row.Cells["Version"].Value

                if ($row.DefaultCellStyle.BackColor.Name -eq $Theme.HighlightYellow.Name) {

                    Append-Log "[Search] Queuing specific version install: $appName (v$version)"; $script:TaskQueue.Add(@{ StatusMessage = "Installing $appName (v$version)"; Arguments = "install --id `"$appId`" --version `"$version`" --silent --accept-source-agreements --disable-interactivity" })

                } else {

                    Append-Log "[Search] Queuing install: $appName"; $script:TaskQueue.Add(@{ StatusMessage = "Installing $appName (latest version)"; Arguments = "install --id `"$appId`" --silent --accept-source-agreements --disable-interactivity" })

                }

            }

            Start-ProcessingQueue

        } else { Append-Log "[Search] Installation cancelled by user." }

    })

    $showVersionsMenuItem.Add_Click({ if ($resultsGrid.CurrentRow) { $rowIndex = $resultsGrid.CurrentRow.Index; $appId = $resultsGrid.Rows[$rowIndex].Cells["Id"].Value; $appName = $resultsGrid.Rows[$rowIndex].Cells["Name"].Value; $searchForm.Cursor = 'WaitCursor'; $versionsOutput = winget show --id $appId --versions | Out-String; $availableVersions = $versionsOutput.Split([Environment]::NewLine) | Where-Object { $_ -match '^\d' } | ForEach-Object { $_.Trim() }; $searchForm.Cursor = 'Default'; if (-not $availableVersions) { [System.Windows.Forms.MessageBox]::Show("No alternative versions found."); return }; $versionForm = New-Object System.Windows.Forms.Form; $versionForm.Text = "Choose version for $appName"; $versionForm.Size = '300,400'; $versionForm.StartPosition = "CenterParent"; $versionForm.BackColor = $Theme.FormBackground; $versionForm.ForeColor = $Theme.Text; $listBox = New-Object System.Windows.Forms.ListBox; $listBox.Dock = "Fill"; $listBox.BackColor = $Theme.GridCellBackground; $listBox.ForeColor = $Theme.Text; $listBox.Items.AddRange($availableVersions); $versionForm.Controls.Add($listBox); $okButton = New-Object System.Windows.Forms.Button; $okButton.Text = "OK"; $okButton.Dock = "Bottom"; $okButton.DialogResult = "OK"; $okButton.FlatStyle = 'Flat'; $okButton.BackColor = $Theme.ButtonBackground; $okButton.FlatAppearance.BorderColor = $Theme.GridHeader; $versionForm.Controls.Add($okButton); if ($versionForm.ShowDialog($form) -eq "OK" -and $listBox.SelectedItem) { $resultsGrid.Rows[$rowIndex].Cells["Version"].Value = $listBox.SelectedItem; $resultsGrid.Rows[$rowIndex].DefaultCellStyle.BackColor = $Theme.HighlightYellow } } })

    $resultsGrid.Add_MouseClick({ param($s, $e); if ($e.Button -eq 'Right') { $hit = $s.HitTest($e.X, $e.Y); if ($hit.RowIndex -ge 0) { $s.ClearSelection(); $s.Rows[$hit.RowIndex].Selected = $true } } })

    $searchForm.ShowDialog($form) | Out-Null

}

$operationTimer = New-Object System.Windows.Forms.Timer; $operationTimer.Interval = 1000

$operationTimer.Add_Tick({ if ($null -eq $script:ActiveJob) { if ($script:TaskQueue.Count -gt 0) { $task = $script:TaskQueue[0]; $script:TaskQueue.RemoveAt(0); Append-Log "[Timer] Executing task: '$($task.StatusMessage)'"; $statusBarLabel.Text = $task.StatusMessage; $script:ActiveJob = Invoke-WingetJob -Arguments $task.Arguments; $script:ActiveJob.Name = "OperationJob" } else { Append-Log "[Timer] Operation queue finished."; $operationTimer.Stop(); $statusBarLabel.Text = "All operations complete."; [System.Windows.Forms.MessageBox]::Show("Operations finished! Press 'Reload Data' to refresh the view.", "Success"); Set-ControlsEnabled $true } } else { $newOutput = Receive-Job -Job $script:ActiveJob -Keep; if ($newOutput) { $newOutput | ForEach-Object { Append-Log "[Winget] $_" } }; if ($script:ActiveJob.State -in @('Running', 'NotStarted')) { return }; if ($script:ActiveJob.State -ne 'Completed') { Append-Log "[Timer] ERROR: Job failed with state $($script:ActiveJob.State)."; [System.Windows.Forms.MessageBox]::Show("An operation failed. Check the log.", "Error", "OK", "Error"); $script:TaskQueue.Clear() } else { Append-Log "[Timer] Task completed successfully." }; Remove-Job $script:ActiveJob; $script:ActiveJob = $null } })

$updateSelectedButton.Add_Click({

    $selectedRows = @($dataGridView.Rows | Where-Object { $_.Cells["Select"].Value -eq $true })

    if ($selectedRows.Count -eq 0) { [System.Windows.Forms.MessageBox]::Show("No programs selected.", "Attention"); return }

    $confirmation = [System.Windows.Forms.MessageBox]::Show("Are you sure you want to update the $($selectedRows.Count) selected programs?", "Confirm Update", "YesNo", "Question")

    if ($confirmation -eq 'Yes') {

        Append-Log "[UI] 'Install/Update Selected' clicked. Confirmed: $($selectedRows.Count)."

        $script:TaskQueue.Clear()

        foreach ($row in $selectedRows) {

            $appName = $row.Cells["Name"].Value; Append-Log "[UI] Queuing update for: $appName"; $appId = $row.Cells["Id"].Value; $targetVersion = $row.Cells["AvailableVersion"].Value; $status = $row.Cells["Status"].Value

            if (($status -eq "⬆️ Update Available" -or $status -eq "⚙️ Custom Version") -and $targetVersion) { $script:TaskQueue.Add(@{ StatusMessage = "Step 1/2: Uninstalling $appName"; Arguments = "uninstall --id `"$appId`" --silent --disable-interactivity" }); $script:TaskQueue.Add(@{ StatusMessage = "Step 2/2: Installing $appName (v$targetVersion)"; Arguments = "install --id `"$appId`" --version `"$targetVersion`" --silent --accept-source-agreements --disable-interactivity" }) }

        }

        Start-ProcessingQueue

    } else { Append-Log "[UI] Selected update cancelled by user." }

})

$updateAllButton.Add_Click({

    $confirmation = [System.Windows.Forms.MessageBox]::Show("Are you sure you want to update ALL available programs?`n`nThis operation might take some time.", "Confirm Update All", "YesNo", "Question")

    if ($confirmation -eq 'Yes') {

        Append-Log "[UI] 'Update All' confirmed. Queuing 'upgrade --all'."

        $script:TaskQueue.Clear(); $script:TaskQueue.Add(@{ StatusMessage = "Updating all programs..."; Arguments = "upgrade --all --silent --accept-source-agreements --include-unknown --disable-interactivity" }); Start-ProcessingQueue

    } else { Append-Log "[UI] 'Update All' cancelled by user." }

})

$installNewButton.Add_Click({ Append-Log "[UI] 'Install New...' button clicked."; Show-SearchInstallWindow })

$refreshButton.Add_Click({ Append-Log "[UI] 'Reload Data' button clicked."; if ($operationTimer.Enabled) { Append-Log "[UI] ERROR: Operations already in progress."; [System.Windows.Forms.MessageBox]::Show("Please wait for the current operations to finish.", "Operation in Progress"); return }; Load-Data })

$searchBox.Add_TextChanged({ $filter = $searchBox.Text; Append-Log "[UI] Filter text changed: '$filter'."; foreach ($row in $dataGridView.Rows) { if (-not $row.IsNewRow) { $row.Visible = $row.Cells["Name"].Value.ToString().ToLower().Contains($filter.ToLower()) } } })

$exportMenuItem.Add_Click({ Append-Log "[Menu] 'Export' clicked."; $sfd = New-Object System.Windows.Forms.SaveFileDialog; $sfd.Filter = "JSON (*.json)|*.json"; if ($sfd.ShowDialog() -eq 'OK') { Append-Log "[Menu] Exporting to: $($sfd.FileName)"; $script:TaskQueue.Clear(); $script:TaskQueue.Add(@{ StatusMessage = "Exporting list..."; Arguments = "export -o `"$($sfd.FileName)`"" }); Start-ProcessingQueue } })

$importMenuItem.Add_Click({

    Append-Log "[Menu] 'Import' clicked."; $ofd = New-Object System.Windows.Forms.OpenFileDialog; $ofd.Filter = "JSON (*.json)|*.json"

    if ($ofd.ShowDialog() -eq 'OK') {

        $confirmation = [System.Windows.Forms.MessageBox]::Show("Install all programs from the file?`n`n$($ofd.FileName)", "Confirm Import", "YesNo", "Warning")

        if ($confirmation -eq 'Yes') {

            Append-Log "[Menu] Importing from: $($ofd.FileName) confirmed."; $script:TaskQueue.Clear(); $script:TaskQueue.Add(@{ StatusMessage = "Importing and installing..."; Arguments = "import -i `"$($ofd.FileName)`" --accept-source-agreements --disable-interactivity" }); Start-ProcessingQueue

        } else { Append-Log "[Menu] Import cancelled." }

    }

})

$showLogMenuItem.Add_Click({ $logForm.Show(); $logForm.Activate() })

$logForm.Add_FormClosing({ param($s, $e); $e.Cancel = $true; $logForm.Hide() })

$specificVersionMenuItem.Add_Click({ if ($dataGridView.CurrentRow) { $row = $dataGridView.CurrentRow; $appName = $row.Cells["Name"].Value; Append-Log "[Ctx Menu] 'Install specific version' clicked for '$appName'."; $appId = $row.Cells["Id"].Value; $form.Cursor = 'WaitCursor'; $statusBarLabel.Text = "Searching versions for $appName..."; $versionsOutput = winget show --id $appId --versions --accept-source-agreements | Out-String; $availableVersions = $versionsOutput.Split([Environment]::NewLine) | Where-Object { $_ -match '^\d' } | ForEach-Object { $_.Trim() }; $form.Cursor = 'Default'; $statusBarLabel.Text = "Ready."; if (-not $availableVersions) { [System.Windows.Forms.MessageBox]::Show("No alternative versions found for '$appName'."); return }; $versionForm = New-Object System.Windows.Forms.Form; $versionForm.Text = "Choose version for $appName"; $versionForm.Size = '300,400'; $versionForm.StartPosition = "CenterParent"; $versionForm.BackColor = $Theme.FormBackground; $versionForm.ForeColor = $Theme.Text; $listBox = New-Object System.Windows.Forms.ListBox; $listBox.Dock = "Fill"; $listBox.BackColor = $Theme.GridCellBackground; $listBox.ForeColor = $Theme.Text; $listBox.Items.AddRange($availableVersions); $okButton = New-Object System.Windows.Forms.Button; $okButton.Text = "Set this version"; $okButton.Dock = "Bottom"; $okButton.DialogResult = "OK"; $okButton.FlatStyle = 'Flat'; $okButton.BackColor = $Theme.ButtonBackground; $okButton.FlatAppearance.BorderColor = $Theme.GridHeader; $versionForm.Controls.AddRange(@($listBox, $okButton)); if ($versionForm.ShowDialog($form) -eq "OK" -and $listBox.SelectedItem) { Append-Log "[Ctx Menu] Custom version '$($listBox.SelectedItem)' selected for '$appName'."; $row.Cells["AvailableVersion"].Value = $listBox.SelectedItem; $row.Cells["Status"].Value = "⚙️ Custom Version"; $row.DefaultCellStyle.BackColor = $Theme.HighlightYellow } } })

$uninstallMenuItem.Add_Click({

    if ($dataGridView.CurrentRow) {

        $appName = $dataGridView.CurrentRow.Cells["Name"].Value

        $confirmation = [System.Windows.Forms.MessageBox]::Show("Are you sure you want to uninstall $($appName)?", "Confirm Uninstallation", 'YesNo', 'Warning')

        if ($confirmation -eq 'Yes') {

            Append-Log "[Ctx Menu] Uninstallation of '$appName' confirmed."; $appId = $dataGridView.CurrentRow.Cells["Id"].Value; $script:TaskQueue.Clear(); $script:TaskQueue.Add(@{ StatusMessage = "Uninstalling $appName"; Arguments = "uninstall --id `"$appId`" --silent --disable-interactivity" }); Start-ProcessingQueue

        } else { Append-Log "[Ctx Menu] Uninstallation of '$appName' cancelled." }

    }

})

$repairMenuItem.Add_Click({

    if ($dataGridView.CurrentRow) {

        $appName = $dataGridView.CurrentRow.Cells["Name"].Value; $installedVersion = $dataGridView.CurrentRow.Cells["InstalledVersion"].Value

        $confirmation = [System.Windows.Forms.MessageBox]::Show("This will attempt to reinstall version $installedVersion of '$appName'.`n`nProceed?", "Confirm Repair", 'YesNo', 'Question')

        if ($confirmation -eq 'Yes') {

            Append-Log "[Ctx Menu] Repair of '$appName' confirmed."; $appId = $dataGridView.CurrentRow.Cells["Id"].Value; $script:TaskQueue.Clear(); $script:TaskQueue.Add(@{ StatusMessage = "Step 1/2 (Repair): Uninstalling $appName"; Arguments = "uninstall --id `"$appId`" --silent --disable-interactivity" }); $script:TaskQueue.Add(@{ StatusMessage = "Step 2/2 (Repair): Installing $appName (v$installedVersion)"; Arguments = "install --id `"$appId`" --version `"$installedVersion`" --force --silent --accept-source-agreements --disable-interactivity" }); Start-ProcessingQueue

        } else { Append-Log "[Ctx Menu] Repair of '$appName' cancelled." }

    }

})

$dataGridView.Add_MouseClick({ param($s, $e); if ($e.Button -eq 'Right') { $hit = $s.HitTest($e.X, $e.Y); if ($hit.RowIndex -ge 0) { $s.ClearSelection(); $s.Rows[$hit.RowIndex].Selected = $true } } })

$dataGridView.Add_CellClick({ param($sender, $e) ; if ($e.ColumnIndex -eq 0 -and $e.RowIndex -ge 0) { $sender.Rows[$e.RowIndex].Cells[0].Value = -not $sender.Rows[$e.RowIndex].Cells[0].Value; $sender.EndEdit(); Append-Log "[UI] Checkbox for '$($sender.Rows[$e.RowIndex].Cells['Name'].Value)' set to '$($sender.Rows[$e.RowIndex].Cells[0].Value)'." } })

# --- ENDREGION ---


# --- REGION: Application Start ---

$form.Add_Shown({

    Append-Log "--- Application Start ---"

    Load-Data

})

$form.ShowDialog() | Out-Null

Append-Log "--- Application Exit ---"

# --- ENDREGION ---
