# --------------------
# Active Directory user creation and disable processes are quite routine, not to say boring, so why not automate them to possible maximum?
# Once fired up, this script creates a user in the domain, generates a random password, applies rights based on AD groups (if any), creates an Exchange mailbox and sends the new user a greetings email.
# Some parts of the script are rather old and could (and should) be written better, once i have spare time.
# --------------------

Import-Module ActiveDirectory

Write-Host "`r`n`r`nThe script creates a user in the domain`r`n"

# Ask the console for user's name
[string]$LatinName = (Read-Host "Specify new user's LastName and FirstName (e.g. John Doe )").trim()
[string]$LastName = ($LatinName.Split(" "))[0]
[string]$FirstName = ($LatinName.Split(" "))[1]

# Generate a login like j.doe
[string]$Login = ($FirstName.SubString(0,1)+"."+$LastName).ToLower()

[string]$FullName = $LastName+" "+$Firstname

[string]$DisplayName = $FullName
# If you would like to have DisplayNames in cyrillic, replace the "$DisplayName = ..." with the following:
#[string]$DisplayName = (Read-Host "Фамилия Имя КИРИЛЛИЦЕЙ (например: Иванов Иван )").trim()

# The Desciption field contains a task in service desk system (yes, we assume a user creation requires a task)
[string]$TaskNumber = Read-Host "Номер задачи в JIRA на заведение нового пользователя"
[string]$Descrip = "Service desk task #" + $TaskNumber

# If such a user doesn't exist
If (-Not (Get-ADUser -Filter {samAccountName -eq $Login}))
    {
    # Sometimes you would like to generate a random password for user to send it via email for example:
    # Generate random password (at least three types of symbols: capitals, lower, numbers and special symbols
    Do {
        # Four flags, one for each symbol type
        [bool]$Pwd_symbols = $false
        [bool]$pwd_numbers = $false
        [bool]$pwd_capitals = $false
        [bool]$pwd_lowercase = $false
        # Number of symbols if a password
        [int]$PwdLength = 8
        # An array of random symbols (except those not acceptable)
        $ArrayPwd = [array]::CreateInstance([char],$pwdLength)
        $values = (33,34,35,36,37,38,39,40,41,42,43,44,45,46,48,49,50,51,52,53,54,55,56,57,58,60,61,62,63,64,65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,80,81,82,83,84,85,86,87,88,89,90,91,93,94,95,96,97,98,99,100,101,102,103,104,105,106,107,108,109,110,111,112,113,114,115,116,117,118,119,120,121,122)
        for ($i=0;$i -lt $pwdLength;$i++)
            {
            $Rnd_Char = Get-Random $values
            if (($Rnd_char -ge 48) -and ($rnd_char -le 57)) {$pwd_numbers = $true}
            if (($Rnd_Char -ge 65) -and ($rnd_char -le 90)) {$pwd_capitals = $true}
            if (($Rnd_Char -ge 97) -and ($rnd_char -le 122)) {$pwd_lowercase = $true}
            if (($Rnd_Char -le 46) -or (($rnd_char -ge 58) -and ($rnd_char -le 64)) -or (($rnd_char -ge 91) -and ($rnd_char -le 96))) {$pwd_symbols = $true}
            $my_char = [char]::ToString($rnd_char)
            # Put a random char to an array
            $ArrayPwd[$i] = $my_char
            }
        # Password simple string
        [string]$PasswdSimple = ""
        # Make a string from a char array
        foreach ($char in $ArrayPwd) {$PasswdSimple = $PasswdSimple+$char}
        # Count how many symbol types do we gave
        $SymbolTypeCount = 0
        if ($pwd_symbols) {$SymbolTypeCount += 1}
        if ($pwd_numbers) {$SymbolTypeCount += 1}
        if ($pwd_capitals) {$SymbolTypeCount += 1}
        if ($pwd_lowercase) {$SymbolTypeCount += 1}
        }
    # If there are less than 3 types - repeat the randomize
    While ($SymbolTypeCount -lt 3)
    
    # Convert a password to secure string
    $Passwd = ConvertTo-SecureString -AsPlainText -force $PasswdSimple
    
    # Create a new user with a number of fields
    New-ADUser -samAccountName $Login -Name $FullName -GivenName $FirstName -Surname $LastName -AccountExpirationDate $null -AccountPassword $Passwd -CannotChangePassword $false -ChangePasswordAtLogon $false -Description $Descrip -DisplayName $DisplayName -Enabled $true -UserPrincipalName "$login@company.com" -Confirm:$false
    
    If (Get-ADUser -Filter {samAccountName -eq $Login})
        {
        Write-Host "`r`nNew user has been created: $Login"
        # Get a user from a samAccountName
        $User = Get-ADUser $Login -Prop mail
        
        # Move the new user to target OU
        [string]$TargetOU = "OU=Users,DC=company,DC=local"
        Move-ADObject $User.DistinguishedName -TargetPath $TargetOU

        # Ask the console if the user does need a local Exchange mailbox
        [string]$MailEnabled = Read-Host "`r`nDoes the user need a local Exchange mailbox? [y = yes]"
        if ($MailEnabled -eq "y")
            {
            # Choose an Exchange database
	        Do
		        {
                $DBSwitch = Read-Host "`r`nPlease choose an Exchange database to create a mailbox (1 = 'regular-users', 2 = 'regional-branches', 3 = 'vip-users')"
                }
	        Until (($DBSwitch -eq "1") -or ($dbswitch -eq "2") -or ($dbswitch -eq "3"))
	        
            Switch ($DBSwitch) {
		        1 {$Database = "regular-users"}
		        2 {$Database = "regional-branches"}
		        3 {$Database = "vip-users"}
		        Default {$Database = "regular-users"}
		        }

            # Create a mailbox
	        Enable-Mailbox $Login -Database $database
            # Disable ActiveSync, OWA, POP, IMAP by default
	        Set-CASMailbox $Login -ActivesyncEnabled $false -owaenabled $false -popenabled:$false -imapenabled:$false
	        # Add the email address to "all users" Distibution list
            Add-DistributionGroupMember "DL-AllUsers" -Confirm:$false -Member $login
            }

        # If you need to add user to specific AD groups for specific access, for example
        $JiraAccess = Read-Host "`r`nDoes the user need JIRA access? [y = yes]"
        if ($JiraAccess -eq "y")
            {Add-ADGroupMember "jira-users" $Login -confirm:$false}
        
        # If you need to grant some users a VPN access (assume you have it based on Active Directory group)
        $VPNAccess = Read-Host "Does the user need a VPN connection? [y = yes]"
        if ($VPNAccess -eq "y")
            {Add-ADGroupMember "cisco-vpn-regularusers" $Login -confirm:$false}

        # Send the new user a 'hello' message
        # Mail server
        $SmtpServer = "mail.company.com"
        # .NET object MailMessage
        $Msg = new-object Net.Mail.MailMessage
        # .NET object SMTP server
        $Smtp = new-object Net.Mail.SmtpClient($smtpServer)
        # Email structure
        $Msg.From = "noreply@company.com"
        $Msg.ReplyTo = "sysadmins@company.com"
        $Msg.To.Add($User.mail)
        # Add a hidden copy to helpdesk specialists, maybe they'll need the info as well as password for the first login
        #$Msg.CC.Add("helpdesk@company.com")
        $Msg.Subject = "Your new account in Company domain"
        $Msg.Body = "Dear collegue,`r`n`r`n"
        $Msg.Body += "Hi there! Your login in our domain is: $Login`r`nYour password for now is: $PasswdSimple , please consider changing it as soon as possible.`r`nYour domain name is: company.local`r`n`r`n"
        if ($JiraAccess -eq "y")
            {$Msg.Body += "Here is a link to our JIRA: https://jira.company.local (you have to supply your login without specifying a domain)`r`n`r`n"}
        # Attach a PDF instruction for VPN client setup
        if ($VPNAccess -eq "y")
            {
            $Msg.Body += "If you need to set up a VPN client, please see the instruction attached to this email.`r`n`r`n"
            $VPNAttach = New-Object Net.Mail.Attachment("C:\powershell\vpn-client.pdf")
            $Msg.Attachments.Add($VPNAttach)
            }
        $Msg.Body += "`r`nThis email is generated automatically, if you have any questions please contact us at sysadmins@company.com"
        $Msg.SubjectEncoding = [System.Text.Encoding]::UTF8
        $Msg.BodyEncoding = [System.Text.Encoding]::UTF8
        # Send email
        $Smtp.Send($Msg)
        
        # Remove attach
        If ($VPNAttach -ne $null) {$VPNAttach.Dispose()}
        
        Write-Host "`r`nAn email has been sent."
        }
    Else
        {
        Write-Host "`r`nSomething went wrong during the user creation process, there's no such user!" -ForegroundColor:red
        }
    }
Else
    {
    Write-Host "`r`nThere is already a user with such login: $Login!" -ForegroundColor:red
    }
    
Write-Host "`r`n"