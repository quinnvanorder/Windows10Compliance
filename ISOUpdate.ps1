##############################################################################################################
############################################### Arguments ####################################################
##############################################################################################################
$Global:Root = ""
[String]$Global:Root = $args[0]
$Global:Target = ""
[String]$Global:Target = $args[1]
##############################################################################################################
############################################# End Arguments ##################################################
##############################################################################################################





##############################################################################################################
############################################## Variables #####################################################
##############################################################################################################
$Global:Extraction = $Global:Root + '\Extraction.zip'
$Global:DirExtraction = $Global:Root + '\Extraction'
$Global:Extractor = $Global:DirExtraction + '\7z.exe'
$Global:Zip = $Global:Root + '\Windows.zip'
##############################################################################################################
############################################# End Variables ##################################################
##############################################################################################################





##############################################################################################################
############################################### Functions ####################################################
##############################################################################################################
Function Prep #Builds working directory within Kworking
{
    $RemovalPath = $Global:Root + "\*"
    Remove-Item –path $RemovalPath -Recurse -Force
    If(!(test-path $Global:Extractor))
    {
        (New-Object System.Net.WebClient).DownloadFile('https://www.dropbox.com/s/[uniquestring]/Extraction.zip?dl=1', $Global:Extraction)
        If(!(test-path $Global:Extraction))
        {
            Write-Host 'Extraction file download failed'
            Exit
        }   
    }
}

Function Split #Uses 7zip to break file into 200mb chunks, deletes extraction components after completion
{
    expand-archive -LiteralPath $Global:Extraction -DestinationPath $Global:Root
    $output = $Global:Extractor + ' a -v200m -mx=0 '+ $Global:Zip + ' ' + $Global:Target
    Remove-Item –path $Global:Extraction -Force
    $Output
    IEX $Output
    Remove-Item –path $Global:DirExtraction -Recurse -Force
}

Function Hash #Creates Files.csv needed for primary script
{
    If(test-path C:\Temp\Files.csv)
    {
        Remove-Item –path C:\Temp\Files.csv -Force
    }
    $Header = "Name, Hash, URL"
    Add-Content C:\Temp\Files.csv $Header
    Copy-Item -Path $Global:Target -Destination $Global:Root
    Get-ChildItem $Global:Root | 
    Foreach-Object {
        #$_ | Format-List * -force
        $hash = Get-FileHash -Path $_.FullName
        $Output = $_.Name + ", " + $hash.Hash + ", " 
        Add-Content C:\Temp\Files.csv $Output
        #After hash file generation, delete iso
    }
    Move-Item -Path C:\Temp\Files.csv -Destination $Global:Root
    Get-ChildItem -Path $Global:Root *.iso | foreach { Remove-Item -Path $_.FullName }
}
##############################################################################################################
############################################# End Functions ##################################################
##############################################################################################################





##############################################################################################################
############################################## Function Calls ################################################
##############################################################################################################
Cls

Prep
Split
Hash
##############################################################################################################
############################################ End Function Calls ##############################################
##############################################################################################################


