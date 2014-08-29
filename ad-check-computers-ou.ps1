# --------------------
# The script checks for Computer objects in 'Computers' container, to which no Group Policies are applied, and alerts the admin by email
# Could be scheduled to run weekly for example
# --------------------

Import-Module ActiveDirectory

# Output of the script
[string]$Output = "Servers in 'Computers' container, no Group policies are applied:`r`n`r`n"

# Get all the servers in default container
$AllServers = Get-ADComputer -Filter * -SearchBase "CN=Computers,DC=company,DC=local" | Sort Name

# If there are any servers
If ($AllServers)
    {
    $Output += $AllServers -join "`r`n"
    # Send an email
    $SmtpServer = "mail.intel-lect.ru"
    # .NET object MailMessage
    $Msg = new-object Net.Mail.MailMessage
    # .NET object SmtpClient
    $Smtp = new-object Net.Mail.SmtpClient($SmtpServer)
    # Email details
    $Msg.From = "ad_script_log@company.com"
    $Msg.ReplyTo = "winadmin@company.com"
    $Msg.To.Add("winadmin@company.com")
    $Msg.Subject = "Active Directory: Servers in 'Computers' container"
    $Msg.Body = $Output
    # Send email
    $Smtp.Send($Msg)
    }