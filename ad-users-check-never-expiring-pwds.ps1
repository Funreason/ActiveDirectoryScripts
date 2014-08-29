# --------------------
# The script checks for User objects whose password never expire (which is wrong by security means), and alerts the admin by email
# Could be scheduled to run daily
# --------------------

Import-Module ActiveDirectory

# Get all user objects in an OU, filter out those in OU=ServiceAccounts (if you have such an OU with accounts which could have never-expiring password, although it's not a best practice)
$Users = Get-ADUser -Filter * -SearchBase "OU=RegularUsers,DC=company,DC=local" -Property PasswordNeverExpires,DisplayName,Description | Where {($_.DistinguishedName -notlike "*OU=ServiceAccounts*") -and ($_.PasswordNeverExpires -ne $false)} | Sort samAccountName

# Script output
$Output = $Users | ft samAccountName,DisplayName,Description,PasswordNeverExpires -Autosize -Wrap

# Send an email to admin
$SmtpServer = "mail.company.com"
# .NET object MailMessage
$Msg = New-Object Net.Mail.MailMessage
# .NET object SmtpClient
$Smtp = New-Object Net.Mail.SmtpClient($SmtpServer)
# Email details
$Msg.From = "ad_script_log@company.com"
$Msg.ReplyTo = "winadmin@company.com"
$Msg.To.Add("winadmin@company.com")
$Msg.Subject = "Active Directiry: Users whose passwords never expire"
$Msg.Body = $Output
# Send email
$Smtp.Send($Msg)