param([string]$CreoRoot,[string]$Destination="$env:LOCALAPPDATA\CreoMaterialPicker",[string]$Settings,[switch]$TestOnly)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
if(!$TestOnly -and (Get-Process xtop -ErrorAction SilentlyContinue)){throw '请保存零件并退出 Creo，再运行安装程序。'}
function IsCreo12($p){$p -and (Test-Path -LiteralPath (Join-Path $p 'Common Files\text\materials-library')) -and ((Split-Path $p -Leaf) -match '12\.' -or (Get-Item (Join-Path $p 'Parametric\bin\parametric.exe') -ErrorAction SilentlyContinue).VersionInfo.ProductVersion -match '^12\.')}
if(!$CreoRoot){
 $links=@(Get-ChildItem "$env:PUBLIC\Desktop","$env:ProgramData\Microsoft\Windows\Start Menu\Programs",([Environment]::GetFolderPath('DesktopDirectory')) -Filter '*Parametric*.lnk' -Recurse -ErrorAction SilentlyContinue)
 $ws=New-Object -ComObject WScript.Shell
 $roots=@(foreach($link in $links){$target=$ws.CreateShortcut($link.FullName).TargetPath;if($target -match '(?i)^(.+)\\Parametric\\bin\\[^\\]+\.exe$'){if(IsCreo12 $Matches[1]){$Matches[1]}}})|Sort-Object -Unique
 if(!$roots){
  $roots=@(foreach($drive in (Get-PSDrive -PSProvider FileSystem)){
   foreach($parent in @('PTC','Program Files\PTC')){
    Get-ChildItem (Join-Path $drive.Root $parent) -Directory -Filter 'Creo 12*' -ErrorAction SilentlyContinue | Where-Object {IsCreo12 $_.FullName} | ForEach-Object FullName
   }
  }) | Sort-Object -Unique
 }
 if(@($roots).Count -eq 1 -and $roots){$CreoRoot=@($roots)[0]}else{
 $dlg=New-Object Windows.Forms.FolderBrowserDialog;$dlg.Description='选择 Creo 12 安装目录（内含 Common Files 和 Parametric）';if($dlg.ShowDialog() -ne 'OK'){return};$CreoRoot=$dlg.SelectedPath}
}
if(!(IsCreo12 $CreoRoot)){throw '请选择 Creo Parametric 12 安装目录。'}
if(!$Settings){$wf=if($env:PTC_WF_ROOT){$env:PTC_WF_ROOT}else{"$env:APPDATA\PTC\ProENGINEER\Wildfire\.wf"};$Settings=Join-Path $wf '.Settings'}
$src=Join-Path $CreoRoot 'Common Files'
$map=Join-Path $Settings 'mapkeys.pro'
$marker='! BEGIN CREO_MATERIAL_PICKER_1'
$end='! END CREO_MATERIAL_PICKER_1'
$old=if(Test-Path $map){[IO.File]::ReadAllText($map)}else{''}
$clean=[regex]::Replace([string]$old,'(?ms)^! BEGIN CREO_MATERIAL_PICKER_1\r?\n.*?^! END CREO_MATERIAL_PICKER_1\r?\n?','')
if($clean -match '(?im)^mapkey\s+zmp|CREO_MATERIAL_PICKER_1'){throw '映射键名称冲突，请保留现有配置并联系维护者。'}
$version=Join-Path $Destination ([guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $version -Force)
Copy-Item (Join-Path $PSScriptRoot 'Picker.ps1') $version
$lib=Join-Path $version 'Materials'
$bundle=Join-Path $PSScriptRoot 'Materials.zip'
$expected=(Get-Content -LiteralPath (Join-Path $PSScriptRoot 'Materials.sha256') -Raw).Trim()
if((Get-FileHash -LiteralPath $bundle).Hash -ne $expected){throw '随包材料校验失败。'}
Expand-Archive -LiteralPath $bundle -DestinationPath $lib
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Verified_Grades') -Destination $lib -Recurse
$dirs=@($lib,(Join-Path $src 'text\materials-library'),(Join-Path $src 'creo_standards\material_database'))|Where-Object {Test-Path $_}
$files=@(Get-ChildItem -LiteralPath $dirs -Filter '*.mtl' -File -Recurse|Sort-Object FullName)
$parent=if($TestOnly){$Destination}elseif(Test-Path 'D:\Creo_Material_Library' -PathType Container){'D:\Creo_Material_Library'}else{[Environment]::GetFolderPath('MyDocuments')}
$cache=New-Item -ItemType Directory -Path (Join-Path $parent ('CMP_'+[guid]::NewGuid().ToString('N').Substring(0,8)))
$lines=New-Object 'Collections.Generic.List[string]';$lines.Add($marker);$i=0
$index=foreach($f in $files){
 $i++;$key='zmp{0:0000}' -f $i
 $groupDir=Join-Path $cache.FullName $f.Directory.Name
 [void][IO.Directory]::CreateDirectory($groupDir)
 $target=Join-Path $groupDir $f.Name
 [IO.File]::Copy($f.FullName,$target,$false)
 $parts=$target.Split('\');if($parts[0] -notmatch '^[A-Za-z]:$' -or $target -match '[`;]'){throw "材料路径不支持：$target"}
 $parts[0]=$parts[0].ToLowerInvariant()
 $cmd=@('~ Command `ProCmdNaModelProperties`','~ Activate `nma_model_massprop` `new_density_opts_ph.AssignMaterialsButton`','~ Activate `assign_material` `PushButton1`','~ Activate `finder` `computer_pb`')
 foreach($part in $parts){foreach($action in 'Select','Activate'){$cmd+=('~ {0} `finder` `FFileListPHLay.Filelist` 1 `{1}`' -f $action,$part)}}
 $cmd+='~ Activate `finder` `FOkPush`','~ Activate `assign_material` `CommitOK`','~ Activate `nma_model_massprop` `ok_btn`'
 $cmd+='~ Command `ProCmdMmModelProperties`','~ Activate `mdlprops_dlg` `MASS_PROPS_lay_Controls.push_Change.lay_instance`','~ Activate `mass_prop_dlg` `CalculateMPPush`','~ Activate `mass_prop_dlg` `GenerateReportPush`'
 $lines.Add("mapkey $key @MAPKEY_LABELAssign $($f.BaseName);\")
 for($j=0;$j -lt $cmd.Count;$j++){$tail=if($j -lt $cmd.Count-1){';\'}else{';'};$lines.Add('mapkey(continued) '+$cmd[$j]+$tail)}
 [pscustomobject]@{Key=$key;Label=("$($f.BaseName)    ·    $($f.Directory.Name)");Path=$target;OriginalPath=$f.FullName}
}
$index|Export-Csv -NoTypeInformation -Encoding UTF8 -LiteralPath (Join-Path $version 'index.csv')
$readMass=@('mapkey zmpmass @MAPKEY_LABELRead current part mass;\','mapkey(continued) ~ Command `ProCmdMmModelProperties`;\','mapkey(continued) ~ Activate `mdlprops_dlg` `MASS_PROPS_lay_Controls.push_Change.lay_instance`;\','mapkey(continued) ~ Activate `mass_prop_dlg` `CalculateMPPush`;\','mapkey(continued) ~ Activate `mass_prop_dlg` `GenerateReportPush`;')
foreach($l in $readMass){$lines.Add($l)}
$lines.Add($end);[void][IO.Directory]::CreateDirectory($Settings)
$tmp=Join-Path $Settings ([guid]::NewGuid().ToString()+'.tmp')
[IO.File]::WriteAllText($tmp,($clean.TrimEnd()+[Environment]::NewLine+($lines -join [Environment]::NewLine)+[Environment]::NewLine),[Text.UTF8Encoding]::new($false))
if(Test-Path $map){[IO.File]::Replace($tmp,$map,($map+'.'+[guid]::NewGuid().ToString()+'.bak'))}else{[IO.File]::Move($tmp,$map)}
if(!$TestOnly){
 $ws=New-Object -ComObject WScript.Shell
 $k=$ws.CreateShortcut((Join-Path ([Environment]::GetFolderPath('DesktopDirectory')) 'Creo 材料面板（便携版）.lnk'))
 $k.TargetPath="$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe";$k.Arguments='-NoProfile -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File "'+(Join-Path $version 'Picker.ps1')+'"';$k.Save()
}
Write-Host "已配置 $i 个材料。启动 Creo 并打开零件后，双击桌面的材料面板。"
