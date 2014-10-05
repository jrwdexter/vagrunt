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

function Get-Gitignore{
  param(
    [System.IO.DirectoryInfo]
    $CurrentDirectory
  )
  if($CurrentDirectory -ne $null) {
    if(Test-Path ("$CurrentDirectory\.gitignore"))
    {
      return "$CurrentDirectory\.gitignore"
    }

    Get-Gitignore $CurrentDirectory.Parent
  }
}

#######################
###### EXECUTION ######
#######################

Write-Progress -Activity "Installing Vagrunt" -Status "Testing for existing vagrunt" -PercentComplete 0
if(Test-Path "vagrunt.ps1") {
  Write-Host "It appears that vagrunt is already installed."
  Write-Host -NoNewLine "Forcefully continue anyway? [y/N] "
  $answer = Read-Host
  if($answer -notmatch "y") {
    return
  }
}
Write-Progress -Activity "Installing Vagrunt" -Status "Testing for 'build.sh'" -PercentComplete 5
if(-not (Test-Path "./build.sh")) {
  Write-Host "It appears there is no build.sh in this directory."
  Write-Host -NoNewLine "Are you sure you want to install Vagrunt? [y/N] "
  $answer = Read-Host
  if($answer -notmatch "y")
  {
    return
  }
}

# Download
Write-Progress -Activity "Installing Vagrunt" -Status "Downloading Files" -PercentComplete 20
$zipFile = "$($env:TEMP)\vagrunt.zip"
Download-File -Url "https://github.com/mandest/vagrunt/archive/master.zip" -File $zipFile

# Unzip
Write-Progress -Activity "Installing Vagrunt" -Status "Unpacking Files" -PercentComplete 50
$tempPath = "$($env:TEMP)\vagrunt"
if(Test-Path $tempPath) {
  $null = Remove-Item -Recurse -Force $tempPath
}
$null = New-Item -Type Directory $tempPath
Extract-File -File $zipFile -OutputDirectory $tempPath

# Copy
Write-Progress -Activity "Installing Vagrunt" -Status "Copying Files" -PercentComplete 70
Get-ChildItem "$tempPath\vagrunt-master" | ? { 
  $ignoredFiles -notcontains $_.Name
} | % {
  Copy-Item $_.FullName "./$($_.Name)"
}

# Update .gitignore
Write-Progress -Activity "Installing Vagrunt" -Status "Updating .gitignore if present" -PercentComplete 80
$gitignore = Get-Gitignore -CurrentDirectory "."
if($gitignore -ne $null) {
  "`n# Vagrunt" | Out-File -Append $gitignore
  if((Get-Content $gitignore | ? {$_ -match "/puppet/modules/"}).Length -eq 0) {
    "**/puppet/modules/" | Out-File -Append $gitignore
  }
  if((Get-Content $gitignore | ? {$_ -match ".vagrant"}).Length -eq 0) {
    ".vagrant" | Out-File -Append $gitignore
  }
}

# Cleanup
Write-Progress -Activity "Installing Vagrunt" -Status "Cleaning Up" -PercentComplete 90
$null = Remove-Item -Recurse -Force $zipFile
$null = Remove-Item -Recurse -Force $tempPath

# Notify
Write-Host ""
Write-Host -ForegroundColor Cyan "Finished!"
Write-Host "Use ./vagrunt.ps1 to run vagrunt.  Happy grunting!"
Write-Host ""
