﻿#Term With Emails

Set-ExecutionPolicy RemoteSigned
$Who= whoami
$UserCredential = Get-Credential -Credential "$who"
$Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri http://edipswexmaa8.bsg.ad.adp.com/PowerShell/ -Authentication Kerberos -Credential $UserCredential
Import-PSSession $Session
Import-Module ActiveDirectory

#Fetching Admin Details
$whoAmI= ($Who -Split '\\')[1]
$Email=get-Aduser -identity $whoAmI -Properties * |select mail
$EmailId= $Email.mail

#Importing Users from CSV file
$Users = Import-Csv -Path "C:\Users\PuligaddaS\Desktop\PowerGUI\Term_List.csv"

#Adding Date
$Date= date
$DateStr = $Date.ToString("MM/dd/yyyy")

$Data= foreach($User in $Users)
{
Write-host $User
 #Fetch the values from CSV
 $EmpID= $User.EmployeeID
 $DisplayName= $User.DisplayName
 $RQSTNO= $user.RequestNo
 
 Try
 {
 #Get the User Details from AD based on EmployeeNumber
 $Names= Get-aduser -filter { employeenumber -eq $EmpID } -Server bsg.ad.adp.com:3268 | select name, samaccountname
 
 $DN= $Names.name     #AD DisplayName
 
 #Cross checking AD Display Name with CSV Display Name
 if($DN -eq $DisplayName)
 {
     Write-host "Condition Satisfied"

     $AccountName = $Names.samaccountname #AD SamAccountName

    #Checking User domain
     $UPN = (Get-ADUser -Identity $AccountName -Property UserPrincipalName -Server bsg.ad.adp.com:3268 ).UserPrincipalName
     $UPNSuffix = ($UPN -Split '@')[1] 
     $server= $UPNSuffix

    #Updating Description
     $ADUser = Get-ADUser -Identity $AccountName  -server $server -Properties *
     $ADUser.Description = "Termed - $DateStr - $RQSTNO" 

    #Disabling Account
     Disable-ADAccount -Identity $AccountName -server $server
     Set-ADUser -Instance $ADUser

    #Removing Group membership of User
     $Groups = Get-ADPrincipalGroupMembership $AccountName -Server $Server
    foreach($Group in $Groups)
    {
        if($Group.name -ne "Domain Users")
       {
        Remove-ADPrincipalGroupMembership -Identity $AccountName -MemberOf $Group -Confirm:$false
       }
    } #End of forloop

    #Working with Mailbox
     Set-Mailbox -Identity $AccountName  -HiddenFromAddressListsEnabled $true

     Set-Mailbox -Identity $AccountName -MaxSendSize  0KB  -MaxReceiveSize  0KB

     Write-Host $DN "account is termed"

     New-Object -TypeName psobject -Property @{
        EmpID = $EmpID
        ADUser = $ADUser.Name
        Email  = $ADUser.mail
        Description = $ADUser.Description
        Remarks= "Terminated"
        }
  }
 else
 {
 $DNM= "Details not matched"

 Write-Host $DNM

   New-Object -TypeName psobject -Property @{
        EmpID = $EmpID
        ADUser= $DN
        Email  = ""
        Description = "$RQSTNO"
        Remarks= $DNM
        }
    }
 }
 catch [Exception]{

        $_.Exception.message 
    
 }
} #End of Forloop


#Mailing Part#
$Header = @"
<style>

TABLE {font-family: "Trebuchet MS", sans-serif;border-width: 1px;border-style: solid;border-color: black;border-collapse: collapse;}
TH {border-width: 1px;padding: 6px;border-style: solid;border-color: black;background-color: #01CFCA;}
TD {border-width: 1px;padding: 4px;border-style: solid;border-color: black;}
TR:hover{background-color:#f5f5f5}
body {
   
} 
<link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/css/bootstrap.min.css">
<script src="https://ajax.googleapis.com/ajax/libs/jquery/3.2.1/jquery.min.js"></script>
<script src="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/js/bootstrap.min.js"></script>
</style>
"@

$body =@"

<body>
  <h3> Below Users are Terminated by {0} </h3>

</body>
"@ -f $whoAmI

$body1 = $Data | Select-Object -Property EmpID,ADUser,Email,Description,Remarks | ConvertTo-Html -Head $Header -body $body

$fromaddress = $EmailId 
$toaddress = $EmailId 
$CCaddress = "GlobalHelpdeskIndiaTeam@broadridge.com" 
$Subject = "Termination Processed | $Datestr" 
$body = $body1
$smtpserver = "edgsmtp.broadridge.net" 

 ################
$message = new-object System.Net.Mail.MailMessage 
$message.From = $fromaddress 
$message.To.Add($toaddress) 
$message.CC.Add($CCaddress) 
$message.IsBodyHtml = $True 
$message.Subject = $Subject 
#$attach = new-object Net.Mail.Attachment($attachment) 
#$message.Attachments.Add($attach) 
$message.body = $body 
$smtp = new-object Net.Mail.SmtpClient($smtpserver) 
$smtp.Send($message) 