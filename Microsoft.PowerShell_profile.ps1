###############################################################################
#
# __   __        ___    __        __       ___    __
#/  ` /  \ |\ | |__  | / _` |  | |__)  /\   |  | /  \ |\ |
#\__, \__/ | \| |    | \__> \__/ |  \ /~~\  |  | \__/ | \|
#
#
###############################################################################

#==============================
#trim how much path shows

function prompt {
  $p1 = Split-Path -leaf -path (Get-Location)
  $p2 = get-date -Format HHmmss
  "$p1 $p2> "
}
#==============================
$confFilePath = "$home\documents\windowsPowershell\conf\config.json"
write-host("loading conf")
$_conf =  get-content $confFilePath | out-string | ConvertFrom-Json

#$cgptToken = gc "~/secrets/cgpt" 
#==============================

# store tenant ID as global
#$global:tenant_id = ""
#==============================
# regex to match MAC
$macRegex = '\b([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})\b'
#==============================
# Set vi as alias for vim
New-Alias -Name vi -Value vim.exe
#==============================
# VI-like command line # escape key for command mode
# https://docs.microsoft.com/en-us/powershell/module/psreadline/about/about_psreadline?view=powershell-7.1
set-PSReadlineOption -EditMode vi
#==============================
# set vim as the editor
$env:editor = "vim.exe"
$env:visual = "vim.exe"
#==============================
$profileModulePath = '~\Documents\WindowsPowerShell\PoShMod\profileModule.psm1'
#==============================
#import-module plaster
#import-module pester -Minimum 5.1.1
import-module importexcel
import-module ps2exe
import-module convertfrommarkdown
import-module "$profileModulePath" -DisableNameChecking
#==============================

#==============================
function reload-profileModule(){
  write-host("reloading profile module") -foregroundcolor yellow
  import-module "$profileModulePath" -disableNameChecking -Force
} # END FUNCTION  reload-profileModule
#==============================
function edit-profileModule([switch]$vimMode){
   switch ($vimMode) {
      $true {vim "$profileModulePath"}
      Default {code "$profileModulePath"}
   }
} # END FUNCTION  edit-profileModule
#===============================
#		!!!
# this is for the pre-graph EXOL module
# 		!!!
<#
function connect-exo{

   Import-Module $((Get-ChildItem -Path $($env:LOCALAPPDATA+"\Apps\2.0\") -Filter Microsoft.Exchange.Management.ExoPowershellModule.dll -Recurse ).FullName|?{$_ -notmatch "_none_"}|select -First 1)

   $Session=New-ExoPSSession

   Import-PSSession $Session -Verbose -AllowClobber
 }
#>
#===============================
#	Random useful things
#===============================
# EICAR virus test string
$PSEICARString = ''
# hosts file on windows OS
$env:hostsFile = "C:\windows\system32\drivers\etc\hosts"
#  new-item -ItemType SymbolicLink .\Microsoft.PowerShell_profile.ps1 -Target .\PoShMod\Microsoft.PowerShell_profile.ps1
