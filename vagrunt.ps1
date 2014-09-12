param(
    [String]$Command,
    [Switch]$StayOn
)

#################
### FUNCTIONS ###
#################

$installingDependancies = "Detecting and installing dependencies"

function Check-Hypervisor() {
    $bcdInfo = bcdedit /enum
    $currentLineIndex = [array]::IndexOf($bcdInfo, ($bcdInfo | ? { $_ -match "identifier.*current" }))
    $currentName = ($bcdInfo[$currentLineIndex..$bcdInfo.Length] | ? {$_ -match "description" }) -replace "^description\s*",""
    $hypervisorLaunchType = ($bcdInfo[$currentLineIndex..$bcdInfo.Length] | ? {$_ -match "hypervisorlaunchtype" }) -replace "^hypervisorlaunchtype\s*",""
    if($hypervisorlaunchtype -notmatch "^[Oo]ff") {
        Write-Host "Hyper-V is enabled.  Would you like this script to add a new boot entry with Hyper-V disabled? [y/N]"
        $key = Get-Content
        if($key -eq "y" -or $key -eq "Y") {
            Write-Host "Adding new boot entry for disabled Hyper-V."
            Write-Host "What would you like to name the new boot entry? Your current boot entry is named $currentName. [Default: $currentName (No Hyper-V)]"
            $newName = Get-Content
            if($newName -eq $null -or $newName -match "^\s*$") {
                $newName = "$currentName (No Hyper-V)"
            }

            $result = bcdedit /copy `{current`} /d $newName
            $newGuid = $result -replace "^.*(\{[^{}]*\}).*$","`$1"
            bcdedit /set $newGuid hypervisorlaunchtype Off
            Write-Host "Entry created.  Please reboot your machine and select the No Hyper-V opotion."
            return $false
        }

        Write-Host "Please disable Hyper-V before continuing.  This will require a reboot."
        return $false
    }

    return $true
}

function Update-Path() {
    $env:PATH = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
}

function Install-ChocolateyPackage
{
    param(
        [Parameter(Mandatory=$False)]
        [scriptblock]$Test,

        [Parameter(Mandatory=$True)]
        [string]$PackageName,

        [Parameter(Mandatory=$True)]
        [string]$TestingMessage,

        [Parameter(Mandatory=$True)]
        [string]$InstallingMessage,

        [Parameter(Mandatory=$True)]
        [int]$Progress
    )

    Write-Progress -PercentComplete $Progress -Activity $installingDependancies -Status $TestingMessage
    $Progress += 5
    if($Test -eq $null) {
        $Test = { (Get-Command -ErrorAction SilentlyContinue $PackageName) -ne $null}
    }
    if($Test.Invoke()){
        return $False
    }
    else {
        Write-Progress -PercentComplete $Progress -Activity $installingDependancies -Status $InstallingMessage
        cinst $PackageName
        Write-Progress -PercentComplete $Progress -Activity $installingDependancies -Status $InstallingMessage
        Update-Path
        if($Test.Invoke() -eq $null) {
            Write-Host -ForegroundColor Red "Could not verify existence of $PackageName after installing.  You may need to install manually and ensure it is in your path."
            Write-Host "Test failed: `n`n"
            Write-Host $Test
        }
        return $True
    }
}


#################
##### SETUP #####
#################

Write-Progress -PercentComplete 0 -Activity "Checking Hypervisor" 
# Ensure Hyper-V is disabled
if((Check-Hypervisor) -eq $false) {
    return
}

# CHOCOLATEY
Write-Progress -PercentComplete 5 -Activity $installingDependancies -Status "Testing Program - Chocolatey"
if((Get-Command -ErrorAction SilentlyContinue choco) -eq $null)
{
    Write-Progress -PercentComplete 5 -Activity $installingDependancies -Status "Installing Chocolatey"
    iex ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1'))
}

# VAGRANT
$null = Install-ChocolateyPackage -PackageName vagrant -TestingMessage "Testing Program - Vagrant" -InstallingMessage "Installing Vagrant..." -Progress 20

# VIRTUALBOX
$virtualBoxTest = {
    (Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* |  % {
        $_.DisplayName
    } | ? {
        $_ -ne $null -and  $_.ToLower().Contains("virtualbox") 
    }).Length -gt 0
}
$null = Install-ChocolateyPackage -Test $virtualBoxTest -PackageName "virtualbox" -TestingMessage "Installation Detected - Virtualbox" -InstallingMessage "Installing Virtualbox..." -Progress 40

# PUPPET
$null = Install-ChocolateyPackage -PackageName puppet -TestingMessage "Testing Program - Puppet" -InstallingMessage "Installing Puppet..." -Progress 30
if((Test-Path "$PSScriptRoot\puppet\modules") -eq $false) {
    New-Item -ItemType Directory -Path "$PSScriptRoot\puppet\modules"
    @("puppetlabs-sdlib", "puppetlabs-apt", "willdurand-nodejs", "puppetlabs-ruby", "maestrodev-wget") | % {
        $folder = $_ -replace "^[^-]*-",""
        if((Test-Path "$PSScriptRoot\puppet\modules\$folder") -eq $false) {
            puppet module install -i "$PSScriptRoot\puppet\modules" --force $_
        }
    }
}

# SSH (GIT)
$sshTest = {
    $command = Get-Command ssh -ErrorAction SilentlyContinue
    if(($command -eq $null) -or ((ssh) -match "plink")) {
        return $False
    }
    return $True
}
$gitTest = {
    ($sshTest.Invoke()) -or (Test-Path "C:\Program Files\Git\bin\ssh.exe") -or (Test-Path "C:\Program Files (x86)\Git\bin\ssh.exe")
}

$gitInstalled = Install-ChocolateyPackage -Test $gitTest -PackageName git -TestingMessage "Testing Program - SSH" -InstallingMessage "Installing Git" -Progress 60

if(-not ($sshTest.Invoke())) {
    if($env:PATH -notmatch "C:\\Program Files( \(x86\))?\\Git\\bin") {
        $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
        if(Test-Path "C:\Program Files (x86)\Git\bin\ssh.exe") {
            [Environment]::SetEnvironmentVariable("Path", "C:\Program Files (x86)\Git\bin;$userPath", "User")
        } elseif(Test-Path "C:\Program Files\Git\bin\ssh.exe") {
            [Environment]::SetEnvironmentVariable("Path", "C:\Program Files\Git\bin;$userPath", "User")
        }
        Update-Path
    }

    if($sshTest.Invoke() -eq $False) {
        Write-Warning "SSH not in path or is using Putty SSH instead (not supported)"
        return
    }
}

#################
#### VAGRANT ####
#################

# START
Write-Progress -Activity "Starting Vagrant" -Status "Installing/Booting Vagrant Box" -PercentComplete 80
$status = (vagrant status | ? { $_ -match "default" }) -replace "^default\s*",""
if($status -match "not created|poweroff") {
    vagrant up
} elseif ($status -match "suspended") {
    vagrant resume
}

if($LastExitCode -ne 0) {
    Write-Host "An error occurred!"
    return
}

# BUILD
Write-Progress -Activity "Starting Vagrant" -Status "Running commands" -PercentComplete 90
vagrant ssh -c "cd /vagrant; bash -c './build.sh $Command'"

# SUSPEND/HALE - suspend doesn't work
$vagrantVersion = (vagrant --version) -replace "^[^\d]*((\d*\.?)+).*$","`$1"
if(-not $StayOn) {
    vagrant halt
}