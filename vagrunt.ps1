param(
    [String]$Command
)

#################
### FUNCTIONS ###
#################

$installingDependancies = "Detecting and installing dependencies"

function Update-Path() {
    $env:PATH = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
}

function Install-ChocolateyPackage
{
    param(
        [Parameter(Mandatory=$False)]
        $Test,

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
    if($Test -eq $null) { $Test = Get-Command -ErrorAction SilentlyContinue $PackageName }
    if($Test -ne $null){
        return $False
    }
    else {
        Write-Progress -PercentComplete $Progress -Activity $installingDependancies -Status $InstallingMessage
        cinst $PackageName
        Write-Progress -PercentComplete $Progress -Activity $installingDependancies -Status $InstallingMessage
        Update-Path
        return $True
    }
}


#################
##### SETUP #####
#################

# CHOCOLATEY
Write-Progress -PercentComplete 0 -Activity $installingDependancies -Status "Testing Program - Chocolatey"
if((Get-Command -ErrorAction SilentlyContinue choco) -eq $null)
{
    Write-Progress -PercentComplete 5 -Activity $installingDependancies -Status "Installing Chocolatey"
    iex ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1'))
}

# VAGRANT
$null = Install-ChocolateyPackage -PackageName vagrant -TestingMessage "Testing Program - Vagrant" -InstallingMessage "Installing Vagrant..." -Progress 20

# VIRTUALBOX
$null = Install-ChocolateyPackage -Test ((Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* |  % {$_.DisplayName} | ? { $_ -ne $null -and  $_.ToLower().Contains("virtualbox") }).Length -gt 0) -PackageName "virtualbox" -TestingMessage "Installation Detected - Virtualbox" -InstallingMessage "Installing Virtualbox..." -Progress 40

# PUPPET
$null = Install-ChocolateyPackage -PackageName puppet -TestingMessage "Testing Program - Puppet" -InstallingMessage "Installing Puppet..." -Progress 30
if((Test-Path "$PSScriptRoot\puppet\modules") -eq $false) {
    New-Item -ItemType Directory -Path "$PSScriptRoot\puppet\modules"
    puppet module install -i "$PSScriptRoot\puppet\modules" --force puppetlabs-stdlib
    puppet module install -i "$PSScriptRoot\puppet\modules" --force puppetlabs-apt
    puppet module install -i "$PSScriptRoot\puppet\modules" --force willdurand-nodejs
    puppet module install -i "$PSScriptRoot\puppet\modules" --force puppetlabs-ruby
    puppet module install -i "$PSScriptRoot\puppet\modules" --force maestrodev-wget
}

# SSH (CYGWIN)
$cygwinInstalled = Install-ChocolateyPackage -Test (Get-Command ssh -ErrorAction SilentlyContinue) -PackageName cygwin -TestingMessage "Testing Program - SSH" -InstallingMessage "Installing Cygwin" -Progress 60
if($cygwinInstalled) {
    Write-Host "Starting cygwin package manager.  Please install the open SSH package."
    & C:\tools\cygwin\cygwinsetup.exe
    while($true) {
        Start-Sleep -Milliseconds 250
        if(Get-Process -Name cygwinsetup -ErrorAction SilentlyContinue)
        { break; }
    }
}

#################
#### VAGRANT ####
#################

Write-Progress -Activity "Starting Vagrant" -Status "Installing/Booting Vagrant Box" -PercentComplete 80
vagrant up
if($LastExitCode -ne 0) {
    Write-Host "`nVirtualbox non-functional.  You may have Hyper-V enabled."
    Write-Host "https://www.hanselman.com/blog/SwitchEasilyBetweenVirtualBoxAndHyperVWithABCDEditBootEntryInWindows81.aspx for an easy way to disable it."
    return
}

Write-Progress -Activity "Starting Vagrant" -Status "Running commands" -PercentComplete 90
vagrant ssh -c "cd /vagrant; bash -c './build.sh $Command'"