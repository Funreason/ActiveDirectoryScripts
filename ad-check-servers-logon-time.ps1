# --------------------
# The script checks for stale Computer objects and alerts the admin by email
# Could be scheduled to run weekly for example
# --------------------

Import-Module ActiveDirectory

# Script output
[string]$Output = "Server Name : Date of last login to Active Directory`r`n`r`n"

# Current date - 30 days
[datetime]$ThresholdDate = (Get-Date).AddDays(-30)

# Servers in target OU
$AllServers = Get-ADComputer -Filter * -Property * -SearchBase "OU=Servers,DC=company,DC=local" | Where {$_.Enabled -ne $false} | Sort LastLogonTimestamp

ForEach ($Server in $AllServers)
    {
    # If last logon is older than $ThresholdDate and the server name is not a ClusterNameObject
    If (([DateTime]::FromFileTime($Server.LastLogon) -le $ThresholdDate) -And ($Server.Description -ne "Failover cluster virtual network name account"))
        {
        $Output += $Server.Name+" : "+[DateTime]::FromFileTime($Server.LastLogon).ToString('dd/MM/yyyy')+"`r`n"
        }
    }

If ($Output -notlike "Server Name : Date of last login to Active Directory`r`n`r`n")
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
    $Msg.Subject = "Active Directory: Servers haven't logged in for more than 30 days"
    $Msg.Body = $Output
    # Send email
    $Smtp.Send($Msg)
    }