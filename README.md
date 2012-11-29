# Posh-Sprint

A PowerShell module containing a bunch of features to help you work with Sprint.ly.

## Warning

This is alpha alpha 0.00001, has just been thrown together...

Is expected to be used along side Posh-Git.

Modify your profile to include:

    Import-Module sprintly
    Set-SprintlyCredentials "sprintly@emailaddress.com" "sprintly-api-key" -silent

Then down before Posh-Git closes out the prompt:


    if ($global:currentProjectId) {
        Write-SprintlyPrompt
    }


Further docs to come...