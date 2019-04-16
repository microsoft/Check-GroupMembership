# Copyright (c) Microsoft. All rights reserved.
# Licensed under the MIT license. See LICENSE.txt file in the project root for full license information.

<#

.SYNOPSIS
This is a sample script which retrieves group membership information from both Azure Active Directory and Exchange Online to check if they match each other.

.DESCRIPTION
This script runs Get-* cmdlets for Azure Active Directory and Exchange Online to collect group information.
The Azure Active Directory V1 module (MSOnline) must be installed on your computer.

.LINK
https://github.com/Microsoft/Check-GroupMembership

.OUTPUTS
A CSV file will be created in the same directory as the script file is located.
If there are any inconsistencies in between Azure Active Directory and Exchange Online in terms of group membership information, the output file will contain the group information which needs attention.
If no issues are found with the group memberships, the output file will be empty.

.EXAMPLE
.\Check-GroupMembership.ps1

.NOTES
This script adopts the methods described in the following article to alleviate PowerShell Throttling and to have enhanced session stability.

Running PowerShell cmdlets for large numbers of users in Office 365
https://blogs.technet.microsoft.com/exchange/2015/11/02/running-powershell-cmdlets-for-large-numbers-of-users-in-office-365/

#>


# Setup PowerShell Session for Office 365
function Connect-O365 {

    # Setup a credential
    $Cred = Get-Credential -Message "Please enter your Office 365 Admin credentials."
    Set-Variable -Name AdminCred -Value $Cred -Scope Script

    Write-Progress -Activity "Connecting to Azure Active Directory and Exchange Online" -Status "Connecting..."

    # Connect to Azure Active Directory
    Import-Module MSOnline -ErrorAction Stop
    Connect-MsolService -Credential $AdminCred -ErrorAction Stop

    # Connect to Exchange Online
    New-ExoSession

    Write-Progress -Activity "Connected to Azure Active Directory and Exchange Online" -Status "Connected" -Completed
}

# Destroy PowerShell Session for Office 365
function Disconnect-O365 {

    Remove-ExoSession
}

# Create new PowerShell Session for Exchange Online
function New-ExoSession {

    # Remove an existing session for Exchange Online
    Remove-ExoSession

    # Create a session for Exchange Online
    $TryCount = 0
    do {
        $TryCount++

        $Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://outlook.office365.com/powershell-liveid/ -Credential $AdminCred -Authentication Basic -AllowRedirection
        if ($null -eq $Session) {

            # Abort if retry count for session creation is over 3 times
            if ($TryCount -ge 3) {
                exit
            }

            # Sleep 60s in the hope that the issue is transient
            Start-Sleep -Seconds 60
        }
    } while ($null -eq $Session)

    $SessionInfo = New-Object PSObject
    $SessionInfo | Add-Member -MemberType NoteProperty -Name "Session"     -Value $Session
    $SessionInfo | Add-Member -MemberType NoteProperty -Name "ConnectTime" -Value (Get-Date)
    Set-Variable -Name ExoSession -Value $SessionInfo -Scope Script
}

# Remove PowerShell Session for Exchange Online
function Remove-ExoSession {

    # Remove a session for Exchange Online
    if ($null -ne $ExoSession -and $null -ne $ExoSession.Session) {
        Remove-PSSession -Session $ExoSession.Session -Confirm:$false
    }

    Set-Variable -Name ExoSession -Value $null -Scope Script

    [System.GC]::Collect()
}

# Get PowerShell Session for Exchange Online
function Get-ExoSession {

    # Recreate an existing session as needed (for the purpose of Session Stability)
    $CurrentTime = Get-Date
    if ($null -eq $ExoSession -or $ExoSession.Session.State -ne "Opened" -or ($CurrentTime - $ExoSession.ConnectTime).TotalSeconds -gt 900) {
        New-ExoSession
    }    

    return $ExoSession.Session
}

# Run a command for Exchange Online
function Execute-CommandToExo($Command) {

    # Get a session for Exchange Online
    $Session = Get-ExoSession

    # Build the script block we want to run for Exchange Online
    $ScriptBlock = [System.Management.Automation.ScriptBlock]::Create($Command)

    # Invoke the command on the remote server
    $ExecutionTime = Measure-Command {
        $ExecutionResult = Invoke-Command -Session $Session -ScriptBlock $ScriptBlock
    }

    # Sleep a sufficient time (for the purpose of alleviating PowerShell Throttle)
    Start-Sleep -Milliseconds ($ExecutionTime.TotalMilliseconds)

    return $ExecutionResult
}

# Write output to a file
function Export-Log($Data, $Path) {

    if ($null -ne $Data) {
        $Data | Export-Csv -Path $Path -NoTypeInformation -Encoding UTF8
    }
    else {
        New-Item -Path $Path -Type file -Force | Out-Null
    }
}

# Format string for the member information
function Format-DisplayString($MemberList) {

    $EntryList = @()
    foreach ($Member in $MemberList) {
        $EntryList += "{ObjectId=$($Member.ObjectId);DisplayName=$($Member.DisplayName);EmailAddress=$($Member.EmailAddress);Description=$($Member.Description)}"
    }

    $Text = "[" + [String]::Join(";", $EntryList) + "]"
    return $Text
}

# Check if a group's membership information matches in both Azure Active Directory and Exchange Online 
function Check-InconsistentGroupMember($AadGroup, $ExoGroup) {

    # Get the list of group members
    $AadGroupMemberList = @(Get-MsolGroupMember -GroupObjectId $AadGroup.ObjectId -All)
    $ExoGroupMemberList = @(Execute-CommandToExo -Command ("Get-DistributionGroupMember -Identity $($ExoGroup.ExternalDirectoryObjectId.ToString()) -ResultSize Unlimited | Select-Object -Property ExternalDirectoryObjectId")) | Where-Object { $_.ExternalDirectoryObjectId.ToString() -ne "" }

    # Create a table for comparison
    $ExoGroupMemberTable = @{ }
    foreach ($ExoGroupMember in $ExoGroupMemberList) {
        $ExoGroupMemberTable.Add($ExoGroupMember.ExternalDirectoryObjectId.ToString(), $ExoGroupMember)
    }

    $InconsistentGroupMember = @()

    foreach ($AadGroupMember in $AadGroupMemberList) {

        # Check if a member object in Azure Active Directory exists in Exchange Online
        if ($null -ne ($ExoGroupMember = $ExoGroupMemberTable[$AadGroupMember.ObjectId.ToString()])) {

            # Remove a checked member from the table
            $ExoGroupMemberTable.Remove($ExoGroupMember.ExternalDirectoryObjectId.ToString())

            # This is a member object that exists in Azure Active Directory but not in Exchange Online
        }
        else {
            $GroupMemberInfo = New-Object PSObject
            $GroupMemberInfo | Add-Member -MemberType NoteProperty -Name "ObjectId"     -Value $AadGroupMember.ObjectId.ToString()
            $GroupMemberInfo | Add-Member -MemberType NoteProperty -Name "DisplayName"  -Value $AadGroupMember.DisplayName.ToString()
            $GroupMemberInfo | Add-Member -MemberType NoteProperty -Name "EmailAddress" -Value $AadGroupMember.EmailAddress.ToString()
            $GroupMemberInfo | Add-Member -MemberType NoteProperty -Name "Description"  -Value "AAD-Only"
            $InconsistentGroupMember += $GroupMemberInfo
        }
    }

    # These are member objects that exist in Exchange Online but not in Azure Active Directory
    foreach ($ExoGroupMember in $ExoGroupMemberTable.Values) {

        # Get detail information for this member
        $ExoGroupMemberDetail = Execute-CommandToExo -Command ("Get-Recipient -Identity $($ExoGroupMember.ExternalDirectoryObjectId.ToString()) | Select-Object -Property DisplayName,PrimarySmtpAddress")

        $GroupMemberInfo = New-Object PSObject
        $GroupMemberInfo | Add-Member -MemberType NoteProperty -Name "ObjectId" -Value $ExoGroupMember.ExternalDirectoryObjectId.ToString()
        if ($null -ne $ExoGroupMemberDetail) {
            $GroupMemberInfo | Add-Member -MemberType NoteProperty -Name "DisplayName"  -Value $ExoGroupMemberDetail.DisplayName.ToString()
            $GroupMemberInfo | Add-Member -MemberType NoteProperty -Name "EmailAddress" -Value $ExoGroupMemberDetail.PrimarySmtpAddress.ToString()
        }
        else {
            $GroupMemberInfo | Add-Member -MemberType NoteProperty -Name "DisplayName"  -Value "<Not a mail-enabled recipient>"
            $GroupMemberInfo | Add-Member -MemberType NoteProperty -Name "EmailAddress" -Value $null
        }
        $GroupMemberInfo | Add-Member -MemberType NoteProperty -Name "Description" -Value "EXO-Only"
        $InconsistentGroupMember += $GroupMemberInfo
    }

    return $InconsistentGroupMember
}

# Check the sync state for groups in Azure Active Directory and Exchange Online
function Check-InconsistentGroup {

    Write-Progress -Activity "Collecting group information from Azure Active Directory and Exchange Online" -Status "Collecting data..."

    # Get the list of groups
    $AadGroupList = @(Get-MsolGroup -All | Where-Object { $_.GroupType -eq "DistributionList" -or $_.GroupType -eq "MailEnabledSecurity" })
    $ExoGroupList = @(Execute-CommandToExo -Command "Get-DistributionGroup -ResultSize Unlimited | Select-Object -Property ExternalDirectoryObjectId") + @(Execute-CommandToExo -Command "Get-Mailbox -GroupMailbox -ResultSize Unlimited | Select-Object -Property ExternalDirectoryObjectId,RecipientTypeDetails") | Where-Object { $_.ExternalDirectoryObjectId.ToString() -ne "" }

    Write-Progress -Activity "Collected group information from Azure Active Directory and Exchange Online" -Status "Collected data" -Completed

    # Create a table for comparison
    $ExoGroupTable = @{ }
    foreach ($ExoGroup in $ExoGroupList) {
        $ExoGroupTable.Add($ExoGroup.ExternalDirectoryObjectId.ToString(), $ExoGroup)
    }

    $InconsistentGroup = @()

    $ProcessCount = 0
    foreach ($AadGroup in $AadGroupList) {

        Write-Progress -Activity "Checking the sync state for groups in Azure Active Directory and Exchange Online" -Status ("Check the count of group: [$ProcessCount/$($AadGroupList.Count)]") -PercentComplete ($ProcessCount / $AadGroupList.Count * 100)

        # Check if a group object in Azure Active Directory exists in Exchange Online
        if ($null -ne ($ExoGroup = $ExoGroupTable[$AadGroup.ObjectId.ToString()])) {

            # Skip checking group members for Office 365 Groups (Not Supported in this script)
            if (-not ($null -ne $ExoGroup.RecipientTypeDetails -and $ExoGroup.RecipientTypeDetails.ToString() -eq "GroupMailbox")) {

                # Check if members of a group match in both Azure Active Directory and Exchange Online
                $MismatchMemberList = @(Check-InconsistentGroupMember -AadGroup $AadGroup -ExoGroup $ExoGroup)

                # This is a group that has mismatched members
                if ($MismatchMemberList.Count -gt 0) {
                    $GroupInfo = New-Object PSObject
                    $GroupInfo | Add-Member -MemberType NoteProperty -Name "ObjectId"      -Value $AadGroup.ObjectId.ToString()
                    $GroupInfo | Add-Member -MemberType NoteProperty -Name "DisplayName"   -Value $AadGroup.DisplayName.ToString()
                    $GroupInfo | Add-Member -MemberType NoteProperty -Name "EmailAddress"  -Value $AadGroup.EmailAddress.ToString()
                    $GroupInfo | Add-Member -MemberType NoteProperty -Name "Description"   -Value "Mismatch-Member"
                    $GroupInfo | Add-Member -MemberType NoteProperty -Name "MemberDetails" -Value (Format-DisplayString -MemberList $MismatchMemberList)
                    $InconsistentGroup += $GroupInfo
                }
            }

            # Remove a checked group from the table
            $ExoGroupTable.Remove($ExoGroup.ExternalDirectoryObjectId.ToString())

            # This is a group object that exists in Azure Active Directory but not in Exchange Online
        }
        else {
            $GroupInfo = New-Object PSObject
            $GroupInfo | Add-Member -MemberType NoteProperty -Name "ObjectId"      -Value $AadGroup.ObjectId.ToString()
            $GroupInfo | Add-Member -MemberType NoteProperty -Name "DisplayName"   -Value $AadGroup.DisplayName.ToString()
            $GroupInfo | Add-Member -MemberType NoteProperty -Name "EmailAddress"  -Value $AadGroup.EmailAddress.ToString()
            $GroupInfo | Add-Member -MemberType NoteProperty -Name "Description"   -Value "AAD-Only"
            $GroupInfo | Add-Member -MemberType NoteProperty -Name "MemberDetails" -Value $null
            $InconsistentGroup += $GroupInfo
        }

        $ProcessCount++
    }

    # These are group objects that exist in Exchange Online but not in Azure Active Directory
    foreach ($ExoGroup in $ExoGroupTable.Values) {

        # Get detail information for this group
        $ExoGroupDetail = Execute-CommandToExo -Command ("Get-DistributionGroup -Identity $($ExoGroup.ExternalDirectoryObjectId.ToString()) | Select-Object -Property DisplayName,PrimarySmtpAddress")

        $GroupInfo = New-Object PSObject
        $GroupInfo | Add-Member -MemberType NoteProperty -Name "ObjectId"      -Value $ExoGroup.ExternalDirectoryObjectId.ToString()
        $GroupInfo | Add-Member -MemberType NoteProperty -Name "DisplayName"   -Value $ExoGroupDetail.DisplayName.ToString()
        $GroupInfo | Add-Member -MemberType NoteProperty -Name "EmailAddress"  -Value $ExoGroupDetail.PrimarySmtpAddress.ToString()
        $GroupInfo | Add-Member -MemberType NoteProperty -Name "Description"   -Value "EXO-Only"
        $GroupInfo | Add-Member -MemberType NoteProperty -Name "MemberDetails" -Value $null
        $InconsistentGroup += $GroupInfo
    }

    Write-Progress -Activity "Checked the sync state for groups in Azure Active Directory and Exchange Online" -Status ("Check the count of group: [$ProcessCount/$($AadGroupList.Count)]") -Completed

    return $InconsistentGroup
}


#############
# File Info #
#############

# Prefix for the output file name
$LogfilePrefix = "CheckGroupMembership-"

###############
# Main Script #
###############

# Get the timestamp for when the script started
$TimeStamp = Get-Date

# Setup PowerShell Session for Office 365
Connect-O365

# Check if there are groups that have mismatching members
$Result = Check-InconsistentGroup

# Output results to a file
$Logfile = "$($PSScriptRoot)\$($LogfilePrefix)$($TimeStamp.ToString("yyyyMMddHHmmss")).csv"
Export-Log -Data $Result -Path $Logfile

# Destroy PowerShell Session for Office 365
Disconnect-O365