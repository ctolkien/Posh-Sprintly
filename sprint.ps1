[string]$script:emailAddress
[string]$script:apiKey
[string]$script:currentProjectId
[int]$script:currentTaskId
[string]$script:authToken
[int]$script:userId
$script:currentProject
$script:currentTask

function Set-SprintlyCredentials([string]$emailAddress, [string]$apiKey) {
    $script:emailAddress = $emailAddress
    $script:apiKey = $apiKey

    $script:authToken = "basic "
    $script:authToken += ConvertTo-Base64($script:emailAddress + ":" + $script:apiKey)

    #now we need to find out the id...
    Write-Output "Sprint.ly Credentials have been set..."
}


function Get-SprintlyProjects {
    Invoke-RestMethod "https://sprint.ly/api/products.json" -Headers @{ "authorization" = $authToken }
}

function Get-SprintlyCurrentTask {
    return $script:currentTask
}

function Get-SprintlyNextTask {

    $task = Invoke-RestMethod ("https://sprint.ly/api/products/" + $script:currentProjectId + "/items.json?limit=1&amp;assigned_to=" + $script:userId) -Headers @{ "authorization" =  $authToken }
    if (!$task) {
        Write-Host "Looks like there's nothing to do...!"
        $script:currentTaskId = $null
        $script:currentTask = $null
        return
    }
    Set-SprintlyTask $task.number

    #if this task isn't on the 'inprogress' status, lets upate it
    if ($task.status -eq "backlog") {
        Invoke-RestMethod  ("https://sprint.ly/api/products/" + $script:currentProjectId + "/items/" + $script:currentTaskId  + ".json") -Headers @{ "authorization" =  $authToken } -Method Post -Body @{ "status" = "in-progress" }
        $task = Invoke-RestMethod ("https://sprint.ly/api/products/" + $script:currentProjectId + "/items.json?limit=1&amp;assigned_to=" + $script:userId) -Headers @{ "authorization" =  $authToken }
    }

}

function Add-SprintlyItem([string]$title, [string]$description) {

    Invoke-RestMethod  ("https://sprint.ly/api/products/" + $script:currentProjectId + "/items.json") -Headers @{ "authorization" =  $authToken } -Method Post -Body @{ "status" = "in-progress" }

}

function Get-SprintlyComments {
    return Invoke-RestMethod ("https://sprint.ly/api/products/" + $script:currentProjectId + "/items/" + $script:currentTaskId + "/comments.json") -Headers @{ "authorization" =  $authToken }
}

function Get-SprintlyItems {

    param(
    [Parameter(Mandatory=$false, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
    [int]$id
    )

    if (!$id) {
        $id = $script:currentProjectId
    }

    return Invoke-RestMethod ("https://sprint.ly/api/products/" + $id + "/items.json") -Headers @{ "authorization" =  $authToken }
}

function Get-SprintlyItem {

    param(
    [Parameter(Mandatory=$true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
    [int]
    $number
    )

    if (!$script:currentProjectId) {
        Write-Host "You must set a project first with 'Set-SprintlyProject'"
        return
    }

    return Invoke-RestMethod ("https://sprint.ly/api/products/" + $script:currentProjectId + "/items/" + $number  + ".json") -Headers @{ "authorization" =  $authToken }
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

    return Invoke-RestMethod ("https://sprint.ly/api/products/" + $script:currentProjectId + "/items.json") -Headers @{ "authorization" =  $authToken } -Method Post -Body $body

}

function Set-SprintlyProject {

    param(
    [Parameter(Mandatory=$true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
    [int]$id
    )

    $content =Invoke-RestMethod ("https://sprint.ly/api/products/" + $id + ".json") -Headers @{ "authorization" =  $authToken }
    $script:currentProjectId = $id
    $script:currentProject = $content.name

    #now we also need to find out our user id for this project....
    $users = ((Invoke-RestMethod ("https://sprint.ly/api/products/" + $id + "/people.json") -Headers @{ "authorization" =  $authToken }) | ? email -EQ $script:emailAddress)
    $script:userId = $users.id
    Get-SprintlyNextTask
    
}

function Set-SprintlyTask([int]$taskId) {

    $script:currentTask =Get-SprintlyItem([int]$taskId)
    $script:currentTaskId = $taskId
}


function Write-SprintlyPrompt {
    Write-Host(Get-Location) -NoNewline
    Write-Host(" [") -NoNewline -ForegroundColor Cyan
    Write-Host $script:currentProject -NoNewline

    If([int]$script:currentTaskId) {
        Write-Host(" #" + $script:currentTaskId) -NoNewline    
    }

    Write-Host("]") -NoNewline -ForegroundColor Cyan

}

function prompt {
    Write-SprintlyPrompt

    return ">"
}


function ConvertTo-Base64($string) {
   $bytes  = [System.Text.Encoding]::UTF8.GetBytes($string);
   $encoded = [System.Convert]::ToBase64String($bytes); 

   return $encoded;
}
