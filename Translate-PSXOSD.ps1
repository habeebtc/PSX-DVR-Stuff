param([string]$path, [string]$TargetLanguage="en")

function translate-string($text, $SourceLanguage="ja", $TargetLanguage="en", $sleepTime = 1000)
{
    $Translation = ""
    $Uri = "https://translate.googleapis.com/translate_a/single?client=gtx&sl=$($SourceLanguage)&tl=$($TargetLanguage)&dt=t&q=$Text"
    $Response = Invoke-RestMethod -Uri $Uri -Method Get
    $Response[0].SyncRoot | foreach { $Translation += $_[0] }
    # Since we're gaming a secret free API - we should try and rate limit this.  Just be patient!
    # Alternately, you can sign up for a GCP eval and use the basic tier translation service with an API Key.  First 500k translations are free, $10/1 million characters after that.
    Start-Sleep -Milliseconds $sleepTime
    
    return $Translation
}
function Recurse-Translate([ref]$xmlnode)
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
                if($bQuestion -and $translated -notlike "*?") { $translated  += "?"}
                # Let's make sure we get everything nicely capitalized
                
                
                $translated = $translated.Replace($translated[0],$translated[0].ToString().ToUpper())
                $translated = $translated.Replace("@RN ","`r`n")
                $xmlnode.Value.Attributes["str"].'#text' = $translated
            }
        }
        catch 
        {
                #Write-Host $_.Message -ForegroundColor Red
        }

    }

    if ($xmlnode.Value.ChildNodes.Count -gt 0)
    {
        foreach($childnode in $xmlnode.Value.ChildNodes)
        {
            Recurse-Translate ([ref]$childnode)
        }
    }
}

$starttime = get-date
foreach($xmlfile in  (get-childitem $original -Recurse -Filter "*.xml"))
{
    Write-Host "Parsing file: $($xmlfile.FullName)"
    $contents = new-object XML
    $contents.Load( $xmlfile.FullName)

    foreach($element in $contents.App)
    {
        # Root document element
        foreach($childnode in $element.ChildNodes)
        {
            Recurse-Translate -xmlnode ([ref]$childnode)
        }
    }

    $contents.Save($xmlfile.FullName)
}

$endtime = get-date
Write-Host "Processing completed!" -ForegroundColor Green
Write-Host "Start Time: $starttime" -ForegroundColor Yellow
Write-Host "End Time: $endtime" -ForegroundColor Yellow
  



