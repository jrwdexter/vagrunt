Vagrunt
=======

## Summary

A set of scripts that sets up a vagrant machine in which to run a Nerdery-specific grunt build task.

## Installation

To install, simply run the below command in the repository's directory:

Powershell:

```powershell
iex ((New-Object Net.WebClient).DownloadString("http://goo.gl/ZcYjb2"))
```

Command Prompt:

`@powershell -NoProfile -ExecutionPolicy unrestricted -Command "iex ((new-object net.webclient).DownloadString('http://goo.gl/ZcYjb2'))"`

## Usage

Before usage, make sure your Powershell execution policy is:

```powershell
Set-ExecutionPolicy RemoteSigned
```

To use, run:

```powershell
vagrunt.ps1 [-StayOn] [-Command GruntCommand]
```

### Notes

If Hyper-V is enabled, you may be prompted to reboot.  Additionally, Vagrant itself will not operate with plink (Putty SSH), and it may cause issues if installed.