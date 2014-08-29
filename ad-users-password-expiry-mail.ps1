# --------------------
# The script checks all Active Directory User objects' password expiry dates and sends email notifications to users, and statictics to local support specialists
# --------------------

Import-Module ActiveDirectory

# Get all users, filter out disabled and expired
$Users = Get-ADUser -Filter {Enabled -eq $True -and PasswordNeverExpires -eq  $False} -Prop msDS-UserPasswordExpiryTimeComputed,AccountExpirationDate,mail -SearchBase "OU=RegularUsers,dc=company,dc=com" | Where {$_.AccountExpirationDate -eq $null} | Sort msDS-UserPasswordExpiryTimeComputed

# Body of a message
[string]$LogBody = ""

# Current date +7 days
[datetime]$ThresholdDate = (Get-Date).AddDays(7)
# Current date
[datetime]$CurrentDate = Get-Date
[string]$CurrentDateFormat = Get-Date $CurrentDate -Format "dd-MM-yyyy"

# SMTP server
$SmtpServer = "mail.company.com"

$Users | ForEach {
    # Current user's password expiry day
    $ExpiryDate = [datetime]::FromFileTime(($_)."msDS-UserPasswordExpiryTimeComputed")
    # in adequate format
    $ExpiryDateFormat = Get-Date $ExpiryDate -Format dd-MM-yyyy
    if ($Expirydate -lt $ThresholdDate)
        {
        # Number of days left before password expiry
        $DaysToExpiry = ($ExpiryDate - $CurrentDate).days
        $Login = $_.samAccountName
        $Email = $_.Mail
        If ($Email -match "@")
            {
            # .NET object MailMessage
            $Msg = New-Object Net.Mail.MailMessage
            # .NET object SmtpClient
            $Smtp = New-Object Net.Mail.SmtpClient($SmtpServer)
            # Email details
            $Msg.From = "noreply@company.com"
            $Msg.ReplyTo = "sysadmins@company.com"
            $Msg.To.Add($Email)
            $Msg.subject = "Your account's password is soon to expire"
            $Msg.body = "Dear user,`r`n`r`nThe password of your $login account in COMPANY domain is expiring at $ExpiryDateFormat, in $DaysToExpiry days. Please consider changing your password, otherwise you might lose access to Company's corporate systems.`r`nIf you have questions or troubles concerning password change, please contact us at sysadmins@company.com"
            $Msg.SubjectEncoding = [System.Text.Encoding]::UTF8
            $Msg.BodyEncoding = [System.Text.Encoding]::UTF8
            # Send email
            $Smtp.Send($Msg)
            $LogBody += "Sent a notification to $Login at $Email, whose password expires on $ExpiryDateFormat.`r`n"
            }
         Else
            {
            $LogBody += "User $Login doesn't gave an email address filled in, email notifications are not possible!`r`n"
            }
        }
    }
    
# Send a statistics email to admin
# .NET object MailMessage
$Msg = New-Object Net.Mail.MailMessage
# .NET object SmtpClient
$Smtp = New-Object Net.Mail.SmtpClient($SmtpServer)
# Email details
$Msg.From = "ad_script_log@company.com"
$Msg.ReplyTo = "winadmin@company.com"
$Msg.To.Add("sysadmins@company.com")
$Msg.Subject = "Active Directory: Users' passwords expiration for $CurrentDateFormat"
$Msg.Body = $LogBody
$Msg.SubjectEncoding = [System.Text.Encoding]::UTF8
$Msg.BodyEncoding = [System.Text.Encoding]::UTF8
# Send email
$Smtp.Send($Msg)