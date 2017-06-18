### Provision VM with WSUS role


This is a template to provision a new Azure VM with WSUS role using 'custom script extension' in a pre-existing VNet.
•	VM Size: Standard D1 v2

•	It has a single NIC

•	Naming format for NIC is: <VM_name>-NIC01

•	It does not have a public IP address

•	Its connected to pre-provisioned VNET

•	Availability Set is also created and VM is associated with it

•	Not using Managed Disk

•	Additional Data Disk of 500GB size

•	The disk is initialized using the ‘custom script extension’:
        Disk Label: WSUS
        
•	A folder is created with the following name in the data disk for WSUS content: WSUSContent

•	The VM is also connected to an OMS workspace

•	The OMS Workspace and the Key Vault exist in a different Subscription

•	The VM's Username and Password are stored in the Key Vault

•	The 'Custom Script Extension' PowerShell file is stored in a Block Blob in a dedicated storage account




