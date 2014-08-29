# --------------------
# Active Directory user creation and disable processes are quite routine, not to say boring, so why not automate them to possible maximum?
# Once fired up, this script "fires" a user, i.e. disables the account in Active Directory, removes from all groups, moves to "Disabled users" OU, then exports user's Exchange mailbox to PST and disables the mailbox.
# Some parts of the script are rather old and could (and should) be written better, once i have spare time.
# --------------------

Import-Module ActiveDirectory

Write-Host "`r`n`r`nThe script 'fires' a user, i.e. disables the account in Active Directory, removes from all groups and moves to 'DisabledUsers' OU, then exports user's Exchange mailbox to PST and disables the mailbox.`r`n"

# Ask console for a samAccountName
[string]$Login = Read-Host "Specify user's login (samAccountName)"

# Need to check if such a user exists in the domain
If (Get-ADUser -Filter {samAccountName -eq $Login})
    {
    [string]$FireDate = Read-Host "Specify the day user has been disabled (in dd/MM/yy format)" #is useful if somebody asks about it
    [string]$FireInfo = Read-Host "Specify the Service Desk task number" #yes, we assume that there should be a task to disable a user
    [string]$FireDesc = "Disabled on "+$FireDate+" (ServiceDesk task # "+$FireInfo+")"
    
    # Disable the user and set a description with details provided
    Disable-ADAccount $Login
    Set-ADUser $Login -Description $FireDesc

    $User = Get-ADUser $Login -Properties MemberOf,DistinguishedName
    # Remove the user from all AD groups
    $UserGroups = $User.MemberOf
    $UserGroups | ForEach {Get-ADGroup $_ | Remove-ADGroupMember -Member $Login -Confirm:$false}
    
    # Remove the accidental deletion protection, if any
    Set-ADObject $User -ProtectedFromAccidentalDeletion:$false

    # Move user to "disabled" OU
    Move-ADObject $User.DistinguishedName -TargetPath 'OU=DisabledUsers,DC=company,DC=local'

    # Check if the user does have Exchange attributes
    $MailEnabled = $User.msExchHomeServerName

    # Export the mailbox to PST file on some external file server/NAS storage
    If ($MailEnabled -ne $null)
        {
	    $Stats = Get-MailboxStatistics $Login
	    $MailboxSize = $Stats.TotalItemSize
	    Write-Host "`r`nUser's mailbox size:" $mailboxsize
	    Write-Host "`r`nExporting the mailbox to PST..."
	    New-MailboxExportRequest $Login -FilePath "\\storage\pst$\$Login.pst"
        # Check export status every 30 seconds until it is over
        # (yes, this part should be replaced with an adequate progress bar once i have some spare time)
    	Do {
		    Sleep 30
		    $ExportRequest = Get-MailboxExportRequest | Where {$_.FilePath -match "$Login"}
		    $Status = $ExportRequest.Status
		    If ($Status -like "Completed") {Write-Host "Export has finished without errors."}
		    ElseIf ($Status -like "CompletedWithWarnings") {Write-Host "Export has finished with warnings!" -ForegroundColor:red}
		    ElseIf ($Status -like "Failed") {Write-Host "Export has finished with errors!" -ForegroundColor:red}
	        }
	    While (($Status -notlike "Completed") -and ($Status -notlike "CompletedWithWarnings") -and ($Status -notlike "Failed"))
	
        # Remove successful export requests, no need in them anymore
	    Get-MailboxExportRequest | Where {$_.Status -like "Completed"} | Remove-MailboxExportRequest -Confirm:$false
	
	    # Ask console if it's ok to disable a mailbox
        $DM = Read-Host "`r`nDisable the mailbox? [y = yes]"
	    If ($DM -eq "y")
            {
            Disable-Mailbox $Login -Confirm:$false
		    write-host "The mailbox has been disabled."
            }
        }
    Else
        {
        Write-Host "Looks like the user doesn't have a mailbox."
        # In case there's no mailbox but there still is a mailuser, remove all Exchange attributes
        Disable-MailUser $Login -confirm:$false
        }

    # Move user's home directory from \\FileServe\User\ to some storage \\storage\public\homedir\
    & "robocopy \\fileserver\user\$Login \\storage\homedirs$\$Login *.* /move /e /is /r:0 /w:0 /nfl /ndl /njh /njs"
    }
Else
    {
    Write-Host "`r`nThere's no such user in the domain."
    }

Write-Host "`r`n"