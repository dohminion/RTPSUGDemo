<#
Must run the following before running the script
Connect-AZAccount
Connet-AzureAd

TODO Need to convert to the following
Install-Module Microsoft.Graph -Scope CurrentUser
Update-Module Microsoft.Graph
Select-MgProfile -Name "beta"
Connect-MgGraph -Scopes 'Group.ReadWrite.All'

NOTE - Must run in PS 5.X
#>

function Test-Subscription {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [string]$SubscriptionName
    )
    
    begin {
        Write-Verbose "Testing Subscription $SubscriptionName"
    }
    
    process {
        switch ($SubscriptionName) {
            'Windows Azure  MSDN - Visual Studio Premium' {
                $SubName = 'VSP'
            }
            'Sub2' {
                $SubName = 'S2'
            }
            'Sub3' {
                $SubName = 'S3'
            }
            'Sub4' {
                $SubName = 'S4'
            }
            'Sub5' {
                $SubName = 'S5'
            }
            Default {
                Write-Verbose "No Subscription match found.  Exiting."
                Break
            }
        }
    }
    
    end {
        Return $SubName
    }
}

function Test-ExistingGroups {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [string]$GroupToTest
    )
    
    begin {
    }
    
    process {
        if (Get-AzADGroup -DisplayName "$GroupToTest") {
            $Group = Get-AzADGroup -DisplayName "$GroupToTest"
            Write-Verbose "$GrouptoTest exists, skipping creation..."
        }
        else {
            Write-Verbose "$GroupToTest doesn't exist, creating"
            $Group = New-AZADGroup -DisplayName "$GroupToTest" -MailNickname "NotSet" 
            Write-Host "Pausing for 10 seconds to allow group availablility"
            Start-Sleep 10
        }        
    }
    
    end {
        Return $Group
    }
}

function Test-OwnerInputFile {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [string]$AADGName
    )
    
    begin {
    }
    
    process {
        if (test-path -Path "C:\temp\$AADGName-Owners.txt" -PathType Leaf) {
            $OwnerGroupFile = Get-Content "C:\temp\$AADGName-Owners.txt"
        }
        else {
            Write-Verbose "Owners file missing Exiting..."
            $OwnerGroupFile = $null
            Break
        }
    }
    
    end {
        Return $OwnerGroupFile
    }
}

function Set-RSGGroupOwners {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [string]$TargetGroupID,
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [string]$OwnerMember
    )
    
    begin {
    }
    
    process {
        Write-Verbose "Adding Owner $OwnerMember"

        $ownertest = Get-AzureADGroupOwner -objectid $TargetGroupID | Where-Object { $_.ObjectID -eq $OwnerMember }
        if ($ownertest) {
            Write-Verbose 'Account is already an owner'
        }
        else {
            Add-AzureADGroupOwner -ObjectId $TargetGroupID -RefObjectId $OwnerMember
        }
    }
    
    end {
        
    }
}

function Add-AZGroupMembers {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [string]$Owner,
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [string]$OwnerGroupID
    )
    
    begin {
        
    }
    
    process {
        Write-Verbose "Name from File - $owner"
        $UserID = (Get-AzureADuser -SearchString $Owner).ObjectId
        Write-Verbose "User ID is: $userID"
        Write-Verbose "OwnerGroupID is $OwnergroupID"
        $memberTest = Get-AZADGroupMember -GroupObjectId $OwnerGroupID | Where-Object { $_.id -eq $UserID }
        if ($MemberTest) {
            Write-Verbose "Already a member, skipping..."
        }
        else {
            Add-AzureADGroupMember -RefObjectId $userid -ObjectId $OwnergroupID
            Write-Verbose "Owner Group member added."
        }
    }
    
    end {
        
    }
}

function Add-RSGGroupOwners {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [string]$AADGName,
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [string]$ReaderID,
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [string]$ContribID,
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [string]$OwnerGroupID
    )
    
    begin {
    }
    
    process {
        $OwnerGroupFile = Test-OwnerInputFile $AADGName
        if ($OwnerGroupFile) {
            foreach ($owner in $OwnerGroupFile) {
                Write-Verbose $owner
                Add-AZGroupMembers -Owner $owner -OwnerGroupID $OwnerGroupID
            }
            $OwnerGroupMembers = Get-AzureADGroupMember -ObjectId $OwnerGroupID
            foreach ($OwnerMember in $OwnerGroupMembers.ObjectID) {
                Set-RSGGroupOwners -TargetGroupID $ContribID -OwnerMember $OwnerMember
                Set-RSGGroupOwners -TargetGroupID $ReaderID  -OwnerMember $OwnerMember
                Set-RSGGroupOwners -TargetGroupID $OwnerGroupID -OwnerMember $OwnerMember
            }
        }
        else {
            Write-Verbose 'Owners Group File is empty or missing.'
            Break
        }
    }
    
    end {
        
    }
}

function Invoke-InputFileProcessing {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$InputFilePath
    )
    
    begin {
        if (test-path -Path $InputFilePath -PathType Leaf) {
            $RSGList = Import-csv $InputFilePath
        }
        else {
            Write-Verbose "Import file missing Exiting..."
            $RSGList = $null
            Break
        }
    }
    
    process {
        foreach ($RSGName in $RSGList) {
            $SubName = Test-Subscription $RSGName.subscription
            $AADGName = $RSGName.NAME
            Write-Verbose "Sub is - $SubName RSGName is - $AADGName"

            Pause
            $OwnerGroupName = "AG-$SubName-RSGAccess-$AADGName-Owner"
            $ReaderGroupName = "AG-$SubName-RSGAccess-$AADGName-Reader"
            $ContribGroupName = "AG-$SubName-RSGAccess-$AADGName-Contrib"
    
            $OwnerGroup = Test-ExistingGroups $OwnerGroupName
            $ReaderGroup = Test-ExistingGroups $ReaderGroupName
            $ContribGroup = Test-ExistingGroups $ContribGroupName
    
            $ContribID = $ContribGroup.ID
            $ReaderID = $ReaderGroup.ID
            $OwnerGroupID = $OwnerGroup.ID

            Add-RSGGroupOwners -AADGName $AADGName -ReaderID $ReaderID -ContribID $ContribID -OwnerGroupID $OwnerGroupID
            Add-RSGRoles -ContribID $ContribID -ReaderID $ReaderID -AADGName $AADGName -ContribGroupName $ContribGroupName -ReaderGroupName $ReaderGroupName
        }

    }
    
    end {
    }
}

function Add-RSGRoles {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$ContribID,
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$ContribGroupName,
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$ReaderID,
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$ReaderGroupName,
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$AADGName
    )
    
    begin {
        #Write-host 'Pausing for 15 Second so groups can be found to apply permissions.'
        #Start-Sleep 15
    }
    
    process {
        $NewRole = 'Contributor'
        if (Get-AzRoleAssignment -ResourceGroupName $AADGName | Where-Object { $_.DisplayName -eq $ContribGroupName -and $_.RoleDefinitionName -eq $NewRole }) {
            Write-Verbose "Contrib Role is already assigned"
        }
        else {
            New-AzRoleAssignment -ObjectId $ContribID -RoleDefinitionName $NewRole  -ResourceGroupName $AADGName    <# Action when all if and elseif conditions are false #>
            Write-Verbose "Adding $NewRole Role"
        }
        
        $NewRole = 'Reader'
        if (Get-AzRoleAssignment -ResourceGroupName $AADGName | Where-Object { $_.DisplayName -eq $ReaderGroupName -and $_.RoleDefinitionName -eq $NewRole }) {
            Write-Verbose "Reader Role is already assigned"
        }
        else {
            New-AzRoleAssignment -ObjectId $ReaderID -RoleDefinitionName Reader  -ResourceGroupName $AADGName    <# Action when all if and elseif conditions are false #>
            Write-Verbose "Adding $NewRole Role"
        }
    }
    
    end {
    }
}

#TODO Delete groups from deleted RSGs

#TODO add groups to access reviews since owners are set

<#
Flow

Invoke-InputFileProcessing
-  Test-Subscription (get Short name back as $SubName)
-  Test-Existing Groups (create if missing, return Group and set to Variable)
-  Add-RSGGroupOwners
--  Test-OwnerInputFile (return contents)
--- Add-AZGroupMembers (add members to Owners Group)
---- Get-AZADGroupMember (test for existing membership)
---- Add Member if not
--- GetAzureADGroupMembers (Of owners group)
---- Set-RSGGroupOwners of each group to Owners group members
----- Test existing owners, add if missing
-  Add-RSGRoles
-- See if Group has Contrib or Reader Role, add if missing

#>