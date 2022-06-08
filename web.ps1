# Load config:
$run = "true"
# Write PID of current process for killtask
write-host "PID: " + $PID
# Load config
$configJson = Get-Content "config/program_config.json"
# Convert to object
$config = $configJson |ConvertFrom-Json
$NumberOfModules = $config | Select-Object -ExpandProperty "NumberOfModules"

$installedDependencies = $false
function InstallDependencies {
    write-host "INSTALLING MODULES!" -f "black" -b "blue"
    if ($installedDependencies -ne $true) {
        # Check version:
        $ver = Get-Host | Select-Object Version
        if("@{Version=5.1.19041.1682}" -eq $ver) {
            write-host "Your PowerShell version: $ver" -f "black" -b "green"
            write-host "You are running the same version of PowerShell on which this was developed!" -f "black" -b "green"
        } else {
            write-host "Your PowerShell version: $ver" -f "black" -b "red"
            write-host "This webpage is built on 5.1.19041.1682 and most likely will not work on different versions!" -f "black" -b "red"
        }
        # Install dependencies:
        write-host "INSTALLING MODULES!" -f "black" -b "yellow"
        for ($i = 0; $i -lt $NumberOfModules; $i++) {
            $string = "$i> " + $config.modules.$i
            Install-Module $config.modules.$i
            write-host $string -f "black" -b "green"
        }
        # Update downloaded modules:
        write-host "UPDATING EXISTING MODULES!" -f "black" -b "yellow"
        Update-Module
        # Update help menu:
        write-host "UPADATING HELP MENU!" -f "black" -b "yellow"
        Update-Help
        $installedDependencies = $true
        LoadDependencies
    }
}
function  LoadDependencies{
    # Documentation: https://github.com/mithrandyr/SimplySql/blob/master/README.md
    # https://docs.microsoft.com/en-us/powershell/module/sqlps/invoke-sqlcmd?view=sqlserver-ps
    # Tries to import modules and if it throws error then it tries to install them
    write-host "LOADING MODULES!" -f "black" -b "blue"
    for ($i = 0; $i -lt $NumberOfModules; $i++) {
        $string = "$i> " + $config.modules.$i
        if (Get-Module -ListAvailable -Name $config.modules.$i) {
            Import-Module $config.modules.$i
            write-host $string -f "black" -b "green"
        } else {
            write-host "$string NOT FOUND!" -f "black" -b "red"
            InstallDependencies
        }
    }
}

LoadDependencies

# Config server
$ip = $config | Select-Object -ExpandProperty "ip"
$port = $config | Select-Object -ExpandProperty "port"
# Config database login
$db_user = $config.database_credentials | Select-Object -ExpandProperty "user"
$db_password = $config.database_credentials | Select-Object -ExpandProperty "password"
$db_database = $config.database_credentials | Select-Object -ExpandProperty "database"
$db_server = $config.database_credentials | Select-Object -ExpandProperty "server"
$db_port = $config.database_credentials | Select-Object -ExpandProperty "port"

# Http Server
$http = [System.Net.HttpListener]::new()
# Hostname and port to listen on
$http.Prefixes.Add("http://" + $ip + ":" + $port + "/")
# Start the Http Server 
$http.Start()

# Functions must be declared BEFORE using them
# Stupidly complicated serving of websites XD
function GetCSS {
    param ($RawUrl)
    $location = $config.$RawUrl | Select-Object -ExpandProperty "css"
    $rawCSS = Get-Content -Raw $location
    $css = "<style>" + $rawCSS + "</style>"
    return $css
}

function GetHTML {
    param ($RawUrl)
    $location = $config.$RawUrl | Select-Object -ExpandProperty "html"
    $rawHTML = Get-Content -Raw $location
    return $rawHTML
}

function GetWebsite {
    param ($RawUrl)
    [string]$rawHTML = GetHTML -RawUrl $context.Request.RawUrl
    [string]$rawCSS = GetCSS -RawUrl $context.Request.RawUrl
    [string]$html = $rawCSS + $rawHTML
    return $html
}

function SendHTML() {
    param(
        $RawUrl,
        $context
    )

    # the html/data you want to send to the browser
    # you could replace this with: [string]$html = Get-Content "C:\some\path\index.html" -Raw
    [string]$html = GetWebsite -RawUrl $context.Request.RawUrl
    #respond to the request
    $buffer = [System.Text.Encoding]::UTF8.GetBytes($html) # convert htmtl to bytes
    $context.Response.ContentLength64 = $buffer.Length
    $context.Response.OutputStream.Write($buffer, 0, $buffer.Length) #stream to broswer
    $context.Response.OutputStream.Close() # close the response
}

function RunSQLQuery {
    param($Query)
    Open-MySQLConnection -Server "$db_server"  -Port "$db_port" -Credential "$db_user" -Database "$db_database"
    Invoke-SqlQuery -query "$Query"
    Close-SqlConnection
    #try {
    #    Open-MySQLConnection -Server "$db_server"  -Port "$db_port" -Credential "$db_user" -Database "$db_database"
    #    Invoke-SqlQuery -query "$Query"
    #    Close-SqlConnection
    #} catch {
    #    {1:"RunSQLQuery error !"}
    #}
}

function GetDataFromSQLQuery {
    param($Query)
    Open-MySQLConnection -Server "$db_server"  -Port "$db_port" -Credential "$db_user" -Database "$db_database"
    $data = Invoke-SqlQuery -query $Query -Parameters @{var = 'a value'}
    Close-SqlConnection
    return $data
    #try {
    #    param($Query)
    #    Open-MySQLConnection -Server "$db_server"  -Port "$db_port" -Credential "$db_user" -Database "$db_database"
    #    $data = Invoke-SqlQuery -query $Query -Parameters @{var = 'a value'}
    #    Close-SqlConnection
    #    return $data
    #} catch {
    #    {1:"GetDataFromSQLQuery error !"}
    #}
}

RunSQLQuery -Query "Select * FROM `users` "

# Log ready message to terminal 
if ($run -eq "true") {
    write-host "HTTP Server started on "$ip":"$port"!" -f 'black' -b 'gre'
#    write-host "now try going to $($http.Prefixes)" -f 'y'
#    write-host "then try going to $($http.Prefixes)other/path" -f 'y'
}

# INFINTE LOOP
while ($run -eq "true") {
    # Get Request Url
    # When a request is made in a web browser the GetContext() method will return a request object
    # Our route examples below will use the request object properties to decide how to respond
    $context = $http.GetContext()
    if ($context.Request.HttpMethod -eq 'GET' -and $context.Request.RawUrl -eq '/') {
        # We can log the request to the terminal
        write-host "$($context.Request.UserHostAddress)  =>  $($context.Request.Url)" -f 'mag'
        SendHTML -RawUrl $context.Request.RawUrl -context $context
    }

    if ($context.Request.HttpMethod -eq 'POST' -and $context.Request.RawUrl -eq '/database') {
        # decode the form post
        # html form members need 'name' attributes as in the example!
        $FormContent = [System.IO.StreamReader]::new($context.Request.InputStream).ReadToEnd()

        # We can log the request to the terminal
        write-host "$($context.Request.UserHostAddress)  =>  $($context.Request.Url)" -f 'mag'
        Write-Host $FormContent -f 'Green'
        SendHTML -RawUrl $context.Request.RawUrl -context $context
    }

    # Kill server remotely :)
    if ($context.Request.HttpMethod -eq 'GET' -and $context.Request.RawUrl -eq '/taskkill') {
        write-host "$($context.Request.UserHostAddress)  =>  $($context.Request.Url)" -f 'mag'
        Write-Host $FormContent -f 'Green'
        $run = "false"
        $context.Response.OutputStream.Close()
    }
} 

# Kill self
Stop-Process $PID