# Posh-Sprintly

A PowerShell module containing a bunch of features to help you work with Sprint.ly. Is expected to be used along side Posh-Git.

### Requirements

Powershell 3.

### What's it do?

Extends the PowerShell prompt to include details of the current project and tasks you're working on.

### Install

* Drop this into your modules directory

* Modify your profile to include:

    Import-Module sprintly
    Set-SprintlyCredentials "sprintly@emailaddress.com" "sprintly-api-key" -silent

Then down before Posh-Git closes out the prompt:


    if ($global:CurrentSprintlyProject) {
        Write-SprintlyPrompt
    }


Further docs to come...