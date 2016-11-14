#00 Create Log file
$currentDate = Get-Date
$currentDate = $currentDate.ToString('yyyyMMdd')
$resultLogPath = "$env:USERPROFILE\desktop\IISremoveResult_$currentDate.txt"
Get-Date | Out-File -Append -FilePath $resultLogPath
[System.Net.Dns]::GetHostByName(($env:computerName)) | Format-Table -AutoSize | Out-File -Append -FilePath $resultLogPath


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


#03 delete folders
foreach ($item in $fileContent){
$phyPath = $item.phyPath
$logPath = $item.logPath
$userDomain = $item.userDomain
$saUser = $item.saUser

$chk = Test-Path $phyPath
If ($chk -eq $True){    Remove-Item $phyPath -Force -Recurse
    $log = "deleted folder: $phyPath"     $log | Out-File -Append -FilePath $resultLogPath    }
}


#04. activate WebAdministration function
Import-Module WebAdministration


#05. delete application pool
foreach ($item in $fileContent){
$appPoolName = $item.appPoolName
$idType = $item.idType
$userDomain = $item.userDomain
$saUser = $item.saUser
$saPassword = $item.saPassword

$chk = Test-Path IIS:\AppPools\$appPoolNameIf ($chk -eq $True){
    Remove-Item IIS:\AppPools\$appPoolName -Recurse

    $log = "deleted application pool: $appPoolName"     $log | Out-File -Append -FilePath $resultLogPath
    }
}


#06 delete Website
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

$chk = Test-Path IIS:\Sites\$siteNameIf ($chk -eq $True){
    Remove-Item IIS:\Sites\$siteName -Recurse
        $log = "deleted web site: $siteName"     $log | Out-File -Append -FilePath $resultLogPath
    }
}

#07 Export IIS setting
$log = "`r`n########## Current IIS settings ##########" $log | Out-File -Append -FilePath $resultLogPath
get-item IIS:\AppPools\* | Format-Table -AutoSize | Out-File -Append -FilePath $resultLogPath
get-item IIS:\Sites\* | Sort-Object ID | Format-Table -AutoSize | Out-File -Append -FilePath $resultLogPath
Get-WindowsFeature *web* | Out-File -Append -FilePath $resultLogPath

<#
#01 remove Web-Server role
$roleState = (Get-WindowsFeature -Name web-webserver).installed
if ($roleState -eq $True){
    Remove-WindowsFeature `
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
#>