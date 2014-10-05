#######################
####### GLOBALS #######
#######################
$rootUrl = "https://github.com/mandest/vagrunt/master.zip"
$downloader = New-Object System.Net.WebClient
$ignoredFiles = @(
  "./LICENSE",
  "./README.md",
  "./install.ps1",
  "./.gitignore"
)

#######################
###### FUNCTIONS ######
#######################

function Download-File {
  param (
    [string]$Url,
    [string]$File
   )

  $downloader.DownloadFile($Url, $File)
}

function Extract-File {
  param (
    [string]$File,
    [string]$OutputDirectory
  )
  $shell = new-object -com shell.application
  $zip = $shell.NameSpace($File)
  foreach($item in $zip.items())
  {
    Write-Host $item
    $shell.Namespace($OutputDirectory).CopyHere($item)
  }
}

#######################
###### EXECUTION ######
#######################

Write-Progress -Activity "Installing Vagrunt" -Status "Testing for 'build.sh'" -PercentComplete 0
if(-not (Test-Path "./build.sh"))
{
  Write-Host "It appears there is no build.sh in this directory."
  Write-Host "Are you sure you want to install Vagrunt? [y/N]"
  $answer = Read-Host
  if($answer -notmatch "y")
  {
    return
  }
}

# download the package
Write-Progress -Activity "Installing Vagrunt" -Status "Downloading Files" -PercentComplete 20
$file = "$($env:TEMP)/$File"
Download-File -Url "https://github.com/mandest/vagrunt/master.zip" -File $file

Write-Progress -Activity "Installing Vagrunt" -Status "Unpacking Files" -PercentComplete 70
Extract-File -File $file -OutputDirectory "./"

Write-Host -ForegroundColor "Finished!"
Write-Host "Use ./vagrunt.ps1 to run vagrunt.  Happy grunting!"
Write-Host ""
