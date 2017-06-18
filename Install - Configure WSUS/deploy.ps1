<#
.SYNOPSIS
    Provision a VM with WSUS role

.DESCRIPTION
    Provisions a VM, adds a 500 GB data disk and installs and configures WSUS role. It also adds the OMS extension to the VM.
#>

param(
[Parameter(Mandatory=$True, HelpMessage="Provide the Azure Subscription Id where WSUS VM will be deployed")]
[string]
$subscriptionId,

[Parameter(Mandatory=$true,  HelpMessage="Provide Region where WSUS VM will be deployed")]
[string]
$Region,

[Parameter(Mandatory=$True, HelpMessage="Provide the existing Virtual Network name")]
[string]
$ExistingVirtualNetworkName,

[Parameter(Mandatory=$True, HelpMessage="Example: InstallWSUS.ps1")]
[string]
$customScriptFileToRun,

[Parameter(Mandatory=$True, HelpMessage="Provide the storage account name where the custom script file is stored")]
[string]
$customScriptStorageAccountName,

[Parameter(Mandatory=$True, HelpMessage="Provide the Resource Groups Name of the storage account where custom scripts are uploaded")]
[string]
$customScriptStorageAccountNamesResourceGroup,

[Parameter(Mandatory=$True, HelpMessage="Provide the Azure Subscription Id for the Key Vault (the Management Subscription)")]
[string]
$managementSubscriptionId,

[Parameter(Mandatory=$True, HelpMessage="Provide the Key Vault name that exists in the other subscription")]
[string]
$keyVaultName,

[Parameter(Mandatory=$True, HelpMessage="Provide the Container name where CustomScriptExtension script is uploaded")]
[string]
$CSEContainerName,

[Parameter(Mandatory=$True)]
[PSCustomObject]
$Tags,

[Parameter(Mandatory=$True, HelpMessage="Provide name of the existing Resource Group which have the existing VNets")]
[string]
$ResourceGroupName,

[Parameter(Mandatory=$True, HelpMessage="Provide the Name of Azure Storage Account to be associated with the VM")]
[string]
$VMStorageAccountName,

[Parameter(Mandatory=$True, HelpMessage="Provide the Deployment Path for JSON templates")]
[string]
$VSTSDeploymentPath,

[Parameter(Mandatory=$True, HelpMessage="Provide the Name for Template Deployment")]
[string]
$VSTSDeploymentName,

[Parameter(Mandatory=$True, HelpMessage="The schedule for the daily sync")]
[string]
$SyncHours,

[Parameter(Mandatory=$True, HelpMessage="The schedule for the daily sync")]
[string]
$SyncMinutes,

[Parameter(Mandatory=$True, HelpMessage="OMS Workspace Name")]
[string]
$workspaceName,

[Parameter(Mandatory=$True, HelpMessage="OMS Workspace Id")]
[string]
$workspaceResourceGroup
)


#******************************************************************************
# Script body
# Execution begins here
#******************************************************************************
$ErrorActionPreference = "Stop"

# Select Key Vault subscription
Write-Output "Selecting Management Subscription: '$managementSubscriptionId'";
Set-AzureRmContext -SubscriptionId $managementSubscriptionId


$AdminUsername = Get-AzureKeyVaultSecret -VaultName $keyVaultname -Name AdminUsername
$AdminPassword = Get-AzureKeyVaultSecret -VaultName $keyVaultname -Name AdminPassword

$StorageAccountKey = (Get-AzureRmStorageAccountKey -StorageAccountName $customScriptStorageAccountName -ResourceGroupName $customScriptStorageAccountNamesResourceGroup).Value[0]
$Ctx = New-AzureStorageContext –StorageAccountName $customScriptStorageAccountName -StorageAccountKey $StorageAccountKey
$SASToken = New-AzureStorageBlobSASToken -Container $CSEContainerName -Blob $customScriptFileToRun -Permission r -StartTime ((Get-Date).AddDays(-1)) -ExpiryTime ((Get-Date).Addyears(+5)) -FullUri -Context $Ctx


#Getting OMS Workspace Id and Key
$workspace = Get-AzureRmOperationalInsightsWorkspace -ResourceGroupName $workspaceResourceGroup -Name $workspaceName
$key =  Get-AzureRmOperationalInsightsWorkspaceSharedKeys -ResourceGroupName $workspaceResourceGroup -Name $workspaceName

$workspaceId = $workspace.CustomerId
$workspaceKey = $key.PrimarySharedKey


# Select subscription to create the VM
Write-Output "Selecting the subscription to create the VM: '$subscriptionId'";
Set-AzureRmContext -SubscriptionID $subscriptionId;

#Deploy the Template to the Resource Group
Write-output "Deploying to $Region in $ResourceGroupName"

$parameters = @{"AdminUsername"=$AdminUsername.SecretValue; "AdminPassword"=$AdminPassword.SecretValue; "existingVirtualNetworkName"=$existingVirtualNetworkName; "customScriptFileToRun"=$customScriptFileToRun; "customScriptStorageAccountName"=$customScriptStorageAccountName; "SASToken"="$SASToken"; "VMStorageAccountName"=$VMStorageAccountName; "SyncHours"=$SyncHours; "SyncMinutes"=$SyncMinutes; "workspaceName"=$workspaceName; "workspaceId"=$workspaceId; "workspaceKey"=$workspaceKey }    
$null = New-AzureRmResourceGroupDeployment -Name $VSTSDeploymentName -ResourceGroupName $ResourceGroupName -TemplateFile "$VSTSDeploymentPath\azuredeploy.json" -TemplateParameterObject $parameters -Mode Incremental

Write-output "Deployed to $Region in $ResourceGroupName"
Write-output "Deployment is done !"
