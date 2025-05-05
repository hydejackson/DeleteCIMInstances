# Deletes user profiles from computers in -ComputerName besides the ones specified in the -Profiles parameter.
# Usage: PATH/TO/SCRIPT -Profiles ProfileName1,ProfileName2,...,ProfileName999 -ComputerName NameOfComputer1,NameOfComputer2,...

param (
    [string]$Profiles = '',
    [string[]]$ComputerName = @()
)

$Usage = 'PATH/TO/SCRIPT -Profiles ProfileName1,ProfileName2,...,ProfileName999 -ComputerName NameOfComputer1,NameOfComputer2,...'

# Separates user input into a list of profile names to not include in the deletion list
$AccountsToKeep = $Profiles.Split(',')
[array]$DefaultAccounts = @()
foreach ($AccountToKeep in $AccountsToKeep) {
    $DefaultAccounts += $AccountToKeep
}

# Collect all profiles to delete across all computers
$ProfilesToDelete = @()

foreach ($Computer in $ComputerName) {
    Write-Host "Processing computer: $Computer"

    try {
        $AccountsToDelete = Get-CimInstance -ComputerName $Computer -Class Win32_UserProfile | Where-Object { 
            $_.LocalPath.split('\')[-1] -notin $DefaultAccounts -and $_.LocalPath.split('\')[-1] -like 'fs*' 
        }
    } catch {
        Write-Host "The computer name '$Computer' was probably not found.
        Usage: $Usage"
        continue
    }

    if ($AccountsToDelete.Count -eq 0 -or $null -eq $AccountsToDelete.Count) {
        Write-Host "No profiles found eligible for deletion on computer: $Computer.
        Usage: $Usage"
        continue
    }

    foreach ($AccountToDelete in $AccountsToDelete) {
        $ProfilesToDelete += $AccountToDelete
    }
}

# If no profiles are found for deletion, exit the script
if ($ProfilesToDelete.Count -eq 0) {
    Write-Host "No profiles found eligible for deletion on any computer."
    exit
}

# List all profiles to be deleted and prompt for confirmation
Write-Host "The following profiles are marked for deletion:"
$ProfilesToDelete | ForEach-Object { Write-Host "$($_.PSComputerName): $($_.LocalPath)" }
$ProfilesToDelete | Group-Object -Property PSComputerName | ForEach-Object {
    Write-Host "$($_.Name): $($_.Count) profiles marked for deletion."
}

$Confirmation = Read-Host "Do you want to proceed with deleting these profiles? (Y/N)"
if ($Confirmation -notin @('Y', 'y')) {
    Write-Host "Operation canceled by user."
    exit
}

# Perform deletion for all computers
foreach ($ComputerGroup in $ProfilesToDelete | Group-Object -Property PSComputerName) {
    $Computer = $ComputerGroup.Name
    $AccountsToDelete = $ComputerGroup.Group
    Write-Host "$ComputerGroup.Name: $($ComputerGroup.Group.Count) profiles to delete."

    Write-Host "Deleting profiles on computer: $Computer"

    $AccountsToDelete | ForEach-Object {
        try {
            # Use the CimInstance object directly
            Remove-CimInstance -InputObject $_ -ErrorVariable RemoveCimInstanceErr -ErrorAction SilentlyContinue
        } catch {
            Write-Host "Error on computer $Computer : $($_)"
        }
    }

    if ($RemoveCimInstanceErr) {
        $LogPath = "./DUPLog_$Computer.log"
        Set-Content -Path $LogPath -Value $RemoveCimInstanceErr
        Write-Host "Non-terminating errors encountered on computer: $Computer. Logged in $LogPath."
    } else {
        Write-Host "Success: $Computer."
    }
}