# ───── ❝ STARTUP ❞ ─────
# Load config:
$run = "true"
# Write PID of current process for killtask
write-host "PID: " + $PID
# Load config
$configJson = Get-Content "config/program_config.json"
# Convert to object
$config = $configJson |ConvertFrom-Json
$NumberOfModules = $config | Select-Object -ExpandProperty "NumberOfModules"

# ───── ❝ DEPENDENCIES / MODULES ❞ ─────
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

# ───── ❝ WEB SERVER START ❞ ─────
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

# ───── ❝ FUNCTIONS ❞ ─────
# ───── ❝ WEBSITE - HTML - CSS❞ ─────
# Functions must be declared BEFORE using them
# Stupidly complicated serving of websites XD
function GetJS {
    param ($RawUrl)
    $location = $config.$RawUrl | Select-Object -ExpandProperty "js"
    if ($location -ne "") {
        $rawJS = Get-Content -Raw $location
        $js = "<script>" + $rawJS + "</script>"
        return $js
    } else {
        return ""
    }
}

function GetCSS {
    param ($RawUrl)
    $location = $config.$RawUrl | Select-Object -ExpandProperty "css"
    if ($location -ne "") {
        $rawCSS = Get-Content -Raw $location
        $css = "<style>" + $rawCSS + "</style>"
        return $css
    } else {
        return ""
    }
}

function GetHTML {
    param ($RawUrl)
    if ($location -ne "") {
        $location = $config.$RawUrl | Select-Object -ExpandProperty "html"
        $rawHTML = Get-Content -Raw $location
        return $rawHTML
    } else {
        return ""
    }
}

function GetWebsite {
    param ($RawUrl)
    [string]$rawHTML = GetHTML -RawUrl $context.Request.RawUrl
    [string]$rawCSS = GetCSS -RawUrl $context.Request.RawUrl
    [string]$rawJS = GetJS -RawUrl $context.Request.RawUrl
    [string]$html = $rawCSS + $rawHTML + $rawJS
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

# ───── ❝ MYSQL DATABASE ❞ ─────
# Open MySQL connection and ask user for a certificate:
# FIXME do not ask user for a certificate when it IS in the json file!
Open-MySQLConnection -Server "$db_server"  -Port "$db_port" -Credential "$db_user" -Database "$db_database"
function RunSQLQuery {
    param($Query)
    try {
        #Open-MySQLConnection -Server "$db_server"  -Port "$db_port" -Credential "$db_user" -Database "$db_database"
        Invoke-SqlQuery -query "$Query"
        #Close-SqlConnection
    } catch {
        write-host "[RunSQLQuery] ERROR! Query: [$Query]" -f "black" -b "red"
    }
}

function GetDataFromSQLQuery {
    param($Query)
    try {
        #Open-MySQLConnection -Server "$db_server"  -Port "$db_port" -Credential "$db_user" -Database "$db_database"
        $data = Invoke-SqlQuery -query $Query -Parameters @{var = 'a value'}
        #Close-SqlConnection
        return $data
    } catch {
        write-host "[GetDataFromQuery] ERROR! Query: [$Query]" -f "black" -b "red"
    }
}
# ───── ❝ DATABASE INTERACTIONS ❞ ─────
function AttemptLogin {
    param($FormContent)
    
    # Get username from form:
    $Regex = [Regex]::new("(?<=username=)(.*)(?=&password)")           
    $Match = $Regex.Match($FormContent)           
    if($Match.Success) {           
        $username = $Match.Value           
    }
    
    # Get password from form:
    $Regex = [Regex]::new("(?<=&password=)(.*)")
    $Match = $Regex.Match($FormContent)           
    if($Match.Success) {           
        $password = $Match.Value           
    }

    # Check if password is correct:
    $passwordFromDatabase = GetDataFromSQLQuery -Query "SELECT PASSWORD FROM `users` WHERE USERNAME = '$username';"
    write-host "User: $username Password: $password PasswordFromDB: " $passwordFromDatabase.Item("PASSWORD") "FormContent: $FormContent"
    if($password -eq $passwordFromDatabase.Item("PASSWORD")) {
        write-host "User $username logged in!" -f "black" -b "green"
        return $true
    } else {
        write-host "Unsuccessful login attempt for user $username!" -f "black" -b "red"
        return $false
    }
}

# ───── ❝ DATABASE.html BACK-END MAGIC ❞ ─────
function GetDatabaseHTML {
    param ($RawUrl)
    if ($location -ne "") {
        # Get database HTML and split it into an array
        $location = $config.$RawUrl | Select-Object -ExpandProperty "html"
        $rawHTML = Get-Content -Raw $location
        $HTML_Parts = "", ""
        # Get part one:
        $Regex = [Regex]::new("((?:.*?\n)*)<!--INSERT_DATABASE_HERE-->")
        $Match = $Regex.Match($rawHTML)           
        if($Match.Success) {           
            $HTML_Parts[0] = $Match.Value   
        }
        # Get part two:
        $Regex = [Regex]::new("<!--INSERT_DATABASE_HERE-->((?:.*?\n)*)")
        $Match = $Regex.Match($rawHTML)           
        if($Match.Success) {           
            $HTML_Parts[1] = $Match.Value      
        }
        # Get data from database and insert it into the HTML
        $data = GetDataFromSQLQuery -Query "SELECT * FROM `computers`;"
        $data_html = ""
        foreach($row in $data) {
            $ID_CLASS = $row.Item("ID_CLASS")
            $ID_PC = $row.Item("ID_PC")
            $IS_FROZEN = $row.Item("IS_FROZEN")
            $INSTALLATION_DATE = $row.Item("INSTALLATION_DATE")
            $INSTALLED_SOFTWARE = $row.Item("INSTALLED_SOFTWARE")
            
            $data_html += "    <tbody>    <tr>        <td>            <span class=`"custom-checkbox`">                <input type=`"checkbox`" id=`"checkbox1`" name=`"options[]`" value=`"1`">                <label for=`"checkbox1`"></label>            </span>        </td>        <td>" + $ID_CLASS + "</td>        <td>" + $ID_PC + "</td>        <td>" + $IS_FROZEN + "</td>        <td>" + $INSTALLATION_DATE + "</td>        <td>" + $INSTALLED_SOFTWARE + "</td>        <td>            <a href=`"#editEntryModal`" class=`"edit`" data-toggle=`"modal`"><i class=`"material-icons`" data-toggle=`"tooltip`" title=`"Edit`">&#xE254;</i></a>            <a href=`"#deleteEntryModal`" class=`"delete`" data-toggle=`"modal`"><i class=`"material-icons`" data-toggle=`"tooltip`" title=`"Delete`">&#xE872;</i></a>        </td>    </tr></tbody>"
        }
        $fullDatabaseHTML = $HTML_Parts[0] + $data_html + $HTML_Parts[1]
        return $fullDatabaseHTML
    } else {
        return ""
    }
}

function GetDatabaseWebsite {
    param ($RawUrl)
    [string]$rawJS = GetJS -RawUrl $context.Request.RawUrl
    [string]$rawCSS = GetCSS -RawUrl $context.Request.RawUrl
    [string]$rawHTML = GetDatabaseHTML -RawUrl $context.Request.RawUrl
    [string]$html = $rawCSS + $rawHTML + $rawJS
    return $html
}

function SendDatabaseHTML {
    param(
        $RawUrl,
        $context
    )

    # the html/data you want to send to the browser
    # you could replace this with: [string]$html = Get-Content "C:\some\path\index.html" -Raw
    [string]$html = GetDatabaseWebsite -RawUrl $context.Request.RawUrl
    #respond to the request
    $buffer = [System.Text.Encoding]::UTF8.GetBytes($html) # convert htmtl to bytes
    $context.Response.ContentLength64 = $buffer.Length
    $context.Response.OutputStream.Write($buffer, 0, $buffer.Length) #stream to broswer
    $context.Response.OutputStream.Close()
}

# ───── ❝ HANDLE WEB REQUESTS ❞ ─────
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
        #Write-Host $FormContent -f 'yellow'
        if(AttemptLogin -FormContent $FormContent) {
            #SendHTML -RawUrl $context.Request.RawUrl -context $context
            SendDatabaseHTML -RawUrl $context.Request.RawUrl -context $context
        }
    }
    
    #TODO: Make database.html work with POST ... it should be able to add new entries to the database and update existing entries (if the user has permission)
    #TODO: Make database.html work with DELETE
    #TODO: Add permissions to the database.html page
    #TODO: Add permissions to users database

    # Kill server remotely :)
    if ($context.Request.HttpMethod -eq 'GET' -and $context.Request.RawUrl -eq '/taskkill') {
        write-host "$($context.Request.UserHostAddress)  =>  $($context.Request.Url)" -f 'mag'
        Write-Host $FormContent -f 'Green'
        $run = "false"
        $context.Response.OutputStream.Close()
    }
} 

# ───── ❝ EOF ❞ ─────
# Close SQL connection:
Close-SqlConnection
# Kill self:
Stop-Process $PID