# --------------------
# The script checks users' last logon date and alerts the admin about those who have not logged in for more than days
# Could be scheduled weekly
# --------------------

Import-Module ActiveDirectory

# Current date -30 days
[datetime]$Threshold1Month = (Get-Date).AddDays(-30)
[string]$Threshold1MonthStr = Get-Date $Threshold1Month -Format "dd.MM.yyyy"
# Current date in string for logging
[string]$Today = (Get-Date).ToString()

# Script output
[string]$Output = "Script run date: $Today`r`n`r`nUsers in COMPANY.LOCAL domain, who have not logged in for more than 30 days, since "+$Threshold1MonthStr+" :`r`n`r`n"

# Get all users in target OU
$AllUsers = Get-ADUser -Filter {Enabled -eq $true} -SearchBase "ou=RegularUsers,dc=company,dc=local" -Prop LastLogonDate,Enabled,Displayname,mail | Sort LastLogonDate

ForEach ($User in $AllUsers)
    {
    [string]$CurrentLogin = $User.samAccountName
    [string]$CurrentDisplayName = $User.DisplayName
    [string]$CurrentEmail = $User.Mail
    If ($User.LastLogonDate -ne $null)
        {
        [datetime]$CurrentLastLogon = Get-Date ($User.LastLogonDate)
        If ($CurrentLastLogon -lt $Threshold1Month)
            {
            [string]$CurrentLastLogonStr = Get-Date $CurrentLastLogon -Format dd.MM.yyyy
            $Output += "User $CurrentLogin ($CurrentDisplayName, $CurrentEmail) hasn't logged in since $CurrentLastLogonStr, that is more than a month ago.`r`n"
            }
        }
     Else
        {
        $Output += "User $CurrentLogin ($CurrentDisplayName) has never logged in.`r`n"
        }
    }

If ($Output -notlike "Script run date: $Today`r`n`r`nUsers in COMPANY domain, who have not logged in for more than 30 days, since "+$Threshold1MonthStr+" :`r`n`r`n")
    {
    # Send an email
    $SmtpServer = "mail.company.com"
    # .NET object MailMessage
    $Msg = new-object Net.Mail.MailMessage
    # .NET object SmtpClient
    $Smtp = new-object Net.Mail.SmtpClient($SmtpServer)
    # Email details
    $Msg.From = "ad_script_log@company.com"
    $Msg.ReplyTo = "winadmin@company.com"
    $Msg.To.Add("winadmin@company.com")
    $Msg.Subject = "Active Directory: Users who have not logged in for more than 30 days"
    $Msg.Body = $Output
    # Send email
    $Smtp.Send($Msg)
    }