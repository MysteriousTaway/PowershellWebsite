# Start
$run = "true"
# Write PID of current process for killtask
write-host "PID: " + $PID
# Load config
$configJson = Get-Content "config/program_config.json"
# Convert to object
$config = $configJson | ConvertFrom-Json
# Data
$ip = $config | Select-Object -ExpandProperty "ip"
$port = $config | Select-Object -ExpandProperty "port"
# Http Server
$http = [System.Net.HttpListener]::new() 
# Hostname and port to listen on
$http.Prefixes.Add("http://" + $ip + ":" + $port + "/")
# Start the Http Server 
$http.Start()
# Log ready message to terminal 
if ($run -eq "true") {
    write-host " HTTP Server Ready!  " -f 'black' -b 'gre'
#    write-host "now try going to $($http.Prefixes)" -f 'y'
#    write-host "then try going to $($http.Prefixes)other/path" -f 'y'
}


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

# INFINTE LOOP
while ($run -eq "true") {
    # Get Request Url
    # When a request is made in a web browser the GetContext() method will return a request object
    # Our route examples below will use the request object properties to decide how to respond
    $context = $http.GetContext()
    if ($context.Request.HttpMethod -eq 'GET' -and $context.Request.RawUrl -eq '/') {

        # We can log the request to the terminal
        write-host "$($context.Request.UserHostAddress)  =>  $($context.Request.Url)" -f 'mag'

        # the html/data you want to send to the browser
        # you could replace this with: [string]$html = Get-Content "C:\some\path\index.html" -Raw
        [string]$html = GetWebsite -RawUrl $context.Request.RawUrl
        #respond to the request
        $buffer = [System.Text.Encoding]::UTF8.GetBytes($html) # convert htmtl to bytes
        $context.Response.ContentLength64 = $buffer.Length
        $context.Response.OutputStream.Write($buffer, 0, $buffer.Length) #stream to broswer
        $context.Response.OutputStream.Close() # close the response
    }

    if ($context.Request.HttpMethod -eq 'POST' -and $context.Request.RawUrl -eq '/database') {
        # decode the form post
        # html form members need 'name' attributes as in the example!
        $FormContent = [System.IO.StreamReader]::new($context.Request.InputStream).ReadToEnd()

        # We can log the request to the terminal
        write-host "$($context.Request.UserHostAddress)  =>  $($context.Request.Url)" -f 'mag'
        Write-Host $FormContent -f 'Green'

        # the html/data
        [string]$html = GetWebsite -RawUrl $context.Request.RawUrl

        # respond to the request
        $buffer = [System.Text.Encoding]::UTF8.GetBytes($html)
        $context.Response.ContentLength64 = $buffer.Length
        $context.Response.OutputStream.Write($buffer, 0, $buffer.Length)
        $context.Response.OutputStream.Close() 
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