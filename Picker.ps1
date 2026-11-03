$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms,System.Drawing
Add-Type @'
using System;
using System.Runtime.InteropServices;
public class CreoFocus {
 [DllImport("ntdll.dll")] static extern int NtQueryInformationProcess(IntPtr h,int c,IntPtr[] b,int n,out int size);
 [DllImport("kernel32.dll")] static extern bool ReadProcessMemory(IntPtr h,IntPtr addr,byte[] b,int n,out IntPtr read);
 static byte[] Read(IntPtr h,long addr,int n){var b=new byte[n];IntPtr got;if(!ReadProcessMemory(h,new IntPtr(addr),b,n,out got)||got.ToInt64()!=n)throw new InvalidOperationException();return b;}
 public static string WorkingDir(IntPtr h){try{if(IntPtr.Size!=8)return null;var info=new IntPtr[6];int len;if(NtQueryInformationProcess(h,0,info,48,out len)!=0)return null;var pp=BitConverter.ToInt64(Read(h,info[1].ToInt64()+32,8),0);var u=Read(h,pp+56,16);int n=BitConverter.ToUInt16(u,0);if(n==0||n%2!=0)return null;return System.Text.Encoding.Unicode.GetString(Read(h,BitConverter.ToInt64(u,8),n));}catch{return null;}}
 [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
 [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h,out uint id);
 [DllImport("user32.dll",CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr h,System.Text.StringBuilder b,int n);
 [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc fn,IntPtr arg);
 [DllImport("user32.dll")] static extern bool PostMessage(IntPtr h,uint m,IntPtr w,IntPtr l);
 delegate bool EnumProc(IntPtr h,IntPtr arg);
 public static void CloseMassWindows(uint pid){var windows=new System.Collections.Generic.List<IntPtr>();EnumWindows((h,arg)=>{uint owner;GetWindowThreadProcessId(h,out owner);if(owner==pid){var title=new System.Text.StringBuilder(256);GetWindowText(h,title,256);var s=title.ToString();if(s.StartsWith("信息窗口 (")||s.StartsWith("Information Window (")||s.StartsWith("质量属性:")||s.StartsWith("Mass Properties:"))windows.Add(h);}return true;},IntPtr.Zero);foreach(var h in windows)PostMessage(h,0x10,IntPtr.Zero,IntPtr.Zero);System.Threading.Thread.Sleep(250);EnumWindows((h,arg)=>{uint owner;GetWindowThreadProcessId(h,out owner);if(owner==pid){var title=new System.Text.StringBuilder(256);GetWindowText(h,title,256);var s=title.ToString();if(s=="模型属性"||s=="Model Properties")PostMessage(h,0x10,IntPtr.Zero,IntPtr.Zero);}return true;},IntPtr.Zero);}
}
'@
$rows=@(Import-Csv -LiteralPath (Join-Path $PSScriptRoot 'index.csv') -Encoding UTF8)
$form=New-Object Windows.Forms.Form
$form.Text='Creo 材料面板'; $form.ClientSize=New-Object Drawing.Size(720,600)
$form.MinimumSize=New-Object Drawing.Size(650,540)
$form.StartPosition='CenterScreen'
$form.Font=New-Object Drawing.Font('Microsoft YaHei UI',10)
$form.BackColor=[Drawing.ColorTranslator]::FromHtml('#F4F7F8')
$ink=[Drawing.ColorTranslator]::FromHtml('#173642')
$accent=[Drawing.ColorTranslator]::FromHtml('#116C64')
$form.ForeColor=$ink
function Place($control,$x,$y,$width,$height,$anchor){
 $control.SetBounds($x,$y,$width,$height);$control.Anchor=$anchor;$form.Controls.Add($control)
}
$title=New-Object Windows.Forms.Label
$title.Text='工程材料库';$title.Font=New-Object Drawing.Font('Microsoft YaHei UI',21,[Drawing.FontStyle]::Bold)
Place $title 24 16 360 45 'Top,Left'
$count=New-Object Windows.Forms.Label
$count.TextAlign='MiddleRight';Place $count 475 24 220 28 'Top,Right'
$caption=New-Object Windows.Forms.Label
$caption.Text='搜索材料名或牌号';Place $caption 24 80 350 25 'Top,Left'
$groupLabel=New-Object Windows.Forms.Label
$groupLabel.Text='材料分类';Place $groupLabel 493 80 200 25 'Top,Right'
$category=New-Object Windows.Forms.ComboBox
$category.DropDownStyle='DropDownList';Place $category 493 106 202 32 'Top,Right'
$names=@{ '01_Plastics'='塑料';Plastics='塑料';'02_Metals'='常用金属';'03_Elastomers'='弹性体';Elastomers_and_rubbers='弹性体';Ferrous_metals='黑色金属';'Non-ferrous_metals'='有色金属';Ceramics_and_glasses='陶瓷与玻璃';Woods='木材';Foams='泡沫';Composites='复合材料';'Core-Materials'='复合材料芯材';'Ply-Materials'='复合材料铺层';'Fastener-Materials'='紧固件';'Fluid-Materials'='流体';'Legacy-Materials'='旧版材料';material_database='标准示例'}
foreach($r in $rows){
 $folder=Split-Path (Split-Path $r.Path) -Leaf
 $group=if($names.ContainsKey($folder)){$names[$folder]}else{$folder}
 $r|Add-Member Group $group
 $source=if($folder -match '^0[123]_'){'重量估算库'}else{'Creo 自带库'}
 $r.Label=([IO.Path]::GetFileNameWithoutExtension($r.Path))+'     ·     '+$group+'     ·     '+$source
 $base=[IO.Path]::GetFileNameWithoutExtension($r.Path)
 $status='未注明具体牌号'
 if($folder -eq 'Verified_Grades'){$group='厂商牌号';$r.Group=$group;$status='厂商牌号';$r.Label=$base.Replace('_','-')+'   ·   牌号密度库'}
 elseif($folder -eq 'Fastener-Materials'){$status='紧固件等级'}
 elseif($folder -in 'Core-Materials','Ply-Materials'){$status='原库型号'}
 elseif($base -match '^(AL(2014|6061|6063|7075)|H13|P20|Q235|S50C|STEEL_45|SUS30[4]|SUS316L|metal_alumin[ui]+m_(aa)?\d+)$'){$status='金属牌号'}
 elseif($folder -in 'Fluid-Materials','Woods' -or $base -match '^wood_'){$status='介质或材种'}
 $r|Add-Member Status $status
 $note=switch -Regex ($base){
  '^(plastic_)?abs$' {'通用 ABS（丙烯腈–丁二烯–苯乙烯）。此条目未指定厂商牌号。奇美 POLYLAC PA-757 系列属于 ABS；PA-758 属于透明 MABS。请按料袋或 BOM 的完整型号区分。';break}
  '^PC[-_+]ABS$' {'PC/ABS 是聚碳酸酯与 ABS 的共混料。此条目未注明配比、阻燃等级或商品牌号。科思创 Bayblend T65 XF 是具体商品的示例，本条目没有采用该牌号的数据。';break}
  '^PA66_GF30$' {'PA66 是聚酰胺 66，GF30 表示约 30% 玻璃纤维增强。增强比例不能确定供应商和商品牌号。';break}
  default {''}
 }
 $r.Label='【'+$status+'】 '+$r.Label
 $r|Add-Member Note $note
}
[void]$category.Items.Add('全部分类');foreach($g in ($rows.Group|Sort-Object -Unique)){[void]$category.Items.Add($g)};$category.SelectedIndex=0
$search=New-Object Windows.Forms.TextBox
$list=New-Object Windows.Forms.ListBox
$button=New-Object Windows.Forms.Button
$hint=New-Object Windows.Forms.Label
$hint.Text='双击材料，或选中后点击右侧按钮。'
Place $search 24 106 451 32 'Top,Left,Right'
Place $list 24 155 671 207 'Top,Left,Right,Bottom'
$list.IntegralHeight=$false;$list.BorderStyle='FixedSingle'
$detail=New-Object Windows.Forms.TextBox
$detail.Multiline=$true;$detail.ReadOnly=$true;$detail.ScrollBars='Vertical'
$badge=New-Object Windows.Forms.Label
$badge.BackColor=$accent;$badge.ForeColor=[Drawing.Color]::White
$badge.Font=New-Object Drawing.Font('Microsoft YaHei UI',12,[Drawing.FontStyle]::Bold)
$badge.TextAlign='MiddleLeft';Place $badge 24 369 671 31 'Bottom,Left,Right'
Place $detail 24 403 671 125 'Bottom,Left,Right'
Place $hint 24 549 450 40 'Bottom,Left,Right'
$button.Text='应用到当前零件';$button.FlatStyle='Flat';$button.FlatAppearance.BorderSize=0
$button.ForeColor=[Drawing.Color]::White;$button.BackColor=$accent
Place $button 504 538 191 44 'Bottom,Right'
$list.DisplayMember='Label'
$list.Add_SelectedIndexChanged({
 $r=$list.SelectedItem;if(!$r){return}
 try{
  $raw=[IO.File]::ReadAllText($r.Path)
  $desc=[regex]::Match($raw,"(?s)Name\s*=\s*PTC_MATERIAL_DESCRIPTION\s+Type\s*=\s*String\s+Default\s*=\s*'([^']*)'").Groups[1].Value
  $density=[regex]::Match($raw,'Name\s*=\s*PTC_MASS_DENSITY\s+Type\s*=\s*Real\s+Default\s*=\s*([^\r\n]+)').Groups[1].Value.Trim()
  $display=$density
  if($density -match '^([\d.eE+-]+)\s+(kg/mm\^3|kg/m\^3)$'){
   $factor=if($Matches[2] -eq 'kg/mm^3'){1e6}else{0.001}
   $display=('{0:0.####} g/cm³' -f ([double]::Parse($Matches[1],[cultureinfo]::InvariantCulture)*$factor))
  }
  $badge.Text="  $($r.Status)   |   $([IO.Path]::GetFileNameWithoutExtension($r.Path))   |   $display"
  if(!$r.Note -and $r.Status -eq '未注明具体牌号'){$r.Note='现有索引未确认厂商或完整牌号。请以 BOM、料袋或材质证明核对。'}
  $detail.Lines=@($r.Note; if($desc){"文件说明  $desc"}; if($density){"文件密度  $density"}; "文件位置  $($r.Path)") | Where-Object {$_}
 }catch{$detail.Text='无法读取材料说明：'+$r.Path}
})
$refresh={ $list.BeginUpdate();try{$list.Items.Clear();foreach($r in $rows){if(($category.SelectedIndex -eq 0 -or $r.Group -eq $category.SelectedItem) -and $r.Label.IndexOf($search.Text.Trim(),[StringComparison]::OrdinalIgnoreCase) -ge 0){[void]$list.Items.Add($r)}}}finally{$list.EndUpdate()};$button.Enabled=$list.Items.Count -gt 0;if($button.Enabled){$list.SelectedIndex=0}else{$detail.Text='没有匹配的材料，请更换分类或搜索词。'};$count.Text="当前 $($list.Items.Count) / $($rows.Count) 项" }
$category.Add_SelectedIndexChanged($refresh);$search.Add_TextChanged($refresh); & $refresh
$reportFolder=$null
$choose=New-Object Windows.Forms.Button
$choose.Text='报告目录…';Place $choose 360 538 133 43 'Bottom,Right'
$choose.Add_Click({$d=New-Object Windows.Forms.FolderBrowserDialog;$d.Description='选择 Creo 当前工作目录（质量报告保存位置）';if($d.ShowDialog() -eq 'OK'){$script:reportFolder=$d.SelectedPath};$d.Dispose()})
$read=New-Object Windows.Forms.Button
$read.Text='读取当前质量 (g)';Place $read 190 538 163 43 'Bottom,Right'
$hint.Width=155
$watch=New-Object Windows.Forms.Timer
$watch.Interval=300
$watch.Add_Tick({
 if($script:trailPath){
  try{$stream=[IO.File]::Open($script:trailPath,'Open','Read','ReadWrite');try{
    if($stream.Length -gt $script:trailOffset){$stream.Position=$script:trailOffset;$reader=[IO.StreamReader]::new($stream);$chunk=$reader.ReadToEnd();$script:trailOffset=$stream.Position
     if($chunk -match '(?im)^!%[^\r\n]*(未分配材料|未指定材料|没有分配材料|材料未分配|未定义密度|no material (?:is )?assigned|density is not defined)'){$watch.Stop();$hint.Text='请先应用材料';[void][Windows.Forms.MessageBox]::Show($form,'Creo 提示材料或密度未定义。请选择材料并点击「应用到当前零件」。','需要应用材料');return}
    }
  }finally{$stream.Dispose()}}catch{}
 }
 if([datetime]::UtcNow -gt $script:deadline){$watch.Stop();$hint.Text='未收到新报告';[void][Windows.Forms.MessageBox]::Show($form,'没有读到本次质量。请查看 Creo 的「已分配的材料」；如为空，请先应用材料。如已有材料，请核对报告目录。','质量待确认');return}
 $f=Get-Item -LiteralPath $script:report -ErrorAction SilentlyContinue
 if(!$f -or $f.LastWriteTimeUtc -le $script:baseline){return}
 try{$s=[IO.File]::ReadAllText($f.FullName)}catch{return}
 # Some Creo reports start directly with volume. Match the exact part filename
 # and fresh timestamp above; reject explicit body or assembly reports.
 if($s -match '(?im)^\s*(?:主体|组件|装配|body\b|assembly\b)'){return}
 $m=[regex]::Match($s,'(?im)^\s*(?:质量|mass)\s*=\s*([\d.+Ee-]+)\s*([^\r\n]+)')
 if(!$m.Success){return}
 if($s -match '(?im)^\s*(?:密度|density)\s*=\s*0(?:[.,]0+)?(?:e[+-]?\d+)?\s'){$watch.Stop();$hint.Text='材料密度为零';[void][Windows.Forms.MessageBox]::Show($form,'报告中的密度为零。请先应用有有效密度的材料。','检查材料');return}
 $units=@{'公吨'=1e6;'吨'=1e6;tonne=1e6;tonnes=1e6;'千克'=1000;'公斤'=1000;kg=1000;kilogram=1000;kilograms=1000;'克'=1;g=1;gram=1;grams=1;lbm=453.59237;'磅'=453.59237}
 $u=$m.Groups[2].Value.Trim();if(!$units.ContainsKey($u)){ $watch.Stop();$hint.Text="报告质量单位未识别：$u";return }
 $g=[double]::Parse($m.Groups[1].Value,[cultureinfo]::InvariantCulture)*$units[$u]
 $msg=('{0}   ·   {1:G9} g' -f $script:part,$g)
 $watch.Stop();$hint.Text=$msg
 $dialog=New-Object Windows.Forms.Form
 $dialog.Text='当前零件质量';$dialog.StartPosition='CenterParent';$dialog.ClientSize=New-Object Drawing.Size(380,185)
 $dialog.FormBorderStyle='FixedDialog';$dialog.MaximizeBox=$false;$dialog.MinimizeBox=$false
 $value=New-Object Windows.Forms.TextBox
 $value.Text=('{0:G9} g' -f $g);$value.ReadOnly=$true;$value.Font=New-Object Drawing.Font('Microsoft YaHei UI',19,[Drawing.FontStyle]::Bold)
 $value.SetBounds(20,18,340,43);$dialog.Controls.Add($value)
 $label=New-Object Windows.Forms.Label;$label.Text=$script:part;$label.SetBounds(20,66,340,24);$dialog.Controls.Add($label)
 $copy=New-Object Windows.Forms.Button;$copy.Text='复制质量';$copy.SetBounds(20,129,95,37)
 $copy.Add_Click({[Windows.Forms.Clipboard]::SetText($value.Text)});$dialog.Controls.Add($copy)
 $close=New-Object Windows.Forms.CheckBox;$close.Text='确认后关闭 Creo 质量窗口';$close.SetBounds(124,96,240,25);$dialog.Controls.Add($close)
 $ok=New-Object Windows.Forms.Button;$ok.Text='确认';$ok.SetBounds(265,129,95,37);$ok.DialogResult='OK';$dialog.AcceptButton=$ok;$dialog.Controls.Add($ok)
 $answer=$dialog.ShowDialog($form);$shouldClose=$answer -eq 'OK' -and $close.Checked;$dialog.Dispose()
 if($shouldClose){[CreoFocus]::CloseMassWindows([uint32]$script:creoPid)}
})
function Invoke-PartMass([bool]$assign){
 try {
  $item=$list.SelectedItem;if($assign -and !$item){return}
  $procs=@(Get-Process xtop -ErrorAction SilentlyContinue)
  if($procs.Count -ne 1){throw '请只打开一个 Creo 会话，并打开目标零件。'}
  $script:creoPid=$procs[0].Id
  $shell=New-Object -ComObject WScript.Shell
  [void]$shell.AppActivate($procs[0].Id)
  Start-Sleep -Milliseconds 250
  [uint32]$owner=0
  [void][CreoFocus]::GetWindowThreadProcessId([CreoFocus]::GetForegroundWindow(),[ref]$owner)
  if($owner -ne $procs[0].Id){throw '未能切换到 Creo。请打开目标零件并关闭其他对话框后重试。'}
  $watch.Stop();$hint.Text='等待读取本次零件质量…'
  $titleText=New-Object Text.StringBuilder 1024
  [void][CreoFocus]::GetWindowText([CreoFocus]::GetForegroundWindow(),$titleText,1024)
  $model=[regex]::Match($titleText.ToString(),'^\s*([^\s()]+)(?:\s*\(|\s+-\s+Creo)')
  if(!$model.Success){throw '请先激活目标零件的主窗口。'}
  $script:part=$model.Groups[1].Value -replace '(?i)\.prt$',''
  $dir=$reportFolder
  if(!$dir){$dir=[CreoFocus]::WorkingDir($procs[0].Handle)}
  if(!$dir -or !(Test-Path -LiteralPath $dir -PathType Container)){$dir=[Environment]::GetFolderPath('CommonDocuments')}
  $script:report=Join-Path $dir ($script:part+'.m_p')
  $script:baseline=[datetime]::UtcNow
  $trail=Get-ChildItem -LiteralPath $dir -Filter 'trail.txt.*' -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
  $script:trailPath=$null;if($trail){$script:trailPath=$trail.FullName;$script:trailOffset=$trail.Length}
  $script:deadline=$script:baseline.AddSeconds(35)
  $key=if($assign){$item.Key}else{'zmpmass'}
  [Windows.Forms.SendKeys]::SendWait($key)
  $watch.Start()
 }catch{[void][Windows.Forms.MessageBox]::Show($_.Exception.Message,'Creo 材料面板')}
}
$read.Add_Click({Invoke-PartMass $false})
$button.Add_Click({Invoke-PartMass $true});$list.Add_DoubleClick({Invoke-PartMass $true})
[void]$form.ShowDialog()

