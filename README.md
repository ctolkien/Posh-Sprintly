# Posh-Sprintly

A PowerShell module containing a bunch of features to help you work with Sprint.ly. It is expected to be used along side Posh-Git.
I always found it jarring to my workflow to have to head back to the website whilst bashing out my code.

- Code... Code... Code... Ready to commit
- Head to Sprint.ly website
- Find the task / task #
- Back to git, write the commit msg so it references the task
- Back to Sprint.ly website
- Find the next item to work on
- Move it to "current"
- Repeat..

It's the aim to reduce this down to a minimum and keep you cranking out code without getting distracted.


### Requirements

Powershell 3.

### What's it do?

Extends the PowerShell prompt to include details of the current project and tasks you're working on. For instance:

    C:\foo [master] [Posh-Sprintly #34 T]>

[master] is the current branch (this is from Posh-Git). Next up, we display the current project you're working on with sprintly, the current task number and the task type (in this case 'T').

### TL;DR Usage

Once you've configured the credentials and project you're working on, you just need one command:

    Set-SprintlyNextItem

This will keep you moving forward, by grabbing the next available task (moving it to 'current' if it's not already) and updating your prompt.

### Install

* Drop this into your modules directory

* Modify your profile to include:


    Import-Module sprintly
    Set-SprintlyCredentials "sprintly@emailaddress.com" "sprintly-api-key" -silent

Then down before Posh-Git closes out the prompt:


    if ($global:CurrentSprintlyProject) {
        Write-SprintlyPrompt
    }


It should also work fine with Posh-Hg

### How do I use it?

Configure you Sprint.ly credentials (preferable in your profile):

    Set-SprintlyCredentials "sprintly@emailaddress.com" "sprintly-api-key" -silent

Next up, we want to set the current project we're working on:

    Set-SprintlyCurrentProject 1234

How can I figure out the project number without heading back to the website?

    Get-SprintlyProjects 

Will return a collection of all the projects you have access to. This is PowerShell, so you can pipe objects around. For instance:

    Get-SprintlyProjects | ? name -eq "project name" | Set-SprintlyCurrentProject

 Which is effectively, Get the sprintly projects, where the name matches the project I'm after and then pipe it set it as the current project.

    Get-SprintlyItems

Will give you a list of all the items in this project (that are in 'current' or 'backlog').

    Set-SprintlyCurrentItem  -id 123

This will either take in a task item (normally piped in), or you can specify the id of the item directly. Normally however, you'll use the following:

    Set-SprintlyNextItem

This will find the next thing for you to work on, it will take either the first item in your current list, or if nothing can be found there, it will find the first item in the backlog assigned to you, move it to the current list and then assign it as the current task.

    Add-SprintlyItem task "title" "description"

This will add the item to the backlog. task/defect/test will all work, story is likely bugged at the moment.

There's a few other command around, just explore the module.

Further docs to come...