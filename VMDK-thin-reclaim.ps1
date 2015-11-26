# Path to SDelete and command to exectue
$PathToSDelete ="C:\Windows\sdelete.exe"
$SDeleteCommand = "sdelete -z c"

# vCenter Server
# I recommend to create a new VICredentialStoreItem and use this to connect to the vCenter Server
$VIServer = "vcsa1.lab.local"

# To create an encrypted password file, execute the following command
# Read-Host -AsSecureString | ConvertFrom-SecureString | Out-File securestring.txt
# Fill $CredFile with path to securesting.txt 

$CredFile = "C:\Users\Administrator\securestring.txt"
$Password = (Get-Content $CredFile | ConvertTo-SecureString)
$Cred = New-Object System.Management.Automation.PSCredential ("VCLOUDLAB\Administrator", $Password)

# Set destination host
$DstDS = "ESX4-LOCAL"

# Name of vSphere Cluster
$ClusterName = "Lab"

# Connect to vCenter Server
Connect-VIServer $VIServer | Out-Null

# Build an array with all Windows VMs
# $SrcVM = (Get-Cluster $ClusterName | Get-VM | Where {$_.Guest.OSFullName -like "*Windows*"})

# Run only for specific VM
$SrcVM = (Get-VM | Where {$_.Name -like "client2"})

# For every object in the array...
$SrcVM | ForEach-Object {
    
    # Set source datastore
    $SrcDS = ((Get-HardDisk $_).Filename).Split('[')[1].Split(']')[0]
    
    # Set source diskformat
    $DiskFormat = ((Get-HardDisk $_).StorageFormat | select -uniq)
    
    # Set source host
    $SrcHost = (Get-VM $_ | Get-VMHost).name
           
    # Initiate new PSSession
    $RemotePSSession = New-PSSession -ComputerName $_.Guest.HostName -Credential $Cred
    
    # Test if SDelete exist. If yes, zero-out the disk c:
    $ExitCodeInvokeCommand = Invoke-Command -Session $RemotePSSession -argumentlist $PathToSDelete, $SDeleteCommand -ScriptBlock {
        
        # Test for SDelete and run SDelete
        If (Test-Path $args[0]) {
            
            cmd /c "$args[1]" | Out-Null
            $ErrorCode = 0
            
        }Else{
            $ErrorCode = 1
        }; $ErrorCode
    }
    
    # If SDelete was found and zero-out has completed, move VM to $DstDS and then back to $SrcDS and $SrcHost
    
    If ($ExitCodeInvokeCommand -eq 0) {
        
        # Use Move-VM to SvMotion a VM to the destination datastore using the original DiskStorageFormat
        Move-VM -VM $_ -Datastore $DstDS -DiskStorageFormat $DiskFormat | Out-Null
        
        # Use Move-VM to SvMotion a VM back to the original datastore using the original DiskStorageFormat
        Move-VM -VM $_ -Destination $SrcHost -Datastore $SrcDS -DiskStorageFormat $DiskFormat | Out-Null
        
    }
    
    # If $ExitCodeInvokeCommand -eq 1, something has failed. Skip this VM.
    
    elseif ($ExitCodeInvokeCommand -eq 1) {
        
        Write-Output "SDelete was not found. Skipping this VM"
        
    }
    
}

# Disconnect from vCenter Server
Disconnect-VIServer $VIServer | Out-Null