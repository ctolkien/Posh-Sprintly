[string]$script:emailAddress
[string]$script:apiKey
[string]$script:authToken
[int]$script:SprintlyUserId
$global:SprintlyCurrentProject
$script:SprintlyCurrentProjectItems
$script:SprintlyCurrentItem
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
    return Format-SprintlyProject $SprintlyProjects
    
}

function Set-SprintlyCurrentProject {

    param(
    [Parameter(Mandatory=$true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
    [int]$id
    )

    $global:SprintlyCurrentProject = (Get-SprintlyProjects) | ? id -eq $id

    #now we also need to find out our user id for this project....
    $script:SprintlyProjectUsers = (Invoke-RestMethod ("https://sprint.ly/api/products/" + $id + "/people.json") -Headers @{ "authorization" =  $authToken })
    
    $me =  $script:SprintlyProjectUsers | ? email -EQ $script:emailAddress
    $script:SprintlyUserId = $me.id
    
}


function Format-SprintlyProject($project) {
    return $project | select Name, Id, archived

}


function Get-SprintlyCurrentItem {
    return Format-SprintlyItem $script:SprintlyCurrentItem
}


function Format-SprintlyItem($item) {
    return $item | select title, description, status, number, type
}

function Set-SprintlyNextItem {

    $task = Invoke-RestMethod ("https://sprint.ly/api/products/" + ($global:SprintlyCurrentProject).id + "/items.json?limit=1&amp;assigned_to=" + $script:SprintlyUserId) -Headers @{ "authorization" =  $authToken }
    if (!$task) {
        Write-Host "Looks like there's nothing to do...!"
        $script:SprintlyCurrentItem = $null
        return
    }

    Set-SprintlyCurrentItem $task

    #if this task isn't on the 'in-progress' status, lets upate it
    if ($task.status -eq "backlog") {
        Invoke-RestMethod  ("https://sprint.ly/api/products/" + ($global:SprintlyCurrentProject).id + "/items/" + ($script:SprintlyCurrentItem).number  + ".json") -Headers @{ "authorization" =  $authToken } -Method Post -Body @{ "status" = "in-progress" }
        $task = Invoke-RestMethod ("https://sprint.ly/api/products/" + ($global:SprintlyCurrentProject).id + "/items.json?limit=1&amp;assigned_to=" + $script:SprintlyUserId) -Headers @{ "authorization" =  $authToken }
    }

}


function Get-SprintlyItems {

    param(
    [Parameter(Mandatory=$false, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
    [int]$id
    )

    if (!$id) {
        $id = ($global:SprintlyCurrentProject).id
    }

    $response = Invoke-RestMethod ("https://sprint.ly/api/products/" + $id + "/items.json") -Headers @{ "authorization" =  $authToken }

    return  Format-SprintlyItem $response
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

    $response = Invoke-RestMethod ("https://sprint.ly/api/products/" + ($global:SprintlyCurrentProject).id + "/items/" + $number  + ".json") -Headers @{ "authorization" =  $authToken }

    return Format-SprintlyTask $response
}

function Set-SprintlyCurrentItem {

    param(
    [Parameter(Mandatory=$false)]
    $item,
    [Parameter(Mandatory=$false)]
    $id
    )

    if ($item) {
        $script:SprintlyCurrentItem = $item
    }
    else {
        $script:SprintlyCurrentItem = (Get-SprintlyItems) | ? number -eq $id
    }
    
}

function Get-SprintlyItemComments {

    if (!$script:SprintlyCurrentItem) {
        Write-Host "You must have a current Sprint.ly item, try Set-SprintlyNextItem"
        return
    }

    $response = Invoke-RestMethod ("https://sprint.ly/api/products/" + ($global:SprintlyCurrentProject).id + "/items/" + ($script:SprintlyCurrentItem).number + "/comments.json") -Headers @{ "authorization" =  $authToken }

    return $response | select @{Name="Comment"; Expression={$_.body}},  @{Name="Created By"; Expression= {$_.created_by.first_name + " " + $_.created_by.last_name}}, @{Name="Created On"; Expression={[System.DateTime]::Parse($_.created_at).ToShortDateString()}}
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

    $response = Invoke-RestMethod ("https://sprint.ly/api/products/" + ($global:SprintlyCurrentProject).id + "/items.json") -Headers @{ "authorization" =  $authToken } -Method Post -Body $body

    return Format-SprintlyTask $response

}


function Remove-Sprintly {
    $global:SprintlyCurrentProject =$null
}


function Write-SprintlyPrompt {
    
    Write-Host(" [") -NoNewline -ForegroundColor Cyan
    Write-Host ($global:SprintlyCurrentProject).name -NoNewline

    If($script:SprintlyCurrentItem) {
        Write-Host(" #" + ($script:SprintlyCurrentItem).number) -NoNewline    
        $taskType = ($script:SprintlyCurrentItem).type[0].ToString().ToUpper()
        $taskColour = "Green"
        
        if (($script:SprintlyCurrentItem).type -eq "task") {
            $taskColour = "Gray"
        }
        elseif (($script:SprintlyCurrentItem).type -eq "defect") {
            $taskColour = "Red"
        }
        elseif (($script:SprintlyCurrentItem).type -eq "test") {
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
