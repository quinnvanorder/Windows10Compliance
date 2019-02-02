# Gateway, IsBDR, Root directory, Target space threshold, Target build
##############################################################################################################
############################################### Arguments ####################################################
##############################################################################################################
$Global:Gateway = ""
[String]$Global:Gateway = $args[0]
$Global:IsBDR = ""
[String]$Global:IsBDR = $args[1]
$Global:Root = ""
[String]$Global:Root = $args[2]
$Global:SpaceTarget = ""
$Global:SpaceTarget = $args[3]
$Global:BuildTarget = ""
$Global:BuildTarget = $args[4]
##############################################################################################################
############################################# End Arguments ##################################################
##############################################################################################################





##############################################################################################################
############################################## Variables #####################################################
##############################################################################################################
#Component file references
$Global:LogFile = $Global:Root + '\Logs.txt'
$Global:StatusFile = $Global:Root + '\Status.txt'
$Global:CheckFile = $Global:Root + '\Files.csv'
$Global:GatewaysTxt = $Global:Root + '\Gateways.txt'
$Global:Extraction = $Global:Root + '\Extraction.zip'


#Directories
$Global:DirISO = $Global:Root + '\ISO'
$Global:DirStaging = $Global:Root + '\Staging'
$Global:DirExtraction = $Global:Root + '\Extraction'
$Global:Unpack = $Global:Root + '\Unpack' #Never referenced within this script other than to delete if present assuming machine is at the target build. That directory is where the ISO is unpacked to for the upgrade. 


#Arrays
$Global:Checks = @() #Array of check values, including file name, hash, and download url
$Global:Gateways = @() #If machine gateway is contained within the gateways file this array is populated, otherwise it is not needed
$Global:StagingFiles = @() #Contains all files within staging directory
$Global:Remain = @() #List of missing files within staging

#Other, mostly declared here, and enumerated in the prep stage
$Global:ISOName = '' #Extracts name of ISO file from checks file. By not hardcoding this, it insulates against variable name ISO's used in future
$Global:ISO = '' #Full path to ISO
$Global:Expected = '' #List of expected files in staging
$Global:Present = '' #List of files present within staging
$Global:User = "ISOGrabber"
$Global:Password = "UniquePassword"
$Global:Extractor = $Global:DirExtraction + '\7z.exe'

##############################################################################################################
############################################# End Variables ##################################################
##############################################################################################################





##############################################################################################################
############################################### Functions ####################################################
##############################################################################################################
Function Prep #Error checking, directory creation, variable enumeration
{
    #Free space check, terminates on failure
    $a = ((get-psdrive c | Select-Object -ExpandProperty free) /1GB); $a = [math]::Round($a)
    If($a -gt $Global:SpaceTarget)
    {
        $Output = $a.ToString() + 'gb free with a min threshold of ' + $Global:SpaceTarget.ToString() + 'gb. Space check passed.'; [string]$Date = Get-Date; $Output = $Date + " - " + $Output; Write-Output $Output >> $Global:LogFile
    }
    Else
    {
        $Output = $a.ToString() + 'gb free with a min threshold of ' + $Global:SpaceTarget.ToString() + 'gb. Space check failed, terminating.'; [string]$Date = Get-Date; $Output = $Date + " - " + $Output; Write-Output $Output >> $Global:LogFile
        If(test-path $Global:StatusFile) {Remove-Item $Global:StatusFile -Force}; [string]$Date = Get-Date -UFormat %y-%m-%d; $Output = $Date + ': ' + 'ERR: ' + $a.ToString() + 'GB free'; Write-Output $Output >> $Global:StatusFile  
        Exit
    }

    #Critical component checks, terminates on failure
    If(!(test-path $Global:CheckFile))
    {
          $Output = 'FAILURE - Check file missing'; [string]$Date = Get-Date; $Output = $Date + " - " + $Output; Write-Output $Output >> $Global:LogFile
          If(test-path $Global:StatusFile) {Remove-Item $Global:StatusFile -Force}; [string]$Date = Get-Date -UFormat %y-%m-%d; $Output = $Date + ': ' + 'ERR: check file missing'; Write-Output $Output >> $Global:StatusFile  
          Exit
    }
    Else
    {
        #Populate variables that require data from the checks file
        $Global:Checks = import-csv $Global:CheckFile
        $Global:ISOName = $Global:Checks.Name -like '*ISO*' 
        $Global:ISO = $Global:DirISO + '\' + $Global:ISOName 

    }
    
    If ($Global:IsBDR -eq "0")
    {
        If(!(test-path $Global:GatewaysTxt))
        {
              $Output = 'FAILURE - Gateways file missing'; [string]$Date = Get-Date; $Output = $Date + " - " + $Output; Write-Output $Output >> $Global:LogFile
              If(test-path $Global:StatusFile) {Remove-Item $Global:StatusFile -Force}; [string]$Date = Get-Date -UFormat %y-%m-%d; $Output = $Date + ': ' + 'ERR: gateways file missing'; Write-Output $Output >> $Global:StatusFile  
              Exit
        }
    }
      
    
    #Path creation checks
    If(!(test-path $Global:DirISO))
    {
          $Output = 'Creating ' + $Global:DirISO; [string]$Date = Get-Date; $Output = $Date + " - " + $Output; Write-Output $Output >> $Global:LogFile
          New-Item -ItemType Directory -Force -Path $Global:DirISO
    }
   
    If(!(test-path $Global:DirStaging))
    {
          $Output = 'Creating ' + $Global:DirStaging; [string]$Date = Get-Date; $Output = $Date + " - " + $Output; Write-Output $Output >> $Global:LogFile
          New-Item -ItemType Directory -Force -Path $Global:DirStaging
    }
    $Global:StagingFiles = @(Get-ChildItem -Path $Global:DirStaging) | select -expand Name

}

Function EnumerateGateways #If machine gateway is contained withing gateways.txt file, array is built
{
    $Input = [IO.File]::ReadAllText($Global:GatewaysTxt)
    if ($Input -like "*$Global:Gateway*")
    {
        $Strings = ''
        $Strings = $Input.split("+")
        foreach ($String in $Strings)
        {
            $Global:Gateways += ,@($String -split ',')
        }   
    }
}

Function RewriteDropbox #Dropbox url's by default open to a page where the download can be initiated. They must be rewritten to download directly
{
    for ($a=0;$a -lt $Global:Checks.length; $a++)
    {
    $b = $Global:Checks[$a].URL
    $b = $b -replace "dl=0", "dl=1"
    $Global:Checks[$a].URL = $b
    }
}

Function BDR #Shares ISO directory, creates local user to access share
{
    If ($Global:IsBDR -eq "1")
    {
        $Output = 'Beginning BDR setup tasks'; [string]$Date = Get-Date; $Output = $Date + " - " + $Output; Write-Output $Output >> $Global:LogFile
        
        #Create share user
        $Command = "net user " + "$Global:User" + " " + "$Global:Password" + " /add /Y" 
        try
        {
            $er = (invoke-expression $Command) 2>&1
	        if ($lastexitcode) {throw $er}
            $Output = 'Local user account created'; [string]$Date = Get-Date; $Output = $Date + " - " + $Output; Write-Output $Output >> $Global:LogFile
        }
        catch
        {
            $Output = ($_.FullyQualifiedErrorId -split '\.')[0] ; [string]$Date = Get-Date; $Output = $Date + " - " + $Output; Write-Output $Output >> $Global:LogFile
        }
        
        #Set user's password to never expire
        $Command = "wmic useraccount WHERE `"Name=`'" + $Global:User + "`'`" set PasswordExpires=false"
        invoke-expression $Command

        #Assign perms to the ISO directory
        $PERMS = "$Global:User" + ":(OI)(CI)(RX)"
        icacls.exe "$Global:DirISO" /grant "$PERMS"
        $Output = 'ISO dir permissions assigned'; [string]$Date = Get-Date; $Output = $Date + " - " + $Output; Write-Output $Output >> $Global:LogFile
        
        #Share ISO directory
        $Command = "Net Share Win10=" + "$Global:DirISO"
        try
        {
            $er = (invoke-expression $Command) 2>&1
	        if ($lastexitcode) {throw $er}
            $Output = 'ISO directory shared'; [string]$Date = Get-Date; $Output = $Date + " - " + $Output; Write-Output $Output >> $Global:LogFile
        }
        catch
        {
            $Output = ($_.FullyQualifiedErrorId -split '\.')[0] ; [string]$Date = Get-Date; $Output = $Date + " - " + $Output; Write-Output $Output >> $Global:LogFile
        }
    }

}

Function Workstation #If the system is a workstation, the target build should be checked. At or above, wipe all directories and terminate, otherwise do nothing
{
    If ($Global:IsBDR -eq "0")
    {
        $a = Get-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name 'CurrentBuildNumber'
        If ($a.CurrentBuildNumber -lt $Global:BuildTarget)
        {
            $Output = 'Workstation is not on target build'; [string]$Date = Get-Date; $Output = $Date + " - " + $Output; Write-Output $Output >> $Global:LogFile
        }
        Else
        {
            $Output = 'Workstation is at or above target build, cleaning up files and terminating'; [string]$Date = Get-Date; $Output = $Date + " - " + $Output; Write-Output $Output >> $Global:LogFile
            If(test-path $Global:DirISO)
            {
                Remove-Item $Global:DirISO -Recurse -Force
            }        
            If(test-path $Global:DirStaging)
            {
                Remove-Item $Global:DirStaging -Recurse -Force
            }
            If(test-path $Global:Unpack)
            {
                Remove-Item $Global:Unpack -Recurse -Force
            }   
            If(test-path $Global:StatusFile) {Remove-Item $Global:StatusFile -Force}; [string]$Date = Get-Date -UFormat %y-%m-%d; $Output = $Date + ': ' + 'COMPLIANT'; Write-Output $Output >> $Global:StatusFile     
            Exit
        }
    }
}

Function ListExpected #Creates search string to be used later
{
    foreach ($Check in $Global:Checks)
    {
        $Global:Expected = $Global:Expected + $Check.Name + "|"    
    }
    $Global:Expected = $Global:Expected.Substring(0,$Global:Expected.Length-1)
}

Function ClearUnexpectedISO  #Wipes unexpected file from ISO Directory
{
    $ISOPathCheck = Get-ChildItem $Global:DirISO | Measure-Object
    if ($ISOPathCheck.count -gt 0) 
    {
        $ISOFiles = @(Get-ChildItem -Path $Global:DirISO) | select -expand Name
        foreach ($File in $ISOFiles)
        {
            $ISO = $Global:Checks.Name -like '*ISO*'
            if ($File -notmatch $ISO)
            {
                $Output = 'Found unexpected file in ISO directory, deleted: ' + $File; [string]$Date = Get-Date; $Output = $Date + " - " + $Output; Write-Output $Output >> $Global:LogFile

                $DeleteTarget = $Global:DirISO + '\' + $File 
                Remove-Item $DeleteTarget -Force
            }
        }
    }
}

Function ClearUnexpectedStaging #Wipes unexpected file from ISO Directory
{
    foreach ($File in $Global:StagingFiles)
    {
        if ($File -notmatch $Global:Expected)
        {
        $Path = $Global:DirStaging + '\' + $File
        $Output = 'Found unexpected file in Staging, deleted: ' + $File; [string]$Date = Get-Date; $Output = $Date + " - " + $Output; Write-Output $Output >> $Global:LogFile
        Remove-Item $Path -Force
        }
    }
    $Global:StagingFiles = @(Get-ChildItem -Path $Global:DirStaging) | select -expand Name 
}

Function ISOCheck #If hash matches wipes staging, otherwise deletes mismatched ISO
{
    $ISO = $Global:Checks.Name -like '*ISO*'
    $ISOFullPath = $Global:DirISO + '\' + $ISO
    If(test-path $ISOFullPath)
    {
        $ISOCheck = ''
        foreach ($Check in $Global:Checks)
        {
            If ($Check.Name -match $ISO)
            {             
                $ISOCheck = $Check.Hash
                $ISOHash = Get-FileHash -Path $ISOFullPath
                If ($ISOCheck -eq $ISOHash.Hash)
                {
                    $Output = 'ISO hash matches, wiping staging directory, terminating script'; [string]$Date = Get-Date; $Output = $Date + " - " + $Output; Write-Output $Output >> $Global:LogFile
                    $RemovalPath = $Global:DirStaging + "\*"
			        Remove-Item –path $RemovalPath -Recurse -Force
                    If(test-path $Global:StatusFile) {Remove-Item $Global:StatusFile -Force}; [string]$Date = Get-Date -UFormat %y-%m-%d; $Output = $Date + ': ' + 'STAGED'; Write-Output $Output >> $Global:StatusFile  
                    Exit
                }
                Else
                {
                    $Output = 'ISO hash mismatch, deleting ISO'; [string]$Date = Get-Date; $Output = $Date + " - " + $Output; Write-Output $Output >> $Global:LogFile
                    Remove-Item –path $ISOFullPath -Force
                }
            }
        }
    }
}

Function GatewayCopy #Attempts LAN copy of files if gateway matches value within gateway array and is not BDR
{
    If ($Global:IsBDR -eq "0")
    {
        if ($Global:Gateways)
        {
            foreach ($Machine in $Global:Gateways)
            {
                if ($Machine[0] -like "*$Global:Gateway*")
                {
                    $a = 'net use \\' + $Machine[1] + '\Win10 /user:' + $Machine[1] + '\' + $Global:User + ' ' + $Global:Password
                    $b = 'robocopy \\' + $Machine[1] + '\Win10 ' + $Global:DirISO + ' *.iso /np /r:0 /w:0'
                    $c = 'net use \\' + $Machine[1] + '\Win10 /delete'
                    invoke-expression $a
                    invoke-expression $b
                    invoke-expression $c
                    $Output = $Target.Name + "LAN cache has been attempted"; [string]$Date = Get-Date; $Output = $Date + " - " + $Output; Write-Output $Output >> $Global:LogFile  
                    If(test-path $Global:ISO)
                    {
                        $Output = $Global:ISO + " has been copied, triggering checks"; [string]$Date = Get-Date; $Output = $Date + " - " + $Output; Write-Output $Output >> $Global:LogFile
                        ISOCheck
                    }
                    Else
                    {
                        $Output = $Target.Name + "LAN cache appears to have failed, moving on"; [string]$Date = Get-Date; $Output = $Date + " - " + $Output; Write-Output $Output >> $Global:LogFile  
                    }
                }
            }
        }
    }
}

Function StagingCheck #Hash checks all components of staging for damage or mismatch
{
    foreach ($File in $Global:StagingFiles)
    {
        #Reads all values in check file
        foreach ($Check in $Global:Checks)
        {   #If file locally present, checks hash
            if ($Check.Name -eq $File)
            {
                $Path = $Global:DirStaging + '\' + $File
                $FileHash = Get-FileHash -Path $Path
                #Hash check output and actions
                if ($Check.Hash -eq $FileHash.Hash)
                {
                    $Output = $File + " Hash matches"; [string]$Date = Get-Date; $Output = $Date + " - " + $Output; Write-Output $Output >> $Global:LogFile
                }
                else 
                {
                    Remove-Item $Path -Force
                    $Output = $File + " Hash mismatched, file deleted"; [string]$Date = Get-Date; $Output = $Date + " - " + $Output; Write-Output $Output >> $Global:LogFile
                }
            }
        }
    }
}

Function ListPresent #Creates search string to be used later
{
    If ($Global:StagingFiles)
    {
        foreach ($File in $Global:StagingFiles)
        {
            $Global:Present = $Global:Present + $File + "|"    
        }
        $Global:Present = $Global:Present.Substring(0,$Global:Present.Length-1)
    }
}

Function ListMissing #Creates array of remaining files to download
{
    If ($Global:StagingFiles)
    {
        $Search = $Global:Present + '|' + $Global:ISOName
    }
    Else
    {
        $Search = $Global:ISOName
    }
    
    foreach ($File in $Global:Checks)
    {
        if ($File.Name -notmatch $Search)
        {
            $Global:Remain += $File
        }
    }
}

Function FileExtract #If no files left to download, extracts segmented ISO into full ISO
{
    If (!($Global:Remain))
    {
        $output = $Global:Extractor + ' x -y -o' + $Global:DirISO + " " + $Global:DirStaging + '\' + $UnpackTarget
        IEX $output
        If(test-path $Global:ISO)
        {
            $Output = 'No files left to download, ISO unpacked, triggering ISO checks.'; [string]$Date = Get-Date; $Output = $Date + " - " + $Output; Write-Output $Output >> $Global:LogFile
            ISOCheck
        }
        Else
        {
            $Output = 'ERROR, unpack failed, requires intervention'; [string]$Date = Get-Date; $Output = $Date + " - " + $Output; Write-Output $Output >> $Global:LogFile
            If(test-path $Global:StatusFile) {Remove-Item $Global:StatusFile -Force}; [string]$Date = Get-Date -UFormat %y-%m-%d; $Output = $Date + ': ' + 'ERR: extraction failure'; Write-Output $Output >> $Global:StatusFile  
            Exit
        }
    }
}

Function FileDownload #Picks single file at random from the array of missing files and downloads with a low priority BITS transfer to minimize user interruption
{
    If ($Global:Remain)
    {
        $Target = $Global:Remain[(Get-Random -Maximum ([array]$Global:Remain).count)]
        $DownloadPath = $Global:DirStaging + '\' + $Target.Name
        $Output = $Target.Name + " has been randomly selected from the missing files for download, beginning now"; [string]$Date = Get-Date; $Output = $Date + " - " + $Output; Write-Output $Output >> $Global:LogFile
        Start-BitsTransfer -Source $Target.URL -Destination $DownloadPath -Priority Low
        $Jobs = get-bitstransfer
        foreach ($Job in $Jobs)
        {
            if ($Job.JobState -eq 'Transferred')
            {
                complete-bitstransfer $Job.JobId
            }
        }

        $Output = $Target.Name + ' Download Complete'; [string]$Date = Get-Date; $Output = $Date + " - " + $Output; Write-Output $Output >> $Global:LogFile 
    }
    $Count = ( Get-ChildItem $Global:DirStaging | Measure-Object ).Count
    $TotalCount = $Global:Checks.Length-1
    If(test-path $Global:StatusFile) {Remove-Item $Global:StatusFile -Force}; [string]$Date = Get-Date -UFormat %y-%m-%d; $Output = $Date + ': ' + $Count.ToString() + ' of ' + $TotalCount.ToString() + ' files'; Write-Output $Output >> $Global:StatusFile  
}


##############################################################################################################
############################################# End Functions ##################################################
##############################################################################################################





##############################################################################################################
############################################## Function Calls ################################################
##############################################################################################################
Cls

Workstation
Prep
If ($Global:IsBDR -eq "0")
{
    EnumerateGateways
}
RewriteDropbox
BDR
ListExpected
ClearUnexpectedISO
ClearUnexpectedStaging
ISOCheck
GatewayCopy
StagingCheck
ListPresent
ListMissing
FileExtract
FileDownload
##############################################################################################################
############################################ End Function Calls ##############################################
##############################################################################################################