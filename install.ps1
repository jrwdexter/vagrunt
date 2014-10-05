#######################
####### GLOBALS #######
#######################
$rootUrl = "https://github.com/mandest/vagrunt/master.zip"
$downloader = New-Object System.Net.WebClient
$ignoredFiles = @(
  "LICENSE",
  "README.md",
  "install.ps1",
  ".gitignore"
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
  $zip = $shell.Namespace($File)
  foreach($item in $zip.items())
  {
    $null = $shell.Namespace($OutputDirectory).CopyHere($item)
  }
}

#######################
###### EXECUTION ######
#######################

Write-Progress -Activity "Installing Vagrunt" -Status "Testing for 'build.sh'" -PercentComplete 0
if(Test-Path "vagrunt.ps1")
{
  Write-Host "It appears that vagrunt is already installed."
  Write-Host -NoNewLine "Forcefully continue anyway? [y/N] "
  $answer = Read-Host
  if($answer -notmatch "y")
  {
    return
  }
}
if(-not (Test-Path "./build.sh"))
{
  Write-Host "It appears there is no build.sh in this directory."
  Write-Host -NoNewLine "Are you sure you want to install Vagrunt? [y/N] "
  $answer = Read-Host
  if($answer -notmatch "y")
  {
    return
  }
}

# download the package
Write-Progress -Activity "Installing Vagrunt" -Status "Downloading Files" -PercentComplete 20
$zipFile = "$($env:TEMP)\vagrunt.zip"
Download-File -Url "https://github.com/mandest/vagrunt/archive/master.zip" -File $zipFile

Write-Progress -Activity "Installing Vagrunt" -Status "Unpacking Files" -PercentComplete 50
$tempPath = "$($env:TEMP)\vagrunt"
if(Test-Path $tempPath)
{
  $null = Remove-Item -Recurse -Force $tempPath
}
$null = New-Item -Type Directory $tempPath
Extract-File -File $zipFile -OutputDirectory $tempPath

Write-Progress -Activity "Installing Vagrunt" -Status "Copying Files" -PercentComplete 70
Get-ChildItem "$tempPath\vagrunt-master" | ? { 
  $ignoredFiles -notcontains $_.Name
} | % {
  Copy-Item $_.FullName "./$($_.Name)"
}

Write-Progress -Activity "Installing Vagrunt" -Status "Cleaning Up" -PercentComplete 90
$null = Remove-Item -Recurse -Force $zipFile
$null = Remove-Item -Recurse -Force $tempPath

Write-Host ""
Write-Host -ForegroundColor Cyan "Finished!"
Write-Host "Use ./vagrunt.ps1 to run vagrunt.  Happy grunting!"
Write-Host ""
