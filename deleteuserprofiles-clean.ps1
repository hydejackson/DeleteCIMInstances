# Deletes user profiles from machine besides the ones in AccountsToKeep
# Usage: PATH/TO/SCRIPT -Profiles ProfileName1,ProfileName2,...,ProfileName999 -ComputerName NameOfComputer

# https://stackoverflow.com/questions/60255255/how-can-i-delete-all-windows-user-profiles-except-for-the-ones-i-specify
# https://adminbraindump.com/post/delete-windows-user-profile/

param (
    [string]$Profiles = '',
    [string]$ComputerName = ''
)

$Usage = 'PATH/TO/SCRIPT -Profiles ProfileName1,ProfileName2,...,ProfileName999 -ComputerName NameOfComputer'

# Separates user input into a list of profile names to not include in the deletion list
$AccountsToKeep = $Profiles.Split(',')
[array]$DefaultAccounts = ('FirstSolar','NetworkService','LocalService','systemprofile')
foreach ($AccountToKeep in $AccountsToKeep) {
    $DefaultAccounts += $AccountToKeep
}

# Removes the specified account names from $AccountsToDelete
try {
    $AccountsToDelete = Get-CimInstance -ComputerName $ComputerName -Class Win32_UserProfile | Where-Object { $_.LocalPath.split('\')[-1] -notin $DefaultAccounts }
} catch {
    Write-Host "The computer name you gave was probably not found. Try again and make sure the case is correct (e.g. `FS` instead of `fs`).
    Usage: $Usage"
    Exit
}

#In case there are no eligible profiles, exit.
if ($AccountsToDelete.Count -eq 0) {
    Write-Host "No profiles found eligible for deletion.
    Usage: $Usage"
    Exit
}

#In case there are no eligible profiles, exit.
if ($null -eq $AccountsToDelete.Count) {
    Write-Host "No profiles found eligible for deletion.
    Usage: $Usage"
    Exit
}

#List the profiles expected to be deleted.
foreach ($AccountToDelete in $AccountsToDelete) {
    Write-Host $AccountToDelete.LocalPath.split('\')[-1]
}

$NumberOfAccounts = $AccountsToDelete.Count
Write-Host "Found the $NumberOfAccounts profiles above to delete. Remove these profiles? Please confirm, then wait."

#Perform operation, asking for confirmation.
$AccountsToDelete | Remove-CimInstance -Confirm -ErrorVariable RemoveCimInstanceErr -ErrorAction SilentlyContinue 

Write-Host "Success."

if ($RemoveCimInstanceErr) {
    Set-Content -Path "./DUPLog.log" -Value $RemoveCimInstanceErr
    Write-Host "Non-terminating errors encountered. Logged in DUPLog.log."
}