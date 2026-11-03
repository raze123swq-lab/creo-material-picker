$ErrorActionPreference='Stop'
if(![Environment]::Is64BitProcess -or $PSVersionTable.PSVersion -lt [version]'5.1'){throw '64-bit Windows PowerShell 5.1 required'}
foreach($f in 'Install.ps1','Picker.ps1','Materials.zip','Materials.sha256','Verified_Grades'){if(!(Test-Path (Join-Path $PSScriptRoot $f))){throw "Missing $f"}}
if((Get-FileHash (Join-Path $PSScriptRoot 'Materials.zip')).Hash -ne (Get-Content (Join-Path $PSScriptRoot 'Materials.sha256') -Raw).Trim()){throw 'Material checksum mismatch'}
$ws=New-Object -ComObject WScript.Shell
$links=Get-ChildItem "$env:PUBLIC\Desktop","$env:ProgramData\Microsoft\Windows\Start Menu\Programs",([Environment]::GetFolderPath('DesktopDirectory')) -Filter '*Parametric*.lnk' -Recurse -ErrorAction SilentlyContinue
$roots=@(foreach($l in $links){$exe=$ws.CreateShortcut($l.FullName).TargetPath;if($exe -match '(?i)^(.+12\.[^\\]*)\\Parametric\\bin\\[^\\]+\.exe$' -and (Test-Path -LiteralPath $exe)){ $Matches[1] }})|Sort-Object -Unique
[pscustomobject]@{CreoRoots=@($roots);CreoOpen=[bool](Get-Process xtop -ErrorAction SilentlyContinue);BundleHash='OK';PowerShell=$PSVersionTable.PSVersion.ToString()}|ConvertTo-Json
