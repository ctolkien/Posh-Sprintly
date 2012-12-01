[string]$script:emailAddress
[string]$script:apiKey
[string]$script:authToken
[int]$script:SprintlyUserId
$global:SprintlyCurrentProject
$script:SprintlyCurrentTask
$script:SprintlyProjects
$script:SprintlyProjectUsers

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

    if (!$silent)
    {
        Write-Output "Sprint.ly Credentials have been set..."
    }
}


function Get-SprintlyProjects {
    if (!$SprintlyProjects) {
        $SprintlyProjects = Invoke-RestMethod "https://sprint.ly/api/products.json" -Headers @{ "authorization" = $authToken }    
    }
    return $SprintlyProjects
    
}

function Set-SprintlyProject {

    param(
    [Parameter(Mandatory=$true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
    [int]$id
    )

    $content = Get-SprintlyProjects | ? id -eq $id 
    $global:SprintlyCurrentProject = $content

    #now we also need to find out our user id for this project....
    $script:SprintlyProjectUsers = (Invoke-RestMethod ("https://sprint.ly/api/products/" + $id + "/people.json") -Headers @{ "authorization" =  $authToken })
    
    $me =  $script:SprintlyProjectUsers | ? email -EQ $script:emailAddress
    $script:SprintlyUserId = $me.id
    Get-SprintlyNextTask
    
}


function Get-SprintlyCurrentTask {
    return $script:SprintlyCurrentTask
}

function Get-SprintlyNextTask {

    $task = Invoke-RestMethod ("https://sprint.ly/api/products/" + ($global:SprintlyCurrentProject).id + "/items.json?limit=1&amp;assigned_to=" + $script:SprintlyUserId) -Headers @{ "authorization" =  $authToken }
    if (!$task) {
        Write-Host "Looks like there's nothing to do...!"
        $script:SprintlyCurrentTask = $null
        return
    }
    Set-SprintlyTask $task

    #if this task isn't on the 'in-progress' status, lets upate it
    if ($task.status -eq "backlog") {
        Invoke-RestMethod  ("https://sprint.ly/api/products/" + ($global:SprintlyCurrentProject).id + "/items/" + ($script:SprintlyCurrentTask).number  + ".json") -Headers @{ "authorization" =  $authToken } -Method Post -Body @{ "status" = "in-progress" }
        $task = Invoke-RestMethod ("https://sprint.ly/api/products/" + ($global:SprintlyCurrentProject).id + "/items.json?limit=1&amp;assigned_to=" + $script:SprintlyUserId) -Headers @{ "authorization" =  $authToken }
    }

}

function Add-SprintlyItem([string]$title, [string]$description) {

    Invoke-RestMethod  ("https://sprint.ly/api/products/" + ($global:SprintlyCurrentProject).id + "/items.json") -Headers @{ "authorization" =  $authToken } -Method Post -Body @{ "status" = "in-progress" }

}

function Get-SprintlyComments {
    return Invoke-RestMethod ("https://sprint.ly/api/products/" + ($global:SprintlyCurrentProject).id + "/items/" + ($script:SprintlyCurrentTask).number + "/comments.json") -Headers @{ "authorization" =  $authToken }
}

function Get-SprintlyItems {

    param(
    [Parameter(Mandatory=$false, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
    [int]$id
    )

    if (!$id) {
        $id = ($global:SprintlyCurrentProject).id
    }

    return Invoke-RestMethod ("https://sprint.ly/api/products/" + $id + "/items.json") -Headers @{ "authorization" =  $authToken }
}

function Get-SprintlyItem {

    param(
    [Parameter(Mandatory=$true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
    [int]
    $number
    )

    if (!$global:SprintlyCurrentProject) {
        Write-Host "You must set a project first with 'Set-SprintlyProject'"
        return
    }

    $SprintlyCurrentTask = Invoke-RestMethod ("https://sprint.ly/api/products/" + ($global:SprintlyCurrentProject).id + "/items/" + $number  + ".json") -Headers @{ "authorization" =  $authToken }

    return $script:SprintlyCurrentTask
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

    return Invoke-RestMethod ("https://sprint.ly/api/products/" + ($global:SprintlyCurrentProject).id + "/items.json") -Headers @{ "authorization" =  $authToken } -Method Post -Body $body

}



function Set-SprintlyTask($task) {

    $script:SprintlyCurrentTask = $task
}

function Remove-Sprintly {
    $global:SprintlyCurrentProject =$null
}


function Write-SprintlyPrompt {
    
    Write-Host(" [") -NoNewline -ForegroundColor Cyan
    Write-Host ($global:SprintlyCurrentProject).name -NoNewline

    If($script:SprintlyCurrentTask) {
        Write-Host(" #" + ($script:SprintlyCurrentTask).number) -NoNewline    
        $taskType = ($script:SprintlyCurrentTask).type[0].ToString().ToUpper()
        $taskColour = "Green"
        
        if (($script:SprintlyCurrentTask).type -eq "task") {
            $taskColour = "Gray"
        }
        elseif (($script:SprintlyCurrentTask).type -eq "defect") {
            $taskColour = "Red"
        }
        elseif (($script:SprintlyCurrentTask).type -eq "test") {
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
