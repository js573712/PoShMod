function send-slackMessage($message){
$webhookURI = (($_conf.services) | ? {$_.id -eq "slack"}).url
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Content-Type", "application/json")
$body = @"
{
  `"message`": `"$message`"
}
"@
$response = Invoke-RestMethod "$webhookURI" -Method 'POST' -Headers $headers -Body "$body" -TimeoutSec 120
$response | ConvertTo-Json
}
# Google admin functions
function get-GUser($upn){
   # requires that GAM be installed and authorized
   # https://github.com/GAM-team/GAM/wiki
   write-host("Getting user report for [$upn]...") -ForegroundColor yellow
   gam report users user $upn | ConvertFrom-Csv
   return
}
function get-GGroupMembership{
   param([parameter(Mandatory=$false,ValueFromPipeline=$true)] [String]$upn,
   [parameter(mandatory=$false,valueFromPipeline=$true)] [switch]$group)


}

# END GOOGLE admin functions 
function get-uptime{
   $res = Get-CimInstance -ClassName win32_operatingsystem 
   $res | Select-Object CSName,LastBootUpTime, @{Name="Uptime";Expression={"{0:dd}d:{0:hh}h:{0:mm}m:{0:ss}s" -f ((Get-Date) - $_.lastbootuptime)}}
}
function test-isElevated
{
    $id = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $p = New-Object System.Security.Principal.WindowsPrincipal($id)

    if ($p.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator))
    { 
        Write-Output $true 
    }      
    else
    { 
        Write-Output $false
    }   
}
function connect-exo{
   connect-exchangeonline
<# I switched to using the new module (exchangeonlinemanagement)
   Import-Module $((Get-ChildItem -Path $($env:LOCALAPPDATA+"\Apps\2.0\") -Filter Microsoft.Exchange.Management.ExoPowershellModule.dll -Recurse ).FullName|?{$_ -notmatch "_none_"}|select -First 1)
   $Session=New-ExoPSSession

   Import-PSSession $Session -Verbose -AllowClobber
#>

 }
#>
 #==============================
 function connect-spo {
   $orgName= "$global:tenandID"
   Connect-SPOService -Url https://$orgName-admin.sharepoint.com
 }
 #==============================
 function ldap-Lookup {
   <#
   .SYNOPSIS
   Use the .net accelerator ADSISearcher to search for a computer or user

   .DESCRIPTION
   This will perform an ldap query the primary domain controller and can be run as a
   unprivledged user from any domain joined computer.
   #>
    param([parameter(Mandatory=$true,ValueFromPipeline=$true)] [String]$lookup,
    [parameter(mandatory=$false,valueFromPipeline=$true)] [switch]$computer,
    [parameter(mandatory=$false,valueFromPipeline=$true)] [switch]$user)

    if ($computer) {
       write-output("searching for computer [$lookup]")
       (([ADSISearcher]"Name=$lookup").FindAll()).properties
    } #  END IF
    else{
    write-output("searching for user [$lookup]")
    (([ADSISearcher]"samaccountname=$lookup").FindAll()).properties
   } #  END ELSE
 }  #  END FUNCTION ldaplookup
 #===========================
 function delist-group {
   <#
   .SYNOPSIS
   take unified groups (o365) out of GAL (global address books)

   .DESCRIPTION
   Change $hiddenfromaddresslistenabled property of an office 365 group from $false to $true.
   This will prevent users from sending mail to the wrong group if the group is being used as a test or is for internal use.
   #>
   param([parameter(Mandatory=$true,ValueFromPipeline=$true)] [String]$group_name)
   $objID = (Get-UnifiedGroup -Identity $group_name).name
   set-unifiedgroup -identity "$objID" -HiddenFromAddressListsEnabled $true
   if($?){
   write-output("successfully hidden from Address Lists.`n")
   }
   else{
   write-output("ERROR: $lastexitcode")
   }
   $exchange_clients = read-host("do you want to hide from outlook and owa? Y/N")
   if($exchange_clients -eq "y"){set-unifiedgroup -identity "$objID" -HiddenFromExchangeClientsEnabled
   if($?){
   write-output("successfully hidden from Exchange Clients`n")
   }
   else{
   write-output("ERROR: $lastexitcode")
   }
   }
   else{
   return}
 }
 #==============================

function write-sha256sum {
   <#
   .SYNTAX
   write_sha256sum [-filename] <string> | write_sha256sum [-filename] <switch> [-nowrite]

   .REMARKS
   get sha256 hash of file and create file like $targetfile.txt or just write out the sha256sum
   author jwscott date 110719
   #>
   param([parameter(Mandatory=$true,ValueFromPipeline=$true)] [String]$filename,
   [parameter(Mandatory=$false,ValueFromPipeline=$true)] [String]$nowrite=$false)
   $hash = (Get-FileHash -Algorithm SHA256 $filename).hash
   if($nowrite -eq "$true"){
   Write-Output $hash
   return
   }
   $hash | out-file -filepath ./$filename.txt -NoNewline
   " " | add-content -path ./$filename.txt -NoNewline
   $filename | add-content -path ./$filename.txt -NoNewline
   Write-Output("wrote $filename.txt`n")
   cat ./$filename.txt
 }
 #==============================
 function get-pseudorandomString{
 param([parameter(mandatory=$false)]$len)

 <#
 .SYNTAX
 generate_psuedorandom_string

 .REMARKS
 write to stdout a psuedorandom string
 #>

 #set length of password to generate
   if ($len -eq $null){ $len = Get-Random -Minimum 8 -Maximum 28}
 ##33 - 126 are ascii code for noneblanks including special characters, "modulo" (is actually remainder in powershell) keeps the string positive
   $temp_passwd = write-output(-join ((33..126) * 256  | Get-Random -Count $len | % {[char]$_}))
   write-output($temp_passwd)
 }

 #===============================
 function send-mail(){
 param([parameter(Mandatory=$true,ValueFromPipeline=$true)] [String]$to,
 [parameter(Mandatory=$true,ValueFromPipeline=$true)] [String]$subject,
 [parameter(Mandatory=$false,ValueFromPipeline=$true)] [String]$body)
 if($body -eq ""){
   Send-MailMessage -To $to -From noreply@foo.com -Subject "$subject" -Body " " -SmtpServer $env:psemailServer -BodyAsHtml
   }
 else{
   Send-MailMessage -To $to -From noreply@foo.com -Subject "$subject" -Body "$body" -SmtpServer $env:psemailServer -BodyAsHtml
   }
 }
 #===============================
 function set-userAutoreply(){
 param([parameter(Mandatory=$true,ValueFromPipeline=$true)] [String]$user,
 [parameter(Mandatory=$true,ValueFromPipeline=$true)] [String]$externalmessage,
 [parameter(Mandatory=$true,ValueFromPipeline=$true)] [String]$internalmessage,
 [parameter(Mandatory=$true,ValueFromPipeline=$true)] [String]$state)
 Set-MailboxAutoReplyConfiguration -Identity $user -ExternalMessage $externalmessage -InternalMessage $internalmessage -AutoReplyState $state
 }
 #===============================
 function task-kill(){
 param([parameter(Mandatory=$true,ValueFromPipeline=$true)] [String]$task)
   taskkill.exe /im $task /f /t
 }
 #===============================
 function ip-lookup(){
    param([parameter(Mandatory=$true,ValueFromPipeline=$true)] [String]$ip)
    $payload = curl ipinfo.io/$ip/geo?token=$TOKEN
    $payload.content
 }
 #===============================
 function onedrive-check(){
    param([parameter(mandatory=$true,ValueFromPipeline=$true)] [string]$username)
    get-sposite -includepersonalsite $true -filter { url -like "$username"} -limit all
 }
 #===============================
 function time-lastCommand(){
   $command = Get-History -Count 1
   $command.EndExecutionTime - $command.StartExecutionTime
 }
 #===============================
 function encrypt-file(){
 param([parameter(Mandatory=$true,ValueFromPipeline=$true)] [String]$in,
 [parameter(Mandatory=$false,ValueFromPipeline=$true)][bool]$decrypt)
 switch ($decrypt) {
       $true {
         openssl aes-256-cbc -d -a -in "$in" -out "$in.dec"
     }
       Default {
         openssl.exe enc -aes-256-cbc -pbkdf2 -salt -base64 -in "$in" -out "$in.enc"
     }
   }
 }
 #===============================
 
 #===============================
 function open-WebDavSPO(){
 param([parameter(mandatory=$true,valuefrompipeline=$true)] [string]$site)
 push-location "\\foo.sharepoint.com@SSL\DavWWWRoot\sites\$site"
 }
 #===============================
 function start-RDP(){
    param([parameter(Mandatory=$true,ValueFromPipeline=$true)] [String]$destination,
    [parameter(Mandatory=$true,ValueFromPipeline=$true)] [switch]$shadow
    )
    switch ($shadow) {
       $true {qwinsta /server:$machinename
          $session = read-host -Prompt "select session"
          Start-Process  "$env:windir\system32\mstsc.exe" -ArgumentList "/v:$machinename /prompt /control /noConsentPrompt /shadow:$session"  }
       Default {Start-Process "$env:windir\system32\mstsc.exe" -ArgumentList "/v:$machinename"}
    }
 }
 #=================================
 # user deactivation
 ################################################################################
 #
 #
 #      __   ___  __      __   ___       __  ___             ___    __
 #|  | /__` |__  |__)    |  \ |__   /\  /  `  |  | \  /  /\   |  | /  \ |\ |
 #\__/ .__/ |___ |  \    |__/ |___ /~~\ \__,  |  |  \/  /~~\  |  | \__/ | \|
 #
 #
 #
 ###############################################################################
 function get-SignIns([string]$upn){
   if ($true -eq (get-module azureadpreview)){
      $upn = $upn.ToLower()
      write-host("Searching for signins from user:[$upn]") -ForegroundColor Yellow
      get-AzureADAuditSignInLogs -Filter "userPrincipalName eq '$upn'" -All:$true
   }  #  END IF
   else{
      write-host("You must connect to azure ad with azureadpreview\connect-azuread before calling get-azureadauditsigninlogs.`nAttempting to load it automatically.") -ForegroundColor Red
      get-module azuread | remove-module
      azureadpreview\connect-azuread
      if(get-module azureadpreview){get-signins $upn}
      else{write-host("Could not load azureadpreview")}
   }  #  END  ELSE
 } #  END  FUNCTION  get-SignIns
 #================================
 function revoke-AzureTokens(){
   param([parameter(Mandatory=$true,valuefrompipeline=$true)] [string]$upn)
   write-output("Getting original token refresh date...")
   write-output((get-azureaduser -searchstring $upn).RefreshTokensValidFromDateTime)
   write-output("Revoking refresh tokens for [$upn]...")
   Revoke-AzureADUserAllRefreshToken -ObjectId ((Get-AzureADUser -SearchString $upn).objectId)
   write-output("Exit status:`t$LastExitCode")
   write-output("Getting new token refresh date...")
   write-output((get-azureaduser -searchstring $upn).RefreshTokensValidFromDateTime)
 }
 #================================
 function block-AzureSignins(){
   param([parameter(Mandatory=$true,valuefrompipeline=$true)] [string]$username,
   [parameter(Mandatory=$false,ValueFromPipeline=$true)] [bool]$unlock)

   if ($unlock -eq $true){
     write-output("User [$username] account enabled:")
     write-output((get-azureaduser -ObjectId "$upn").accountenabled)
     write-output("allowing azure sign-ins for [$username]...")
     Set-AzureADUser -ObjectID $upn -AccountEnabled $true
     write-output("User [$username] account enabled:")
     write-output((get-azureaduser -ObjectId "$upn").accountenabled)
   }
   else{
     write-output("User [$username] account enabled:")
     write-output((get-azureaduser -ObjectId "$upn").accountenabled)
     write-output("Blocking azure sign-ins for [$username]...")
     Set-AzureADUser -ObjectID "$upn" -AccountEnabled $false
     write-output("User [$username] account enabled:")
     write-output((get-azureaduser -ObjectId "$upn").accountenabled)
   }
 }
 #==============================
 function deactive-user {
 <#
 .SYNTAX
 deactivate_user [-user] $string
 .REMARKS
 requires conenction to exo and AzureAD
 #>
 param([parameter(Mandatory=$true,ValueFromPipeline=$true)] [String]$user)
 #    try {
     Revoke-AzureADUserAllRefreshToken -ObjectId (Get-AzureADUser -SearchString $user).objectId -ErrorAction Stop
     Set-Mailbox $user_upn -AccountDisabled:$true
     generate_psuedorandom_string
     $newpwd = ConvertTo-SecureString -String "$temp_passwd" -AsPlainText -Force
     Set-ADAccountPassword $user -NewPassword $newpwd -Reset
 }
 ################################################################################
 #
 # ___       __           __   ___  __      __   ___       __  ___             ___    __
 #|__  |\ | |  \    |  | /__` |__  |__)    |  \ |__   /\  /  `  |  | \  /  /\   |  | /  \ |\ |
 #|___ | \| |__/    \__/ .__/ |___ |  \    |__/ |___ /~~\ \__,  |  |  \/  /~~\  |  | \__/ | \|
 #
 #
 ###############################################################################
 #================================
 function reload-Profile(){

 # Using invoke operator
   & $PROFILE

 # Using dot sourcing
   .$PROFILE
 }
 #================================
 function get-Accelerators(){
    [psobject].Assembly.GetType("System.Management.Automation.TypeAccelerators")::Get
 }
 #================================
 function add-ToProfile(){
    param([parameter(Mandatory=$true,ValueFromPipeline=$true)] [String]$TextToAdd)
    Add-Type -AssemblyName PresentationFramework
    $confirm = [System.Windows.MessageBox]::Show('Are you sure you want to make a change to your profile?`nThe last version of your profile will be saved as [$profile`.old]', 'Confirmation', 'YesNo');
    switch ($confirm) {
       "Yes" {
          Write-Output("making a backup of the powershell profile")
          copy-item "$profile" "$profile`.old"
          "`n#================================" | Add-Content $profile
          $TextToAdd | add-content $profile
          "#================================" | Add-Content $profile
       if(cat $profile | findstr.exe $TextToAdd) {
          write-output("Text was added successfully")
       } #   END IF
       else{
          write-host("ERROR:`tTEXT NOT ADDED SUCCESFULLY") -ForegroundColor red
       }
    }  #  END   yes CASE
       Default {write-output("No changes made to [$profile]")}
    }  #  END   switch
 }
 #================================
 #================================
 function Test-WMI(){
    param([parameter(Mandatory=$true,ValueFromPipeline=$true)] $workstations, [Parameter(Mandatory=$true)] [string]$user)
    foreach($workstation in $workstations){
       wmic /node:$workstation /user:"$workstation\$user"  baseboard
    }
 }
 #================================
 function convertTo-ASCIIArt{
    # invoke-restmethod https://artii.herokuapp.com/fonts_list
  Param(
         [Parameter(Position = 0, Mandatory, HelpMessage = "Enter a short string of text to convert", ValueFromPipeline)]
         [ValidateNotNullOrEmpty()]
         [string]$Text,
         [Parameter(Position = 1,HelpMessage = "Specify a font from https://artii.herokuapp.com/fonts_list. Font names are case-sensitive")]
         [ValidateNotNullOrEmpty()]
         [string]$Font = "big",
         [switch]$listFonts
     )

     Begin {
         Write-Verbose "[$((Get-Date).TimeofDay) BEGIN] Starting $($myinvocation.mycommand)"
         
     switch ($listfonts) {
      true {(invoke-webrequest artii.herokuapp.com/fonts_list).content }
      Default {}
   }
     } #begin

     Process {
         Write-Verbose "[$((Get-Date).TimeofDay) PROCESS] Processing $text with font $Font"
         $testEncode = [uri]::EscapeDataString($Text)
         $url = "http://artii.herokuapp.com/make?text=$testEncode&font=$Font"
         Try {
             Invoke-Restmethod -Uri $url -DisableKeepAlive -ErrorAction Stop
         }
         Catch {
             Throw $_
         }
     } #process
     End {
         Write-Verbose "[$((Get-Date).TimeofDay) END    ] Ending $($myinvocation.mycommand)"
     } #end
 }  #  END   FUNCTION convertToASCIIArt
 #================================
 function create-DummyFile(){
      param([parameter(Mandatory=$true,ValueFromPipeline=$true)] $fileName,
      [parameter(Mandatory=$false,ValueFromPipeline=$true)] $fileSize = "2146435072")

      Write-Host "Creating files..."
      for ($i = 1; $i -le $fileCount; $i++) {
         $outputFileName = "$fileName.$i"
         Write-Host "Writing $outputFileName ($i/$fileCount)"

         $file = [System.IO.File]::Create($outputFileName)
         $file.SetLength($fileSize)
         $file.Close()
      Write-Host "Done!"
   }
 } # END FUNCTION createDummyFile

 #================================
 function console-Beep(){
   param([parameter(Mandatory=$false,ValueFromPipeline=$true)] $pitch = 440,
       [parameter(Mandatory=$false,ValueFromPipeline=$true)] $length =300)
   [console]::beep($pitch,$length)
   } # END FUNCTION  consoleBeep
 #================================
 function get-OU{
    param([parameter(mandatory=$true,valuefrompipeline=$true)]$user)

    $user = get-azureaduser -searchstring $user
    $output = [PSCustomObject][ordered]@{
         username = write-output(($user).mailnickname)
         DistinguishedOU = (((Get-AzureADUserExtension -ObjectId    ($user).objectid).onPremisesDistinguishedName))
    } # END array
    echo($output)
 }   #   END   FUNCTION getOU
 #================================

 #================================
 function get-Weather(){
    invoke-restMethod http://wttr.in/new+concord
    }   #   END   FUNCTION getWeather
 #================================

 #================================
 function start-Project(){
    invoke-plaster -templatePath "C:\Program Files\WindowsPowerShell\Modules\plaster\1.1.3\Templates\SubSystem"
 }   #   END   FUNCTION startMUProject
 #================================

 #================================
 function execute-RemotePowershellScript(){
    param([parameter(mandatory=$true,valuefrompipeline=$true)]$remoteHost,
    [parameter(mandatory=$true,ValueFromPipeline=$true)]$remotePath)
    <#
    .REMARKS
    requires that PSEXEC binary be located at C:\program files
    #>
    write-host("Executing powershell script at [$remotePath] on host[$remoteHost]") -ForegroundColor yellow
    C:\Program Files\PsExec.exe \\$remoteHost -d -s cmd /c "powershell.exe -f $remotePath"
 }  #  END   FUNCTION executeRemotePowershellScript
 #================================

 #================================
 function update-UserPhoto(){
    param([parameter(mandatory=$true,valuefrompipeline=$true)]$user,
    [parameter(mandatory=$false,ValueFromPipeline=$true)]$pathToPicture,
    [parameter(mandatory=$false,valueFrompipeline=$true)][switch]$remove)

   switch($remove){
       True{
          write-host("removing photo for user:[$user]")
          remove-userphoto -identity $user
       }
       default{
       write-host("changing photo for user:[$user]")
       Set-UserPhoto -Identity $user -PictureData ([System.IO.File]::ReadAllBytes("$pathToPicture"))
       }
   }   # END SWITCH

 } # END FUNCTION updateUserphoto

 function get-mfaUsers(){
   Get-AzureADGroupMember -all $true -ObjectId (Get-AzureADGroup -SearchString "MFAUsers").objectid | select displayname,UserPrincipalName
 }  #   END   FUNCTION   get-mfaUsers

 function check-sha256(){
    param([parameter(mandatory=$true,valuefrompipeline=$true)]$inputpath)
    $misMatchCount = 0
    $checksums = import-csv -header algo,hash,path -path $inputpath
    foreach($checksum in ($checksums | select-object -skip 1)){
    if ((get-filehash -algorithm $checksum.algo -path $checksum.path).hash -eq $checksum.hash){
      }
    else{
      write-host("ALERT: [$checksum] MISMATCH") -foregroundcolor red
      $mismatchCount = $mismatchCount + 1
      }
    } # END FOREACH
    if($mismatchcount -gt 0){
    write-host("WARNING: there are [$mismatchcount] file(s) with hashes different than expected. File integrity cannot be assured") -foregroundcolor red
    }
    else{
    write-host("All files matched provided checksums. Please ensure that the signature file was signed with an expected key") -foregroundcolor green
    gpg --verify "$inputPath`.sig"
    }
 }  #  END   FUNCTION check-sha256

 function show-exampleDISMCommands{
    $infoStr = @"
[1]    Burn an winPE image to a liveUSB: 
    MakeWinPEMedia /UFD G:\windowsImaging\WinPE_amd64 D:

[2]   unmount and commit an image:
    dism /unmount-image /mountDir:G:\mountpoint\ /commit

[3]    Mount an image to the local filesystem:
    dism /mount-wim /wimfile:"G:\windowsimaging\WinPE_amd64\media\sources\boot.wim" /index:1 /mountdir:"G:\mountpoint\"
"@
   write-output("$infoStr")
   $choice = read-host
   switch ($choice) {
      1 { write-output ("#MakeWinPEMedia /UFD G:\windowsImaging\WinPE_amd64 D:")|clip; echo("coppied to clipboard") }


      2 { write-output ("#dism /unmount-image /mountDir:G:\mountpoint\ /commit") | clip ; echo("coppied to clipboard") }


      3 { write-output ("#dism /mount-wim /wimfile:`"G:\windowsimaging\WinPE_amd64\media\sources\boot.wim`" /index:1 /mountdir:`"G:\mountpoint\`"") | clip ; echo("coppied to clipboard") }

      Default {}
   }  #  END   SWITCH
 }   #   END   FUNCTION show-exampleDISMCommands

function Create-PesterBlocksModule {
param([parameter(mandatory=$true,valuefrompipeline=$true)]$Module)
if((get-module).name -notcontains "$module"){
   import-module $module
}   #   END   IF
foreach($cmdlet in (get-command -Module $module).name){
   Echo @"
   Describe "$cmdlet" {
      context "foo foo" {
         BeforeAll {     
            mock foo foo foo
         }   #   END   MOCK
         it "does something" {
         }   #   END   IT "does something"
      }   #   END   CONTEXT "foo foo"     
   }   #   END   DESCRIBE $cmdlet         
"@                                     
   }   #   END   FOREACH                                       
}   #   END   FUNCTION Create-PesterBlocksModule
#================================
<# this was just a test for PSExec 
function eject-opticalDrive {
   param([parameter(mandatory=$false,valuefrompipeline=$true)]$remoteHost)
   if($null -ne $remoteHost){
      (C:\cns\PsExec.exe \\$remoteHost -d -s cmd /c "powershell.exe -command {(New-Object -com 'WMPlayer.OCX.7').cdromcollection.item(0).eject()}")
   }
   else{
      (New-Object -com "WMPlayer.OCX.7").cdromcollection.item(0).eject()
   }
}
#>
#================================
 function start-tftpd {
    param(
    [Parameter(Mandatory=$false)]
    $rootDir = "C:\temp")
    Write-Output("starting TFTP server...")
    Invoke-Command {C:\Strawberry\perl\bin\perl.exe  "c:\program files\TFTPD\tftpd-simple.pl" -4 -d "$rootDir"}
 } #  END   FUNCTION start-tftpd
#================================
function start-sshOLD {
   param(
      [Parameter(Mandatory=$true)]
      $ip)
      ssh -o KexAlgorithms=diffie-helleman-group14-sha1 -o Ciphers=3des-cbc "manager@$ip"
}
#================================
function lookup-Switch {
    param(
         [parameter(mandatory=$true)]$switch)
    $switches | ? {$_.devicelabel -match "$switch"}
}
#================================
function rsync-files ($source,$target) {

  $sourceFiles = Get-ChildItem -Path $source -Recurse
  $targetFiles = Get-ChildItem -Path $target -Recurse

  if ($debug -eq $true) {
    Write-Output "Source=$source, Target=$target"
    Write-Output "sourcefiles = $sourceFiles TargetFiles = $targetFiles"
  }
  <#
  1=way sync, 2=2 way sync.
  #>
  $syncMode = 1

  if ($sourceFiles -eq $null -or $targetFiles -eq $null) {
    Write-Host "Empty Directory encountered. Skipping file Copy."
  } else
  {
    $diff = Compare-Object -ReferenceObject $sourceFiles -DifferenceObject $targetFiles

    foreach ($f in $diff) {
      if ($f.SideIndicator -eq "<=") {
        $fullSourceObject = $f.InputObject.FullName
        $fullTargetObject = $f.InputObject.FullName.Replace($source,$target)

        Write-Host "Attempt to copy the following: " $fullSourceObject
        Copy-Item -Path $fullSourceObject -Destination $fullTargetObject
      }


      if ($f.SideIndicator -eq "=>" -and $syncMode -eq 2) {
        $fullSourceObject = $f.InputObject.FullName
        $fullTargetObject = $f.InputObject.FullName.Replace($target,$source)

        Write-Host "Attempt to copy the following: " $fullSourceObject
        Copy-Item -Path $fullSourceObject -Destination $fullTargetObject
      }

    }
  }
}
#================================
function Generate-Doc(){
    param(
    [Parameter(Mandatory=$false)]
    $outputPath = ".")
   invoke-plaster -TemplatePath "C:\program files\WindowsPowerShell\Modules\Plaster\1.1.3\Templates\documentationTemplate" -DestinationPath $outputPath 
}

#================================
#================================
function get-processByIP(){
   <#
      .SYNOPSIS
      This command will get active TCP connections to and from the local PC then search for connections that match the provided Remote IP Address.  
      .DESCRIPTION
      Currently this function will list all active TCP connections that match the remote IP address provided and give the option to stop each process.
      The user is prompted to confirm before any process is closed. If there is more than one remote connection, the function will prompt for each connection.
      .EXAMPLE
      get-processByIP -remoteIP 192.168.80.4
   #>

  param(
  [Parameter(Mandatory=$false)]
  $remoteIP) 

  $netConns = Get-NetTCPConnection
  $selectedConns = $netConns | ? {$_.remoteaddress -match "$remoteIP"}
  $selectedConnsProcs = ($selectedConns).owningprocess

  if ((read-host "stop [($selectedConns)]? Y/N") -eq "y"){
    $selectedConnsProcs = @()
    $selectedConnsProcs = ($selectedConns).owningprocess
    foreach ($proc in $selectedConnsProcs){
      write-host -ForegroundColor Yellow "Stopping [$proc]"
      stop-process -Id $proc -Confirm -PassThru
    }
  }
}
function ConvertFrom-HTMLTable {
    # https://github.com/ztrhgf/useful_powershell_functions/blob/master/ConvertFrom-HTMLTable.ps1
    <#
    .SYNOPSIS
    Function for converting ComObject HTML object to common PowerShell object.

    .DESCRIPTION
    Function for converting ComObject HTML object to common PowerShell object.
    ComObject can be retrieved by (Invoke-WebRequest).parsedHtml or IHTMLDocument2_write methods.

    In case table is missing column names and number of columns is:
    - 2
        - Value in the first column will be used as object property 'Name'. Value in the second column will be therefore 'Value' of such property.
    - more than 2
        - Column names will be numbers starting from 1.

    .PARAMETER table
    ComObject representing HTML table.

    .PARAMETER tableName
    (optional) Name of the table.
    Will be added as TableName property to new PowerShell object.

    .EXAMPLE
    $pageContent = Invoke-WebRequest -Method GET -Headers $Headers -Uri "https://docs.microsoft.com/en-us/mem/configmgr/core/plan-design/hierarchy/log-files"
    $table = $pageContent.ParsedHtml.getElementsByTagName('table')[0]
    $tableContent = @(ConvertFrom-HTMLTable $table)

    Will receive web page content >> filter out first table on that page >> convert it to PSObject

    .EXAMPLE
    $Source = Get-Content "C:\Users\Public\Documents\MDMDiagnostics\MDMDiagReport.html" -Raw
    $HTML = New-Object -Com "HTMLFile"
    $HTML.IHTMLDocument2_write($Source)
    $HTML.body.getElementsByTagName('table') | % {
        ConvertFrom-HTMLTable $_
    }

    Will get web page content from stored html file >> filter out all html tables from that page >> convert them to PSObjects
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [System.__ComObject] $table,

        [string] $tableName
    )

    $twoColumnsWithoutName = 0

    if ($tableName) { $tableNameTxt = "'$tableName'" }

    $columnName = $table.getElementsByTagName("th") | % { $_.innerText -replace "^\s*|\s*$" }

    if (!$columnName) {
        $numberOfColumns = @($table.getElementsByTagName("tr")[0].getElementsByTagName("td")).count
        if ($numberOfColumns -eq 2) {
            ++$twoColumnsWithoutName
            Write-Verbose "Table $tableNameTxt has two columns without column names. Resultant object will use first column as objects property 'Name' and second as 'Value'"
        } elseif ($numberOfColumns) {
            Write-Warning "Table $tableNameTxt doesn't contain column names, numbers will be used instead"
            $columnName = 1..$numberOfColumns
        } else {
            throw "Table $tableNameTxt doesn't contain column names and summarization of columns failed"
        }
    }

    if ($twoColumnsWithoutName) {
        # table has two columns without names
        $property = [ordered]@{ }

        $table.getElementsByTagName("tr") | % {
            # read table per row and return object
            $columnValue = $_.getElementsByTagName("td") | % { $_.innerText -replace "^\s*|\s*$" }
            if ($columnValue) {
                # use first column value as object property 'Name' and second as a 'Value'
                $property.($columnValue[0]) = $columnValue[1]
            } else {
                # row doesn't contain <td>
            }
        }
        if ($tableName) {
            $property.TableName = $tableName
        }

        New-Object -TypeName PSObject -Property $property
    } else {
        # table doesn't have two columns or they are named
        $table.getElementsByTagName("tr") | % {
            # read table per row and return object
            $columnValue = $_.getElementsByTagName("td") | % { $_.innerText -replace "^\s*|\s*$" }
            if ($columnValue) {
                $property = [ordered]@{ }
                $i = 0
                $columnName | % {
                    $property.$_ = $columnValue[$i]
                    ++$i
                }
                if ($tableName) {
                    $property.TableName = $tableName
                }

                New-Object -TypeName PSObject -Property $property
            } else {
                # row doesn't contain <td>, its probably row with column names
            }
        }
    }
}

#================================
function ask-cgpt {
   param (
      # type your question here 
      [Parameter(Mandatory=$true)]
      [string]
      $CompletionQuery
   )
   $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Content-Type", "application/json")
$headers.Add("Authorization", "Bearer $cgptToken")

$body = @"
{
  `"model`": `"text-davinci-003`",
  `"prompt`": `"$completionQuery`",
  `"max_tokens`": 250,
  `"temperature`": 0.7
}
"@

$response = Invoke-RestMethod 'https://api.openai.com/v1/completions' -Method 'POST' -Headers $headers -Body $body
(($response).choices).text | ConvertTo-Json
}
#================================
function generate-selfSignedCert {
   param (
       $certDomains = @('DEVSERVER', 'DEVSERVER.local'),
       $certFriendlyName = "Test Self-Signed Cert",
       $certFileName = "TestCert.cer",
       $certIPAddresses = @('192.168.2.3'))

<#	
 .SYNOPSIS 
   Creates a basic self-signed certificate that for the specified host names.
 .DESCRIPTION
   Creates a basic self-signed certificate that for the specified host names.  
 .NOTES

   Modified from original sample script by: 

   Author: jpann@impostr-labs.com
   Filename: Create-SelfSignedCertBasic.ps1
   Created on: 03-15-2022
   Version: 1.0
   Last updated: 03-15-2022
#>

if (-not(test-isElevated))
{
   throw "Please run this script as an administrator" 
}

Write-Host "Creating self-signed certificate called '$certFriendlyName' in LocalMachine\Personal store..." 
$params = @{
 DnsName = $certDomains
 Subject = $certFriendlyName
 FriendlyName = $certFriendlyName
 KeyLength = 4096
 KeyAlgorithm = 'RSA'
 HashAlgorithm = 'SHA256'
 KeyExportPolicy = 'Exportable'
 NotAfter = (Get-Date).AddYears(15)
 CertStoreLocation = "Cert:\LocalMachine\My"
}
$continue = $true
while($continue){
$edit = read-host -Prompt "would you like ot change anything? [y/n]"
   if ($edit -ne "n"){
       notepad ./defaultCert.config 
       $params = gc './defaultCert.config'
   }
   else{
       $continue = $false
   }
}
$continue = $true
$cert = New-SelfSignedCertificate @params
 
# Export certificate to disk in the current user's home directory
if ($PSScriptRoot -ne $HOME)
{
   cd $HOME;
}

$certFileName = Join-Path $HOME $certFileName

Write-Host "Exporting certificate to '$certFileName'..."
Export-Certificate -Cert $cert -FilePath "$certFileName" -Type CERT

Write-Host "Importing certificate into local Trusted Root Certification Authorities..."
Import-Certificate -FilePath "$certFileName" -CertStoreLocation Cert:\LocalMachine\Root
}

#================================

function generate-selfSignedROOTCA{
   $rootCAParams = @{}
   $rootCAParams = @{
   FriendlyName = "JWS Test Root CA Cert"
   DnsName = "JWS Test Root CA Cert"
   Subject = "CN=JWSRootCA,O=JWSRootCA,OU=JWSRootCA"
   KeyLength = 4096
   KeyAlgorithm = 'RSA'
   HashAlgorithm = 'SHA256'
   KeyExportPolicy = 'Exportable'
   KeyUsage = 'CertSign','CRLSign','DigitalSignature'
   KeyUsageProperty = 'All'
   NotAfter = (Get-Date).AddYears(15)
   Provider = 'Microsoft Enhanced RSA and AES Cryptographic Provider'
   CertStoreLocation = "Cert:\LocalMachine\My"
   }

$rootCACert = New-SelfSignedCertificate @rootCAParams
# We need to the thumbprint of the Root CA Certificate in order to export the private key
$rootCAThumbprint = $rootCACert.Thumbprint

# Set the password that will be used for the Root CA Certificate's private key
$myPword = read-host -prompt "enter a password for the certificate: "
$rootCACertPassword = ConvertTo-SecureString -String "$myPword" -Force -AsPlainText
$exportParams =@{
   cert = 'Cert:\LocalMachine\My\' + $rootCAThumbprint
   FilePath = 'JWSRootCACert.pfx'
   password = $rootCACertPassword
}
Export-PfxCertificate @exportParams



# Export the Root CA Certificate's public key
Export-Certificate -Cert $rootCACert -FilePath 'JWSRootCACert.cer' -Type CERT
}
#================================
function ssh-copyID($user,$server) {
   write-host("copying ~/.ssh/id_rsa.pub to $user`@$server`:~/.ssh/authorized_keys")
   $check = read-host -Prompt "Upload? y/n"
   if($check -eq "y"){
   cat ~/.ssh/id_rsa.pub | ssh "$user`@$server" "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
   }
   else {
      write-host("Exiting.")
      return 
   }
}

#================================
#
# Export only the functions using PowerShell standard verb-noun naming.
# Be sure to list each exported functions in the FunctionsToExport field of the module manifest file.
# This improves performance of command discovery in PowerShell.
Export-ModuleMember -Function *-*
