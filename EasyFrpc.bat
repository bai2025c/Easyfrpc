<#*,:
@echo off
chcp 65001 >nul
cd /d "%~dp0"
set "batchfile=%~f0"
powershell -ExecutionPolicy Bypass -C "Set-Location -LiteralPath ([Environment]::CurrentDirectory);. ([ScriptBlock]::Create([IO.File]::ReadAllText($env:batchfile,[Text.Encoding]::UTF8 )) )"

exit /b
#>
$Host.UI.RawUI.WindowTitle = [IO.Path]::GetFileName($env:batchfile)

# 日志文件
$log = "myfrp.log"
# frpc.toml文件
$frpc = "frpc.toml"
# 文件备份格式
$backup_format = "{0}_{1:yyyyMMddHHmmss}.bak"
# 日志记录格式
$log_format = "[{0:yyyy-MM-dd HH:mm:ss}]`t[{1}]`t{2}"
# 指定的存档目录
$dirs = @(
  "${env:userprofile}\Documents\Klei\DoNotStarveTogether\Cluster_?\Caves"
  "${env:userprofile}\Documents\Klei\DoNotStarveTogether\Cluster_?\Masters"

)
# 动态端口分配区间 开区间
[int[]]$dynamic_port = 10800, 12000
# 自动端口分配区间 开区间
[int[]]$auto_port = 10801, 11999

# toml格式
$toml_format = @"

[[{0}]]
type = "udp"
local_ip = "127.0.0.1"
local_port = {0}
remote_port = {0}

"@

$reToml = [regex]'\[\[(\d+)\]\]'
$reDigit = [regex]'\d+'
$dirs = @($dirs | ForEach-Object { [IO.Path]::Combine($_, 'server.ini') })
[int[]]$auto_port2 = ($auto_port[0] + 1)..($auto_port[1] - 1)
$frpc_ports = New-Object 'System.Collections.Generic.List[int]'

$swLog = New-Object System.IO.StreamWriter -ArgumentList ($log, $true)
if (-not $?) { return }
# 读取server.ini的端口号
function Read-ServerIni {
  param([string]$Ini)
  $text = [IO.File]::ReadAllText($Ini)
  if ($text -match '(?mi)^(?>\s*)\[NETWORK\](?>\s*)server_port(?>\s*)=(?>\s*)(\d+)') {
    return $Matches[1] -as [int]
  } else {
    throw "文件 ${Ini} 找不到[NETWORK]的端口号."
  }
}
# 读取所有server.ini的端口号
function Read-AllServerIni {
  Get-ChildItem -Path $dirs -File | ForEach-Object {
    try {
      # 读取server.ini的[NETWORK]的server_port
      Read-ServerIni -Ini $_.FullName
    } catch {
      Write-MyLog ($_ | Out-String) -LogLevel Error
    }
  }
}
# 写入server.ini的端口号
function Write-ServerIni {
  param([string]$Ini, [int]$ServerPort)
  # Backup-MyFile -File $Ini
  $text = [IO.File]::ReadAllText($Ini)
  if ($text -match '(?mi)^(?>\s*)\[NETWORK\](?>\s*)server_port(?>\s*)=(?>\s*)(\d+)') {
    $text = $text -replace '(?mi)^((?>\s*)\[NETWORK\](?>\s*)server_port(?>\s*)=(?>\s*))(\d+)', "`${1}${ServerPort}"
  } else {
    $text = $text + @"

[NETWORK]
server_port = ${ServerPort}

"@
  }
  [IO.File]::WriteAllText($Ini, $text)
  Write-MyLog "写入端口号 ${ServerPort} 到 `"${Ini}`"" -LogLevel Info
}
# 读取frpc.toml
function Read-FrpcToml {
  param([string]$Toml)
  $text = [IO.File]::ReadAllText($Toml)
  foreach ($m in $reToml.Matches($text)) {
    $m.Groups[1].Value -as [int]
  }
}
# 写入frpc.toml
function Write-FrpcToml {
  param([string]$Toml, [int[]]$ServerPort)
  # Backup-MyFile -File $Toml
  if ($null -eq $ServerPort -or $ServerPort.Count -eq 0) { return }
  $append = @(
    foreach ($port in $ServerPort) {
      $toml_format -f $port
    }
  ) -join ""
  [IO.File]::AppendAllText($Toml, $append)
  Write-MyLog "写入端口号 ${ServerPort} 到 `"${Toml}`"" -LogLevel Info
}
# 备份文件
function Backup-MyFile {
  param([string]$File)
  $File = [IO.Path]::GetFullPath($File)
  $backup = $backup_format -f ($File, [DateTime]::Now)
  [IO.File]::Copy($File, $backup)
  Write-MyLog "备份文件 `"${File}`" 到 `"${backup}`"" -LogLevel Info
  $backup
}
# 写入日志
function Write-MyLog {
  param(
    [string]$Message,
    [ValidateSet('Error', 'Warning', 'Info')]
    [string]$LogLevel = 'Error')
  $msg = $log_format -f ([datetime]::Now, $LogLevel, $Message)
  # Add-Content -Value $msg -Path $log -Encoding utf8
  $swLog.WriteLine($msg)
  # [IO.File]::AppendAllText($log, "$msg`r`n")
  if ($LogLevel -eq 'Error') {
    Write-Host $msg -ForegroundColor Red
  } else {
    Write-Host $msg
  }
}
# 端口动态读取与写入功能
function DynamicReadWrite {
  try {
    # 先对`frpc.toml`文件进行备份
    $backup_frpc = Backup-MyFile -File $frpc
    # 遍历指定的存档目录的server.ini文件
    # 读取server.ini的[NETWORK]的server_port
    $frpc_ports.Clear()
    # 读取`frpc.toml`文件和所有`server.ini`文件中已配置的端口列表，确保新分配的端口不与已有端口重复
    [int[]]$serverIni_ports = @(Read-AllServerIni)
    [int[]]$used_ports = @(Read-FrpcToml $frpc)
    $unused_ports = [System.Linq.Enumerable]::ToArray([System.Linq.Enumerable]::Except($serverIni_ports, $used_ports))
    foreach ($server_port in $unused_ports) {
      try {
        # 检查端口号是否在10800 - 12000之间（开区间）
        if ($server_port -gt $dynamic_port[0] -and $server_port -lt $dynamic_port[1]) {
          $frpc_ports.Add($server_port)
        } else {
          Write-MyLog  "(动态分配端口) server_port:${server_port} 不在范围$($dynamic_port[0]) - $($dynamic_port[1])之间（开区间）" -LogLevel Error
        }
      } catch {
        Write-MyLog ($_ | Out-String) -LogLevel Error
      }
    }
    Write-FrpcToml -Toml $frpc -ServerPort $frpc_ports
  } catch {
    Write-MyLog ($_ | Out-String) -LogLevel Error
    if ($backup_frpc) {
      try {
        # 尝试恢复frpc的备份
        [IO.File]::Copy($backup_frpc, $frpc, $true)
      } catch {
        Write-MyLog ($_ | Out-String) -LogLevel Error
      }
    }
  }
}
# 自动分配端口
function AutoReadWrite {
  try {
    # 先对`frpc.toml`文件进行备份
    $backup_frpc = Backup-MyFile -File $frpc
    # 读取`frpc.toml`文件和所有`server.ini`文件中已配置的端口列表，确保新分配的端口不与已有端口重复
    [int[]]$used_ports = @(
      Read-AllServerIni
      Read-FrpcToml $frpc
    )
    $unused_ports = [System.Linq.Enumerable]::ToArray([System.Linq.Enumerable]::Except($auto_port2, $used_ports))
    if ($unused_ports.Count -gt 0) {
      $frpc_ports.Clear()
      $serverInis = @(Get-ChildItem -Path $dirs -File)
      $minCount = [Math]::Min($serverInis.Count, $unused_ports.Count)
      for ($i = 0; $i -lt $minCount; ++$i) {
        try {
          $backup_serverIni = Backup-MyFile -File $serverInis[$i].FullName
          Write-ServerIni -Ini $serverInis[$i].FullName -ServerPort $unused_ports[$i]
          $frpc_ports.Add($unused_ports[$i])
        } catch {
          Write-MyLog ($_ | Out-String) -LogLevel Error
          if ($backup_serverIni) {
            try {
              # 尝试恢复server.ini的备份
              [IO.File]::Copy($backup_serverIni, $serverInis[$i].FullName, $true)
              $backup_serverIni = $null
            } catch {
              Write-MyLog ($_ | Out-String) -LogLevel Error
            }
          }
        }
      }
      Write-FrpcToml -Toml $frpc -ServerPort $frpc_ports
    } else {
      # 遍历完10801 - 11999都未找到可用端口，则停止分配并给出明确提示，告知用户端口分配失败及原因
      Write-MyLog "(自动分配端口) 在范围 $($auto_port[0]) - $($auto_port[-1]) 没有可用端口（开区间）!" -LogLevel Error
    }
  } catch {
    Write-MyLog ($_ | Out-String) -LogLevel Error
    if ($backup_frpc) {
      try {
        # 尝试恢复frpc的备份
        [IO.File]::Copy($backup_frpc, $frpc, $true)
      } catch {
        Write-MyLog ($_ | Out-String) -LogLevel Error
      }
    }
  }
}

# 手动添加端口
function Add-FrpcPort {
  try {
    $input_ports = Read-Host -Prompt "请输入要添加的端口( $($dynamic_port[0]) - $($dynamic_port[-1]) 之间 开区间，用空格隔开)"
    if ($input_ports -notmatch '\d') { return }
    # 先对`frpc.toml`文件进行备份
    $backup_frpc = Backup-MyFile -File $frpc
    $used_ports = @(Read-FrpcToml $frpc)
    $frpc_ports.Clear()
    foreach ($m in $reDigit.Matches($input_ports)) {
      try {
        $server_port = [int]$m.Value
        # 检查端口号是否在10800 - 12000之间（开区间）
        if ($server_port -gt $dynamic_port[0] -and $server_port -lt $dynamic_port[1]) {
          if ($used_ports -contains $server_port) {
            Write-MyLog  "(手动分配端口) server_port:${server_port} 已存在 文件 `"${frpc}`" 中"
          } else {
            $frpc_ports.Add($server_port)
          }
        } else {
          Write-MyLog  "(手动分配端口) server_port:${server_port} 不在范围$($dynamic_port[0]) - $($dynamic_port[1])之间（开区间）"
        }
      } catch {
        Write-MyLog ($_ | Out-String) -LogLevel Error
      }
    }
    Write-FrpcToml -Toml $frpc -ServerPort $frpc_ports
  } catch {
    Write-MyLog ($_ | Out-String) -LogLevel Error
    if ($backup_frpc) {
      try {
        # 尝试恢复frpc的备份
        [IO.File]::Copy($backup_frpc, $frpc, $true)
      } catch {
        Write-MyLog ($_ | Out-String) -LogLevel Error
      }
    }
  }
}
# 手动删除端口
function Remove-FrpcPort {
  try {
    $input_ports = Read-Host -Prompt "请输入要删除的端口(用空格隔开)"
    if ($input_ports -notmatch '\d') { return }
    # 备份文件frpc.toml
    $backup_frpc = Backup-MyFile -File $frpc
    $text = [IO.File]::ReadAllText($frpc)
    foreach ($m in $reDigit.Matches($input_ports)) {
      try {
        $server_port = [int]$m.Value
        if ($text -match "\[\[${server_port}\]\]") {
          $text = $text -replace "(?s)\[\[${server_port}\]\].*?(?=\[\[\d+\]\]|\z)"
          Write-MyLog "从 `"${frpc}`" 删除端口号 ${server_port} 成功" -LogLevel Info
        } else {
          Write-MyLog "(手动分配端口) 端口号:${server_port} 不存在于 文件 `"${frpc}`" 中"
        }
      } catch {
        Write-MyLog ($_ | Out-String) -LogLevel Error
      }
    }
    [IO.File]::WriteAllText($frpc, $text)
  } catch {
    Write-MyLog ($_ | Out-String) -LogLevel Error
    if ($backup_frpc) {
      try {
        # 尝试恢复frpc的备份
        [IO.File]::Copy($backup_frpc, $frpc, $true)
      } catch {
        Write-MyLog ($_ | Out-String) -LogLevel Error
      }
    }
  }
}
# 查看已有端口
function Show-FrpcPort {
  try {
     (Read-FrpcToml $frpc | Sort-Object) -join ' '
  } catch {
    Write-MyLog ($_ | Out-String) -LogLevel Error
  }
}
Write-Output "请先使用选项[8]bak.bat进行存档server.ini备份与恢复！！！"
# 菜单
$menus = @(
	
  "`t[0]`t查看frpc.toml已有端口"
  "`t[1]`t从'server.ini'读取端口写入'frpc.toml'"
  "`t[2]`t自动给存档分配端口"
  "`t[3]`t手动添加端口"
  "`t[4]`t手动删除端口"
  "`t[5]`t清屏"
  "`t[6]`t退出"
  "`t[7]`t启动"
  "`t[8]`t请先使用选项[8]bak.bat进行存档server.ini备份与恢复！！！"


)
function Show-Menu {
  "`t`t菜单" | Write-Host -ForegroundColor Cyan
  $menus | Write-Host -ForegroundColor Yellow

  $choices = New-Object 'System.Collections.ObjectModel.Collection[System.Management.Automation.Host.ChoiceDescription]'
  for ($i = 0; $i -lt $menus.Count; $i++) {
    $choices.Add((New-Object 'System.Management.Automation.Host.ChoiceDescription' -ArgumentList ("${i}", $menus[$i])))
  }
  $choice = $Host.UI.PromptForChoice('请选择', '请选择操作序号:', $choices, 0)
  if ($choice -ge 0) {
    if ($choice -eq 0) {
      # 查看frpc.toml已有端口
      Show-FrpcPort
    } elseif ($choice -eq 1) {
      # '从`server.ini`读取端口写入`frpc.toml` '
      DynamicReadWrite 
    } elseif ($choice -eq 2) {
      # '自动给存档分配端口'
      AutoReadWrite
    } elseif ($choice -eq 3) {
      # '手动添加端口'
      Add-FrpcPort
    } elseif ($choice -eq 4) {
      # '手动删除端口'
      Remove-FrpcPort
    } elseif ($choice -eq 5) {
      Clear-Host
    } elseif ($choice -eq 6) {
      $swLog.Close()
     } elseif ($choice -eq 7) {
	cd .\frpc; .\frpc.exe -c frpc.toml
    } elseif ($choice -eq 8) {
# 保存当前编码设置
$originalEncoding = [Console]::OutputEncoding

# 设置为 ANSI 编码（中文系统代码页 936）
[Console]::OutputEncoding = [System.Text.Encoding]::GetEncoding(936)

# 同步调用 BAT 文件（在当前窗口执行并等待）
cmd /c "bakg00.bat"

# 恢复原始编码
[Console]::OutputEncoding = $originalEncoding
      exit  

   

  }
 }
}
# 显示菜单
while ($true) {
Write-Host "当前frpc版本：" -ForegroundColor Blue
cd .\; .\frpc.exe --version
  Show-Menu
}
