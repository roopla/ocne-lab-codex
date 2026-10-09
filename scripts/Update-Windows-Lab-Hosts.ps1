$ErrorActionPreference='Stop'
$labRoot='D:\OCNE19-Lab'
$hostsPath='C:\Windows\System32\drivers\etc\hosts'
$original=[IO.File]::ReadAllText($hostsPath)
$backup=Join-Path $labRoot ('logs\windows-hosts-before-'+(Get-Date -Format yyyyMMdd-HHmmss)+'.txt')
[IO.File]::WriteAllText($backup,$original)
$aliases=@('ocne-op','ocne-cp','ocne-w1','ocne-w2','ocne-op.lab.test','ocne-cp.lab.test','ocne-w1.lab.test','ocne-w2.lab.test')
$result=foreach ($line in ($original -split '\r?\n')) {
 if ($line -match '^\s*#' -or $line -notmatch '\S') { $line; continue }
 $parts=$line -split '#',2
 $fields=@($parts[0].Trim() -split '\s+')
 $retained=@($fields | Select-Object -Skip 1 | Where-Object { $_ -notin $aliases })
 if ($retained.Count -eq ($fields.Count-1)) { $line; continue }
 if ($retained.Count -gt 0) {
  $rewritten=$fields[0]+'  '+($retained -join ' ')
  if ($parts.Count -gt 1) { $rewritten+=' #'+$parts[1] }
  $rewritten
 }
}
$result+= '# OCNE 1.9 clones - D:\OCNE19-Lab (guest NAT addresses; SSH uses configured forwarding)'
$result+= '192.168.77.10  ocne-op.lab.test ocne-op'
$result+= '192.168.77.11  ocne-cp.lab.test ocne-cp'
$result+= '192.168.77.12  ocne-w1.lab.test ocne-w1'
$result+= '192.168.77.13  ocne-w2.lab.test ocne-w2'
[IO.File]::WriteAllText($hostsPath,($result -join "`r`n")+"`r`n",[Text.Encoding]::ASCII)
Clear-DnsClientCache
foreach ($name in @('ocne-op','ocne-cp','ocne-w1','ocne-w2')) { "$name $([Net.Dns]::GetHostAddresses($name).IPAddressToString -join ',')" }