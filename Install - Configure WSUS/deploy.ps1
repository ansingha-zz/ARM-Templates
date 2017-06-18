<#
.SYNOPSIS
    Provision a VM with WSUS role

.DESCRIPTION
    Provisions a VM , adds a 500 GB data disk and installs WSUS role

.Parameter $subscriptionId
    Provide the Azure Subscription Id where WSUS VM will be deployed
  
.Parameter $Region
    Provide Region where WSUS VM will be deployed

.Parameter $ExistingVirtualNetworkName
    Provide the existing Virtual Network names

.Parameter $customScriptFileToRun
    Example: InstallWSUS.ps1

.Parameter $customScriptStorageAccountName
    Provide the storage account name where the custom script file is stored

.Parameter $customScriptStorageAccountNamesResourceGroup
    Provide the Resource Groups Names of the storage accounts where custom scripts are uploaded

.Parameter $keyVaultName
    Provide the Key Vault name that exists in the other subscription

.Parameter $managementSubscriptionId
    Provide the Azure Subscription Id for the Key Vault

.Parameter $CSEContainerName
    Provide the Container name where CustomScriptExtension scripts are uploaded

.PARAMETER $Tags
    Tag values for Resource Group

.Parameter $ResourceGroupName
    Provide name of the existing Resource Group which have the existing VNets

.Parameter $VMStorageAccountName
	Name of Azure Storage Account associated with the VM

.Parameter $VSTSDeploymentPath
    Provide the VSTS Deployment Path for JSON templates

.Parameter $VSTSDeploymentName
    Provide the Name for Template Deployment

.Parameter $SyncHours
    The schedule for the daily sync

.Parameter $SyncMinutes
    The schedule for the daily sync

.Parameter $workspaceName
    OMS Workspace

.Parameter $workspaceResourceGroup
    OMS Workspace Resource Group
)
#>

param(
[Parameter(Mandatory=$True, HelpMessage="Provide the Azure Subscription Id where WSUS VM will be deployed")]
[string]
$subscriptionId,
  
[validateset("EN","UW" )]
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

[Parameter(Mandatory=$True, HelpMessage="Provide the Key Vault name that exists in the other subscription")]
[string]
$keyVaultName,

[Parameter(Mandatory=$True, HelpMessage="Provide the Azure Subscription Id for the Key Vault")]
[string]
$managementSubscriptionId,

[Parameter(Mandatory=$True, HelpMessage="Provide the Container name where CustomScriptExtension script is uploaded")]
[string]
$CSEContainerName,

[Parameter(Mandatory=$True)]
[PSCustomObject]
$Tags,

[Parameter(Mandatory=$True, HelpMessage="Provide name of the existing Resource Group which have the existing VNets
[string]
$ResourceGroupName,

[Parameter(Mandatory=$True, HelpMessage="Provide the Name of Azure Storage Account associated with the VM")]
[string]
$VMStorageAccountName,

[Parameter(Mandatory=$True, HelpMessage="Provide the VSTS Deployment Path for JSON templates")]
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
Log-Information "Selecting Management Subscription: '$managementSubscriptionId'";
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
Log-Information "Selecting the subscription to create the VM: '$subscriptionId'";
Set-AzureRmContext -SubscriptionID $subscriptionId;
    
    $Location = ConvertFrom-RegionCode $Region

Ensure-ResourceGroup -ResourceGroupName $ResourceGroupName -Location $Location -Tags $Tags

#Deploy the Template to the Resource Group
Log-Information "Deploying to $Location in $ResourceGroupName"


$parameters = @{"AdminUsername"=$AdminUsername.SecretValue; "AdminPassword"=$AdminPassword.SecretValue; "region"=$region; "existingVirtualNetworkName"=$existingVirtualNetworkName; "customScriptFileToRun"=$customScriptFileToRun; "customScriptStorageAccountName"=$customScriptStorageAccountName; "SASToken"="$SASToken"; "VMStorageAccountName"=$VMStorageAccountName; "SyncHours"=$SyncHours; "SyncMinutes"=$SyncMinutes; "workspaceName"=$workspaceName; "workspaceId"=$workspaceId; "workspaceKey"=$workspaceKey }    
$null = New-AzureRmResourceGroupDeployment -Name $VSTSDeploymentName -ResourceGroupName $ResourceGroupName -TemplateFile "$VSTSDeploymentPath\azuredeploy.json" -TemplateParameterObject $parameters -Mode Incremental
Log-Information "Deployed to $Location in $ResourceGroupName"
Log-Information "Deployment is done !"
