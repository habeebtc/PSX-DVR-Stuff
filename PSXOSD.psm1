function translate-imagestrings($srcfolder)
{
    $imagestrings = import-csv -path "$srcfolder\ImageSourceStrings.csv"
    Write-Progress -Status "Translating Strings contained within images" -Activity "Starting..." -PercentComplete 0
    
    $outputFile = New-Object System.Collections.ArrayList
    $count = 0
    foreach($row in $imagestrings)
    {
        $count++
        Write-Progress -Status "Translating Strings contained within images" -Activity "Translating $($row.SourceText)" -PercentComplete ($count / $imagestrings.Count)
        if($row.SourceText.Length -gt 0)
        {
            $string = translate-string -text $row.SourceText
            $row.Translated = $string
        }
        $outputFile.Add($row)
    }
    
    $outputFile | export-csv -Path "$srcfolder\ImageSourceStrings.csv"  -NoTypeInformation -Encoding UTF8
}
function camel-case($string)
{
    $position = 0
    $newstring = ""
    foreach($char in $string.GetEnumerator())
    {
        
        if($position -eq 0 -or $string[$position - 1] -eq " " -or $string[$position - 1]  -eq "/")
        {
            $newstring += $string[$position].ToString().ToUpper()
        }
        else
        {
            $newstring += $string[$position]
        }
        $position++
    }
    return $newstring
}

function get-imagemagic()
{
    # Get the first imagemagick install folder, and pass back the path to convert.exe
    $regkey =  (Get-ChildItem -Path Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall | Where-Object {$_.Name -like "*ImageMagick*"})[0] 

    $imgmagicpath = (Get-ItemProperty Registry::$regkey).InstallLocation

    $convertpath = "$($imgmagicpath)convert.exe"

    if((test-path $convertpath) -eq $false)
    {
        Write-Host "ImageMagick doesn't appear to be installed!" -ForegroundColor Yellow
        Write-Host "Please visit https://imagemagick.org/script/download.php" -ForegroundColor Yellow
        throw "ImageMagickNotFound"
    }

    return $convertpath 
}

function convertto-png($filepath, $bOverwrite = $true)
{
    $convert = get-imagemagic
    $file = Get-Item $filepath 
    if($bOverwrite -eq $false -and (test-path -path "$($file.DirectoryName)\$($file.BaseName).png" ))
    {
        $timestamp = Get-Date -Format "ddMMddyyyyHHmm"
        Rename-Item -Path "$($file.DirectoryName)\$($file.BaseName).png" -NewName "$($file.DirectoryName)\$($file.BaseName).$timestamp.png"
    }
    Start-Process -FilePath $convert -ArgumentList $filepath, "$($file.DirectoryName)\$($file.BaseName).png" -Wait
    
    return "$($file.DirectoryName)\$($file.BaseName).png"
}

function convertto-tga($filepath, $bOverwrite = $true)
{
    $convert = get-imagemagic
    $file = Get-Item $filepath 
    if($bOverwrite -eq $false -and (test-path -Path "$($file.DirectoryName)\$($file.BaseName).tga"))
    {
        $timestamp = Get-Date -Format "ddMMddyyyyHHmm"
        Rename-Item -Path "$($file.DirectoryName)\$($file.BaseName).tga" -NewName "$($file.DirectoryName)\$($file.BaseName).$timestamp.tga"
    }
    Start-Process -FilePath $convert -ArgumentList $filepath, "$($file.DirectoryName)\$($file.BaseName).tga" -Wait
    return "$($file.DirectoryName)\$($file.BaseName).tga"
}


function translate-string($text, $SourceLanguage="ja", $TargetLanguage="en", $sleepTime = 100)
{
    $translation = ""
    $Uri = "https://translate.googleapis.com/translate_a/single?client=gtx&sl=$($SourceLanguage)&tl=$($TargetLanguage)&dt=t&q=$Text"
    $Response = Invoke-RestMethod -Uri $Uri -Method Get
    $Response[0].SyncRoot | foreach { $translation += $_[0] }
    # Since we're gaming a secret free API - we should try and rate limit this.  Just be patient!
    # Alternately, you can sign up for a GCP eval and use the basic tier translation service with an API Key.  First 500k translations are free, $10/1 million characters after that.
    Start-Sleep -Milliseconds $sleepTime

    $translation = do-replacement -string $translation
    $translation = camel-case -string $translation

    if($translation.Length -gt ($text.Length * 3))
    {
        Write-Host "Resulting string $translation is more than 3x the length of source string $text - Please validate the output!" -ForegroundColor Yellow
    }

    return $translation
}

function do-replacement($string, $lang = "en")
{
    foreach($replacement in (Import-Csv -Path "$($PSScriptRoot)\$lang-replacements.csv"))
    {
        switch($replacement.Position.ToLower())
        {
            "contains" {
                if($string -like "*$($replacement.String)*")
                {
                    $bReplace = $true
                }
            }
            "startswith" {
                if($string -like "$($replacement.String)*")
                {
                    $bReplace = $true
                }
            }
            "endswith" {
                if($string -like "*$($replacement.String)")
                {
                    $bReplace = $true
                }
            }
        }

        if($bReplace)
        {
            # let's gaurantee that we get the replacement done - our camel caser will handle capitalization
            $string = $string.Replace($replacement.String.ToLower(),$replacement.Replacement.ToLower())
        }
    }

    return $string
}

function get-folders($folder, $fileext)
{
    $subfolders = @()
    foreach($file in (get-childitem $folder -Recurse -File -Filter "*.$fileext"))
    {
        $subfolders += $file.Directory.FullName.Replace($folder,"")
    }

    return ($subfolders | Get-Unique)
}



function Recurse-Translate([ref]$xmlnode, $lang = "en")
{
    if($xmlnode.Value.Attributes.Count -ge 0)
    {
        try {
            if( $xmlnode.Value.Attributes["str"] -ne $null)
            {
                #translate the string from Japanese.
                $original = $xmlnode.Value.Attributes["str"].'#text'
                $bQuestion = $original -like "*?"

                if($original -like "*`r`n*") {$original = $original.Replace("`r`n","@RN ")  }

                $translated = translate-string -text $original 
                # TODO: Let's consider a warning system, where we flag via output message a string which far exceeds the source string in character count.
                if($bQuestion -and $translated -notlike "*?") { $translated  += "?"} 
                $translated = $translated.Replace("@RN ","`r`n")
                $xmlnode.Value.Attributes["str"].'#text' = $translated
            }
        }
        catch 
        {
                Write-Host $_.Message -ForegroundColor Red
        }

    }

    if ($xmlnode.Value.ChildNodes.Count -gt 0)
    {
        foreach($childnode in $xmlnode.Value.ChildNodes)
        {
            Recurse-Translate ([ref]$childnode) -lang $lang
        }
    }
}

function copy-folder($folder, $destination)
{
    $files = @()
    Write-Progress -Status "Gathering File List" -PercentComplete 0 -Activity "Phase 1: Copying OSD files to destination"
    foreach($file in (get-childitem $folder -Recurse -File))
    {
        $files += $file.FullName
    }
    try {
        $count = 0
        foreach($file in $files)
        {
            $destinationfile = $File.Replace($folder,$destination)
            $srcfileobj = get-item -Path $file
            $destinationfolder = $destinationfile.replace($srcfileobj.Name,"")
            if((test-path -path $destinationfolder) -eq $false)
            {
                Write-Progress -Status "Creating Destination Folder $destinationfolder" -PercentComplete (($count / $files.Count) * 100) -Activity "Copying OSD files to destination"            
                $newfolder = new-item -Path $destinationfolder -ItemType Directory -Force 
            }
            Write-Progress -Status "Copying OSD File $file" -PercentComplete (($count / $files.Count) * 100) -Activity "Copying OSD files to destination"
            Copy-Item -Path $file -Destination $File.Replace($folder,$destination) -Force
            $count++        
        }
    }
    catch {
        Write-Host "Exception raised copying file $file" -ForegroundColor Yellow
        Write-Host "Check disk space, permissions, etc." -ForegroundColor Yellow
        Write-Host $_.Message -ForegroundColor Red
        exit
    }

}

function unsign($num)
{
    if($num -lt 0)
    {
        return ($num * -1)
    }
    else 
    {
        return $num
    }
}

function write-imagestring($imgfile, $string, [int32]$startx, [int32]$starty, [int32]$width, [int32]$height, $fontname = 'Dominican', $openFile = $false)
{
    $bTga = $false
    if($imgfile.EndsWith(".tga"))
    {
        write-host "Converting $imgfile to *.png for processing..." -ForegroundColor Yellow
        # leave any prior *.png in place, just in case we want to look at our history for some reason
        $imgfile = convertto-png -filepath $imgfile -bOverwrite $false
        $bTga = $true
    }
    else
    {
        write-host "Processing $imgfile directly as *.png or *.bmp" -ForegroundColor Yellow
    }
    $bytes = [System.IO.File]::ReadAllBytes($imgfile);
    [System.IO.MemoryStream] $ms = [System.IO.MemoryStream]::new($bytes);
    $src = [System.Drawing.Image]::FromStream($ms);
    $basepxl = $src.GetPixel($startx, $starty)


    $pixels = @{}
    $startx .. ($startx + $width) | % {
        # check the middle pixel in the region
        $pxl = $src.GetPixel($_, $starty + ($height / 2))
        $pixels[$pxl.Name] = unsign -num ([uint32]"0x$($basepxl.Name)" - [uint32]"0x$($pxl.Name)")
    }
    # Sort the pixels dictionary by value, and grab the highest value
    # what is this doing: Taking the biggest diff value, and using it as foreground color.
    # Then, convert the name back to a ARBG value
    
    $fgcolorname = ($pixels.GetEnumerator() | sort-object -Property value -Descending)[0].Name
    $fgcolor = [System.Drawing.Color]::FromArgb([uint32]"0x000000$($fgcolorname[0])$($fgcolorname[1])", [uint32]"0x000000$($fgcolorname[2])$($fgcolorname[3])",[uint32]"0x000000$($fgcolorname[4])$($fgcolorname[5])",[uint32]"0x000000$($fgcolorname[6])$($fgcolorname[7])")
    $brushFg = [System.Drawing.SolidBrush]::new($fgcolor)
    
    
    
    $starty .. ($starty+$height) | % {
        $newy =  $_
        $pxl = $src.GetPixel($startx,$newy)
        $bgColor = [System.Drawing.Color]::FromArgb($pxl.A, $pxl.R,$pxl.G,$pxl.B)
        $brushBg = [System.Drawing.SolidBrush]::new($bgColor)
        $pen = [System.Drawing.Pen]::new($brushBg)
        $pen.Width = 1
        $startx .. ($startx + $width) | % {
            $newx = $_
            # SetPixel allows us to overwrite regions of the image with transparent pixels
            # Graphics.DrawLine() just writes a transparent layer over the top, which doesn't erase anything...
            $src.SetPixel($newx, $newy, $bgColor )
        }
    }
    
    $graphics = [System.Drawing.Graphics]::FromImage($src) 

    $fontsize = 1

    do
    {
        $fontsize++
        $font = [System.Drawing.Font]::new($fontname,$fontsize)
        $result = $graphics.MeasureString($string,$font,1000) #effectively unlimited width - we don't want to hit the limit
    } 
    until($result.Width -gt $width -or $result.Height -gt $height)

    $font = [System.Drawing.Font]::new($fontname,$fontsize)

    $drawFormat = [System.Drawing.StringFormat]::new()
    $drawFormat.Alignment = [System.Drawing.StringAlignment]::Center

    $graphics.DrawString($string,$font,$brushFg,$startx,$starty, $drawFormat)
    
    $src.Save($imgfile)
    
    $src.Dispose()
    $graphics.Dispose() 

    if($bTga)
    {
        # leave the original *.tga file in place, in case we want to go back and have a look
        $imgfile = convertto-tga -filepath $imgfile -bOverwrite $false
    }
    
    if($openFile)
    {
        mspaint.exe $imgfile
    }
}

function process-osd([string]$osdpath, [string]$TargetLanguage="en", [string]$outputpath, [bool]$bCopyFolder = $true , [bool]$bTranslateXML = $true, [bool]$bWriteImages = $true, [bool]$bProcessImageStrings = $true)
{
    $starttime = get-date

    # Phase 1: Copying the source to destination.

    if($bCopyFolder)
    {
        copy-folder -folder $osdpath -destination $outputpath
    }
    else {
        Write-Host "Bypassing Copy Folder stage; copy parameter: $bCopyFolder" -ForegroundColor Green
    }
    
    # Phase 2: Translating all the strings inside *.xml files

    if($bTranslateXML)
    {
        $files = @()
        foreach($xmlfile in  (get-childitem $outputpath -Recurse -Filter "*.xml"))
        {
            $files += $xmlfile.FullName
        }
        $count = 0

        foreach($xmlfile in $files)
        {
            $count++
            Write-Progress -Status "Translating file: $xmlfile" -PercentComplete (($count / $files.Count) * 100) -Activity "Phase 2: Translating XML files"

            $contents = new-object XML
            $contents.Load([string]$xmlfile)

            foreach($element in $contents.LastChild)
            {
                # Root document element
                foreach($childnode in $element.ChildNodes)
                {
                    Recurse-Translate -xmlnode ([ref]$childnode) -lang $TargetLanguage
                }
            }
            $contents.Save([string]$xmlfile)
        }
    }
    else {
        Write-Host "Skipping XML file translation due to translate parameter: $bTranslateXML" -ForegroundColor Green
    }

    # Phase 3: Translate the image strings

    if($bProcessImageStrings)
    {
        translate-imagestrings -srcfolder $outputpath
    }
    else {
        Write-Host "Skipping translation of image strings, due to processing parameter: $bProcessImageStrings" -ForegroundColor Green
    }

    # Phase 4: Inject the translated image strings

    if($bWriteImages)
    {
        $imagestrings = import-csv -path "$outputpath\ImageSourceStrings.csv"
        Write-Progress -Status "Injecting Strings into images" -Activity "Starting..." -PercentComplete 0

        $count = 0
        foreach($row in $imagestrings)
        {
            $count++
            Write-Progress -Status "Translating Strings contained within images" -Activity "Writing string: $($row.Translated)" -PercentComplete ($count / $imagestrings.Count)

            $imagepath = (get-childitem $outputpath -Recurse -Filter $row.File)[0].FullName

            write-imagestring -imgfile $imagepath -string $row.Translated -startx $row.X -starty $row.Y -width $row.Width -height $row.Height -fontname $row.Font
        }
    }
    else {
        Write-Host "Skipping injection of text into images, due to write parameter: $bWriteImages"
    }

    $endtime = get-date
    Write-Host "Processing completed!" -ForegroundColor Green
    Write-Host "Start Time: $starttime" -ForegroundColor Yellow
    Write-Host "End Time: $endtime" -ForegroundColor Yellow
}

