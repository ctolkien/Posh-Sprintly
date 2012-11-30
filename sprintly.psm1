[string]$script:emailAddress
[string]$script:apiKey
[int]$global:currentProjectId
[int]$script:currentTaskId
[string]$script:authToken
[int]$script:userId
$script:currentProject
$script:currentTask
$script:projects
$script:projectUsers

function Set-SprintlyCredentials {

    param(
    [Parameter(Mandatory=$true)]
    $emailAddress,
    [Parameter(Mandatory=$true)]
    $apiKey,
    [Parameter(Mandatory=$false)]
    [switch]$silent
    )


    $script:emailAddress = $emailAddress
    $script:apiKey = $apiKey

    $script:authToken = "basic "
    $script:authToken += ConvertTo-Base64($script:emailAddress + ":" + $script:apiKey)

    #now we need to find out the id...
    if (!$silent)
    {
        Write-Output "Sprint.ly Credentials have been set..."
    }
}


function Get-SprintlyProjects {
    if (!$script:projects) {
        $script:projects = Invoke-RestMethod "https://sprint.ly/api/products.json" -Headers @{ "authorization" = $authToken }    
    }
    return $script:projects
    
}

function Set-SprintlyProject {

    param(
    [Parameter(Mandatory=$true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
    [int]$id
    )

    $content = Get-SprintlyProjects | ? id -eq $id 
    $global:currentProjectId = $id
    $script:currentProject = $content

    #now we also need to find out our user id for this project....
    $script:projectUsers = (Invoke-RestMethod ("https://sprint.ly/api/products/" + $id + "/people.json") -Headers @{ "authorization" =  $authToken })
    
    $me =  $script:projectUsers | ? email -EQ $script:emailAddress
    $script:userId = $me.id
    Get-SprintlyNextTask
    
}


function Get-SprintlyCurrentTask {
    return $script:currentTask
}

function Get-SprintlyNextTask {

    $task = Invoke-RestMethod ("https://sprint.ly/api/products/" + $global:currentProjectId + "/items.json?limit=1&amp;assigned_to=" + $script:userId) -Headers @{ "authorization" =  $authToken }
    if (!$task) {
        Write-Host "Looks like there's nothing to do...!"
        $script:currentTaskId = $null
        $script:currentTask = $null
        return
    }
    Set-SprintlyTask $task

    #if this task isn't on the 'inprogress' status, lets upate it
    if ($task.status -eq "backlog") {
        Invoke-RestMethod  ("https://sprint.ly/api/products/" + $global:currentProjectId + "/items/" + $script:currentTaskId  + ".json") -Headers @{ "authorization" =  $authToken } -Method Post -Body @{ "status" = "in-progress" }
        $task = Invoke-RestMethod ("https://sprint.ly/api/products/" + $global:currentProjectId + "/items.json?limit=1&amp;assigned_to=" + $script:userId) -Headers @{ "authorization" =  $authToken }
    }

}

function Add-SprintlyItem([string]$title, [string]$description) {

    Invoke-RestMethod  ("https://sprint.ly/api/products/" + $global:currentProjectId + "/items.json") -Headers @{ "authorization" =  $authToken } -Method Post -Body @{ "status" = "in-progress" }

}

function Get-SprintlyComments {
    return Invoke-RestMethod ("https://sprint.ly/api/products/" + $global:currentProjectId + "/items/" + $script:currentTaskId + "/comments.json") -Headers @{ "authorization" =  $authToken }
}

function Get-SprintlyItems {

    param(
    [Parameter(Mandatory=$false, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
    [int]$id
    )

    if (!$id) {
        $id = $global:currentProjectId
    }

    return Invoke-RestMethod ("https://sprint.ly/api/products/" + $id + "/items.json") -Headers @{ "authorization" =  $authToken }
}

function Get-SprintlyItem {

    param(
    [Parameter(Mandatory=$true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
    [int]
    $number
    )

    if (!$global:currentProjectId) {
        Write-Host "You must set a project first with 'Set-SprintlyProject'"
        return
    }

    $script:currentTask = Invoke-RestMethod ("https://sprint.ly/api/products/" + $global:currentProjectId + "/items/" + $number  + ".json") -Headers @{ "authorization" =  $authToken }

    return $script:currentTask
}

function Add-SprintlyItem {

    param(

    [ValidateSet("story","task","defect","test")]
    [Parameter(Mandatory=$true, Position =0)]
    [string]$type,

    [Parameter(Mandatory =$true, Position = 1)]
    [string]$title,

    [Parameter(Mandatory=$false, Position = 2)]
    [string]$description,

    $assigned_to
    )

    $body = @{ "type" = $type; "title" = $title; "description" = $description  }

    return Invoke-RestMethod ("https://sprint.ly/api/products/" + $global:currentProjectId + "/items.json") -Headers @{ "authorization" =  $authToken } -Method Post -Body $body

}



function Set-SprintlyTask($task) {

    $script:currentTask = $task
    $script:currentTaskId = ($task).number
}

function Remove-Sprintly {
    $global:currentProjectId =$null
}


function Write-SprintlyPrompt {
    
    Write-Host(" [") -NoNewline -ForegroundColor Cyan
    Write-Host ($script:currentProject).name -NoNewline

    If($script:currentTask) {
        Write-Host(" #" + ($script:currentTask).number) -NoNewline    
        $taskType = ($script:currentTask).type[0].ToString().ToUpper()
        $taskColour = "Green"
        
        if (($script:currentTask).type -eq "task") {
            $taskColour = "Gray"
        }
        elseif (($script:currentTask).type -eq "defect") {
            $taskColour = "Red"
        }
        elseif (($script:currentTask).type -eq "test") {
            $taskColour = "Blue"
        }

        Write-Host(" " + $taskType) -NoNewline -ForegroundColor $taskColour
    }

    Write-Host("]") -NoNewline -ForegroundColor Cyan

}


function ConvertTo-Base64($string) {
   $bytes  = [System.Text.Encoding]::UTF8.GetBytes($string);
   $encoded = [System.Convert]::ToBase64String($bytes); 

   return $encoded;
}
