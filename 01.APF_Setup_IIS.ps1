#00 Create Log file
$currentDate = Get-Date
$currentDate = $currentDate.ToString('yyyyMMdd')
$resultLogPath = "$env:USERPROFILE\desktop\IISsetupResult_$currentDate.txt"
Get-Date | Out-File -Append -FilePath $resultLogPath
[System.Net.Dns]::GetHostByName(($env:computerName)) | Format-Table -AutoSize | Out-File -Append -FilePath $resultLogPath


#01 Install Web-Server role
$roleState = (Get-WindowsFeature -Name web-webserver).installed
if ($roleState -eq $false){
    Add-WindowsFeature `
    Application-Server,
    Web-Default-Doc,
    Web-Http-Errors,
    Web-Static-Content,
    Web-Http-Logging,
    Web-Stat-Compression,
    Web-Filtering,
    Web-Windows-Auth,
    Web-Asp-Net45,
    Web-ISAPI-Ext,
    Web-ISAPI-Filter,
    Web-Mgmt-Console
    }


#02 Import parameters from csv
Function Get-FileName($initialDirectory){
[System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
$OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
$OpenFileDialog.initialDirectory = $initialDirectory
$OpenFileDialog.filter = "CSV (*.csv)| *.csv"
$OpenFileDialog.ShowDialog() | Out-Null
$OpenFileDialog.filename
}

$inputfile = Get-FileName "$env:USERPROFILE\desktop"
$fileContent = import-csv $inputfile


#03 create folders
foreach ($item in $fileContent){
$phyPath = $item.phyPath
$logPath = $item.logPath
$userDomain = $item.userDomain
$saUser = $item.saUser

$chk = Test-Path $phyPath
If ($chk -eq $false){
    $IdentityReference = $userDomain + '\' + $saUser    $FileSystemAccessRights = [System.Security.AccessControl.FileSystemRights]”FullControl”    $InheritanceFlags = [System.Security.AccessControl.InheritanceFlags]”ContainerInherit, ObjectInherit”    $PropagationFlags = [System.Security.AccessControl.PropagationFlags]”None”    $AccessControl = [System.Security.AccessControl.AccessControlType]”Allow”    $AccessRule = NEW-OBJECT System.Security.AccessControl.FileSystemAccessRule `    ($IdentityReference,$FileSystemAccessRights,$InheritanceFlags,$PropagationFlags,$AccessControl)    try{    New-Item $phyPath -ItemType directory -Force -ErrorAction stop
    }
    catch{
    $log = "ERROR!:" + $_.Exception.Message
    $log | Out-File -Append -FilePath $resultLogPath
    Break
    }
    $phyPathACL = Get-Acl $phyPath    $phyPathACL.AddAccessRule($AccessRule)    Set-Acl -path $phyPath -AclObject $phyPathACL    $log = "created folder: $phyPath"     $log | Out-File -Append -FilePath $resultLogPath    }$chk = Test-Path $logPathIf ($chk -eq $false){    New-Item $logPath -ItemType directory -Force

    $log = "created folder: $logPath"     $log | Out-File -Append -FilePath $resultLogPath
    }
}


#04. activate WebAdministration function
Import-Module WebAdministration


#05. create application pool
foreach ($item in $fileContent){
$appPoolName = $item.appPoolName
$idType = $item.idType
$userDomain = $item.userDomain
$saUser = $item.saUser
$saPassword = $item.saPassword

$chk = Test-Path IIS:\AppPools\$appPoolNameIf ($chk -eq $false){
    $appPool = New-WebAppPool -Name $appPoolName
    $appPool.processModel.identityType = $idType
    $apppool.processModel.userName = $userDomain + "\" + $saUser
    $appPool.processModel.password = $saPassword
    $appPool | set-Item

    $log = "created application pool: $appPoolName"     $log | Out-File -Append -FilePath $resultLogPath
    }
}


#06 create Website
foreach ($item in $fileContent){
$siteName = $item.siteName
$phyPath = $item.phyPath
$appPoolName = $item.appPoolName
$port = $item.port
$protocol = $item.protocol
$logPath = $item.logPath
$allowUnlisted = $item.allowUnlisted
$ipRange = $item.ipRange
$ipMask = $item.ipMask

$chk = Test-Path IIS:\Sites\$siteNameIf ($chk -eq $false){
    New-Website -Name $siteName -PhysicalPath $phyPath -ApplicationPool $appPoolName
    Get-WebBinding -Name $siteName -port 80 | Remove-WebBinding
    New-WebBinding -Name $siteName -IPAddress "*" -Port $port -Protocol $protocol
    Set-ItemProperty "IIS:\Sites\$($siteName)" -name logFile.directory -value $logPath

    $svrType = $siteName.Contains("api")
    If ($svrType -eq $false){
        Set-WebConfigurationProperty -filter "/system.WebServer/security/authentication/AnonymousAuthentication" `
        -name enabled -value false -PSPath IIS:\ -location $siteName
        Set-WebConfigurationProperty -filter "/system.webServer/security/authentication/windowsAuthentication" `
        -name enabled -value true -PSPath IIS:\ -location $siteName
        }
    Else{
        Set-WebConfigurationProperty -filter “system.webServer/security/access” `
        -name “sslFlags” -value “Ssl,SslNegotiateCert,SslRequireCert” -PSPath IIS:\ -location $siteName
        }
        $log = "created web site: $siteName"     $log | Out-File -Append -FilePath $resultLogPath
    }
}

#07 Export IIS setting
$log = "`r`n########## Current IIS settings ##########" $log | Out-File -Append -FilePath $resultLogPath
get-item IIS:\AppPools\* | Format-Table -AutoSize | Out-File -Append -FilePath $resultLogPath
get-item IIS:\Sites\* | Sort-Object ID | Format-Table -AutoSize | Out-File -Append -FilePath $resultLogPath
Get-WindowsFeature *web* | Out-File -Append -FilePath $resultLogPath
