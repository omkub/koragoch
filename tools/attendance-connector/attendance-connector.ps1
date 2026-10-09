<#
  ตัวเชื่อมเครื่องสแกนหน้า → ระบบลงเวลา (พาร์ท 7)
  ============================================================
  ใช้กับเครื่องที่ "ส่งข้อมูลออกทางอินเทอร์เน็ตเองไม่ได้" แต่ export ไฟล์ได้
  (หรือมีโปรแกรมของยี่ห้อที่ดึงข้อมูลจากเครื่องมาเก็บเป็นไฟล์บนคอมพิวเตอร์)

  ทำงาน: อ่านไฟล์ในโฟลเดอร์ที่กำหนด (CSV / TXT / DAT เช่น attlog.dat ของ ZKTeco)
         → หา "รหัสพนักงาน + วันเวลา" ในแต่ละบรรทัด
         → ส่งเข้า attendance-ingest ด้วยรหัสลับเครื่องที่ออกจาก web
         ส่งเฉพาะบรรทัดใหม่ (จำไว้ใน state.json) ส่งซ้ำก็ไม่เบิ้ล ฐานข้อมูลกันให้

  ใช้กับ Windows PowerShell 5.1 ที่มากับ Windows ได้เลย ไม่ต้องติดตั้งอะไรเพิ่ม

  วิธีใช้ (ดู README.md):
    powershell -ExecutionPolicy Bypass -File attendance-connector.ps1 -Test     ทดสอบรหัสลับ
    powershell -ExecutionPolicy Bypass -File attendance-connector.ps1 -DryRun   ดูว่าอ่านไฟล์ได้อะไร (ไม่ส่ง)
    powershell -ExecutionPolicy Bypass -File attendance-connector.ps1           ส่งรอบเดียว (ให้ Task Scheduler เรียกทุก 5 นาที)
#>
param(
  [string]$Config = (Join-Path $PSScriptRoot 'config.json'),
  [switch]$Test,
  [switch]$DryRun,
  [switch]$ResendAll
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch { }
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$BatchSize = 1000

function Write-Log([string]$message) {
  $line = '{0:yyyy-MM-dd HH:mm:ss}  {1}' -f (Get-Date), $message
  Write-Host $line
  try { Add-Content -Path (Join-Path $PSScriptRoot 'connector.log') -Value $line -Encoding UTF8 } catch { }
}

# ── ตั้งค่า ─────────────────────────────────────────────────────
if (-not (Test-Path $Config)) {
  Write-Log "ไม่พบไฟล์ตั้งค่า $Config — คัดลอก config.example.json เป็น config.json แล้วแก้ค่า"
  exit 2
}
$cfg = Get-Content $Config -Raw -Encoding UTF8 | ConvertFrom-Json
$url = [string]$cfg.url
$key = [string]$cfg.deviceKey
if (-not $url -or -not $key -or $key.Length -lt 20) {
  Write-Log 'config.json ต้องมี url และ deviceKey (รหัสลับเครื่องจาก web > ลงเวลา > เครื่องสแกน)'
  exit 2
}
$headers = @{ 'x-device-key' = $key }

function Invoke-Ingest([string]$method, $body) {
  $params = @{ Uri = $url; Method = $method; Headers = $headers; TimeoutSec = 60; UseBasicParsing = $true }
  if ($body) {
    # ส่งเป็น UTF-8 (PowerShell 5.1 ส่ง string แบบ ISO-8859-1 ถ้าไม่บังคับ)
    $params.Body = [Text.Encoding]::UTF8.GetBytes(($body | ConvertTo-Json -Depth 4 -Compress))
    $params.ContentType = 'application/json; charset=utf-8'
  }
  try {
    # อ่านคำตอบเป็น UTF-8 เอง (PowerShell 5.1 เดาเป็น ISO-8859-1 ถ้าไม่มี charset → ภาษาไทยเพี้ยน)
    $resp = Invoke-WebRequest @params
    $text = [Text.Encoding]::UTF8.GetString($resp.RawContentStream.ToArray())
    return $text | ConvertFrom-Json
  } catch {
    # PowerShell 5.1 ไม่ใส่ข้อความจากเซิร์ฟเวอร์ใน ErrorDetails — อ่านจาก response เอง
    $detail = $_.ErrorDetails.Message
    $response = $_.Exception.Response
    if (-not $detail -and $response) {
      try {
        $reader = New-Object IO.StreamReader($response.GetResponseStream(), [Text.Encoding]::UTF8)
        $detail = $reader.ReadToEnd()
      } catch { }
    }
    if ($detail) {
      try { $detail = ($detail | ConvertFrom-Json).error } catch { }
    }
    if (-not $detail) { $detail = $_.Exception.Message }
    throw "เรียกระบบไม่สำเร็จ: $detail"
  }
}

if ($Test) {
  try {
    $r = Invoke-Ingest 'GET' $null
    Write-Log "เชื่อมต่อสำเร็จ: เครื่อง `"$($r.device)`""
    exit 0
  } catch {
    Write-Log $_.Exception.Message
    exit 1
  }
}

# ── อ่านไฟล์ ────────────────────────────────────────────────────
$folder = [string]$cfg.folder
if (-not $folder -or -not (Test-Path $folder)) {
  Write-Log "ไม่พบโฟลเดอร์ $folder"
  exit 2
}
$patterns = @('*.csv', '*.txt', '*.dat', '*.tsv')
if ($cfg.filePattern) { $patterns = @([string]$cfg.filePattern) }
$dayFirst = $cfg.dateOrder -ne 'MDY'   # 09/10/2026 = 9 ต.ค. (ค่าเริ่มต้น แบบไทย)

$statePath = Join-Path $PSScriptRoot 'state.json'
$state = @{}
if ((Test-Path $statePath) -and -not $ResendAll) {
  (Get-Content $statePath -Raw -Encoding UTF8 | ConvertFrom-Json).PSObject.Properties |
    ForEach-Object { $state[$_.Name] = [int]$_.Value }
}

# วันเวลาในบรรทัด: 2026-10-09 07:45:12 / 2026/10/09 07:45 / 09/10/2026 07:45:12 / 09-10-2569 7:45
$reIso = [regex]'(?<y>\d{4})[-/.](?<m>\d{1,2})[-/.](?<d>\d{1,2})[ T]+(?<H>\d{1,2}):(?<M>\d{2})(:(?<S>\d{2}))?'
$reDmy = [regex]'(?<a>\d{1,2})[-/.](?<b>\d{1,2})[-/.](?<y>\d{4})[ T]+(?<H>\d{1,2}):(?<M>\d{2})(:(?<S>\d{2}))?'

function Parse-Line([string]$line) {
  $m = $reIso.Match($line)
  if ($m.Success) {
    $y = [int]$m.Groups['y'].Value; $mo = [int]$m.Groups['m'].Value; $d = [int]$m.Groups['d'].Value
  } else {
    $m = $reDmy.Match($line)
    if (-not $m.Success) { return $null }
    $y = [int]$m.Groups['y'].Value
    $a = [int]$m.Groups['a'].Value; $b = [int]$m.Groups['b'].Value
    if ($dayFirst) { $d = $a; $mo = $b } else { $mo = $a; $d = $b }
  }
  if ($y -gt 2400) { $y -= 543 }   # พ.ศ. → ค.ศ.
  if ($mo -lt 1 -or $mo -gt 12 -or $d -lt 1 -or $d -gt 31) { return $null }
  $sec = if ($m.Groups['S'].Success) { [int]$m.Groups['S'].Value } else { 0 }
  $time = '{0:0000}-{1:00}-{2:00} {3:00}:{4:00}:{5:00}' -f $y, $mo, $d, [int]$m.Groups['H'].Value, [int]$m.Groups['M'].Value, $sec

  # รหัสพนักงาน = ช่องแรก (ก่อนวันเวลา) ที่เป็นตัวเลข/ตัวอักษรล้วน
  $before = $line.Substring(0, $m.Index)
  $fields = $before -split '[,;\t|]' | ForEach-Object { $_.Trim().Trim('"') } | Where-Object { $_ -ne '' }
  $code = $null
  if ($cfg.codeColumn) {
    $all = $line -split '[,;\t|]' | ForEach-Object { $_.Trim().Trim('"') }
    $idx = [int]$cfg.codeColumn - 1
    if ($idx -lt $all.Count) { $code = $all[$idx] }
  } else {
    $code = $fields | Where-Object { $_ -match '^[A-Za-z0-9_-]{1,50}$' } | Select-Object -First 1
  }
  if (-not $code) { return $null }
  return @{ code = $code; time = $time }
}

$files = foreach ($p in $patterns) {
  Get-ChildItem -Path $folder -Filter $p -File -Recurse:([bool]$cfg.recurse) -ErrorAction SilentlyContinue
}

$pending = New-Object System.Collections.ArrayList
$newState = @{}
foreach ($file in $files) {
  $lines = [IO.File]::ReadAllLines($file.FullName, [Text.Encoding]::UTF8)
  $name = $file.FullName
  $start = if ($state.ContainsKey($name)) { $state[$name] } else { 0 }
  if ($start -gt $lines.Count) { $start = 0 }   # ไฟล์ถูก export ใหม่ (สั้นลง) — อ่านใหม่ทั้งไฟล์
  $parsed = 0
  for ($i = $start; $i -lt $lines.Count; $i++) {
    $row = Parse-Line $lines[$i]
    if ($row) { [void]$pending.Add($row); $parsed++ }
  }
  $newState[$name] = $lines.Count
  if ($lines.Count -gt $start) {
    Write-Log ("{0}: บรรทัดใหม่ {1} อ่านได้ {2} รายการ" -f $file.Name, ($lines.Count - $start), $parsed)
  }
}

if ($DryRun) {
  Write-Log "ทดลองอ่าน (ไม่ส่ง): $($pending.Count) รายการ"
  $pending | Select-Object -First 15 | ForEach-Object { Write-Host ("   รหัส {0,-10} เวลา {1}" -f $_.code, $_.time) }
  exit 0
}

if ($pending.Count -eq 0) {
  Write-Log 'ไม่มีข้อมูลใหม่'
  $newState | ConvertTo-Json | Set-Content -Path $statePath -Encoding UTF8
  exit 0
}

# ── ส่ง ────────────────────────────────────────────────────────
$inserted = 0; $dups = 0; $invalid = 0; $unmatched = 0
try {
  for ($i = 0; $i -lt $pending.Count; $i += $BatchSize) {
    $end = [Math]::Min($i + $BatchSize, $pending.Count) - 1
    $batch = @($pending[$i..$end])
    $r = Invoke-Ingest 'POST' @{ logs = $batch }
    $inserted += [int]$r.inserted; $dups += [int]$r.duplicates
    $invalid += [int]$r.invalid; $unmatched += [int]$r.unmatched
  }
} catch {
  Write-Log ($_.Exception.Message + ' — รอบหน้าจะส่งใหม่')
  exit 1
}
# จำว่าส่งถึงไหน หลังส่งสำเร็จทุกชุดเท่านั้น (ล้มกลางทาง = รอบหน้าส่งใหม่ ไม่เบิ้ล)
$newState | ConvertTo-Json | Set-Content -Path $statePath -Encoding UTF8
Write-Log ("ส่งแล้ว {0} รายการ: ใหม่ {1} ซ้ำ {2} ผิดรูปแบบ {3} รหัสยังไม่จับคู่ครู {4}" -f $pending.Count, $inserted, $dups, $invalid, $unmatched)
