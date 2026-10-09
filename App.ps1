# -*- coding: utf-8 -*-
# AION 2 国际服简繁一键汉化大师 - 原生独立GUI图形版
# 作者: B站@吃素的佩奇
# 开源主页: https://github.com/duoluoyuji/Aion2-Steam-CN

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

[System.Windows.Forms.Application]::EnableVisualStyles()

$ToolDir        = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$ZhDir          = Join-Path $ToolDir 'zh'
$ZhTwDir        = Join-Path $ToolDir 'zh-TW'
$CurrentVersion = '1.2.0'
$AppIds         = @('3393110', '4972320')
$RemoteVersionUrl   = 'https://raw.githubusercontent.com/duoluoyuji/Aion2-Steam-CN/main/version.json'
$FallbackVersionUrl = 'https://ghp.ci/https://raw.githubusercontent.com/duoluoyuji/Aion2-Steam-CN/main/version.json'

# ==================== 扫描游戏函数 ====================
function Get-AllGameRoots {
    param([scriptblock]$LogCallback)

    function Write-Log($msg) {
        if ($LogCallback) { & $LogCallback $msg }
    }

    $detected = @()
    $fixedDrives = (Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Free -ne $null -and $_.Root }).Root
    
    # ---------------- 1. 扫描 Steam 游戏库 ----------------
    Write-Log "[扫描] 正在扫描全盘 Steam 游戏库与清单..."
    $steamRoots = @()
    foreach ($d in $fixedDrives) {
        $candidates = @(
            (Join-Path $d 'SteamLibrary\steamapps'),
            (Join-Path $d 'steamapps'),
            (Join-Path $d 'Program Files (x86)\Steam\steamapps'),
            (Join-Path $d 'Program Files\Steam\steamapps'),
            (Join-Path $d 'Steam\steamapps')
        )
        foreach ($c in $candidates) {
            if (Test-Path $c) { $steamRoots += $c }
        }
    }
    
    try {
        $reg = Get-ItemProperty -Path "HKCU:\Software\Valve\Steam" -ErrorAction SilentlyContinue
        if ($reg -and $reg.SteamPath) {
            $regApps = Join-Path $reg.SteamPath 'steamapps'
            if (Test-Path $regApps) { $steamRoots += $regApps }
        }
    } catch {}

    $steamRoots = $steamRoots | Select-Object -Unique

    foreach ($r in $steamRoots) {
        foreach ($aid in $AppIds) {
            $acf = Join-Path $r "appmanifest_$aid.acf"
            if (Test-Path $acf) {
                try {
                    $txt = Get-Content $acf -Raw -ErrorAction SilentlyContinue
                    if ($txt -match '"installdir"\s+"([^"]+)"') {
                        $gameAbs = Join-Path (Join-Path $r 'common') $matches[1]
                        if (Test-Path (Join-Path $gameAbs 'Aion2\Content\Paks\L10N')) {
                            $label = if ($aid -eq '3393110') { "Steam 国际正式版" } else { "Steam 测试服版" }
                            if (-not ($detected | Where-Object { $_.Path.ToLower() -eq $gameAbs.ToLower() })) {
                                $detected += [PSCustomObject]@{
                                    ClientType = $label
                                    Path       = $gameAbs
                                }
                            }
                        }
                    }
                } catch {}
            }
        }

        $common = Join-Path $r 'common'
        if (Test-Path $common) {
            $hits = Get-ChildItem $common -Directory -ErrorAction SilentlyContinue | Where-Object {
                Test-Path (Join-Path $_.FullName 'Aion2\Content\Paks\L10N')
            }
            foreach ($h in $hits) {
                if (-not ($detected | Where-Object { $_.Path.ToLower() -eq $h.FullName.ToLower() })) {
                    $detected += [PSCustomObject]@{
                        ClientType = "Steam 游戏库 ($($h.Name))"
                        Path       = $h.FullName
                    }
                }
            }
        }
    }

    # ---------------- 2. 三重增强：扫描 NCSoft PURPLE (紫P) 客户端 ----------------
    Write-Log "[扫描] 正在执行 PURPLE (紫P) 三重增强扫描..."
    # 增强 1：从 plaync 官方注册表枚举 BaseDir
    $playncRegKeys = @(
        "HKLM:\SOFTWARE\plaync",
        "HKLM:\SOFTWARE\WOW6432Node\plaync",
        "HKCU:\SOFTWARE\plaync"
    )
    foreach ($rk in $playncRegKeys) {
        try {
            if (Test-Path $rk) {
                $subKeys = Get-ChildItem -Path $rk -ErrorAction SilentlyContinue
                foreach ($sk in $subKeys) {
                    $props = Get-ItemProperty -Path $sk.PSPath -ErrorAction SilentlyContinue
                    if ($props -and $props.BaseDir) {
                        $bPath = $props.BaseDir.ToString().TrimEnd('\')
                        if (Test-Path (Join-Path $bPath 'Aion2\Content\Paks\L10N')) {
                            if (-not ($detected | Where-Object { $_.Path.ToLower() -eq $bPath.ToLower() })) {
                                $detected += [PSCustomObject]@{
                                    ClientType = "NCSoft PURPLE 国际服 (注册表定位)"
                                    Path       = $bPath
                                }
                            }
                        }
                    }
                }
            }
        } catch {}
    }

    # 增强 2：从 Windows 软件卸载列表中精确匹配 AION 2 / PURPLE 安装目录
    $uninstallRegKeys = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall"
    )
    foreach ($uk in $uninstallRegKeys) {
        try {
            if (Test-Path $uk) {
                $subKeys = Get-ChildItem -Path $uk -ErrorAction SilentlyContinue
                foreach ($sk in $subKeys) {
                    $props = Get-ItemProperty -Path $sk.PSPath -ErrorAction SilentlyContinue
                    if ($props) {
                        $dName = $props.DisplayName
                        $iLoc = $props.InstallLocation
                        if ($dName -and ($dName -like "*AION*" -or $dName -like "*Purple*") -and $iLoc) {
                            $cleanLoc = $iLoc.ToString().TrimEnd('\')
                            if (Test-Path (Join-Path $cleanLoc 'Aion2\Content\Paks\L10N')) {
                                if (-not ($detected | Where-Object { $_.Path.ToLower() -eq $cleanLoc.ToLower() })) {
                                    $detected += [PSCustomObject]@{
                                        ClientType = "NCSoft PURPLE 国际服 (系统识别)"
                                        Path       = $cleanLoc
                                    }
                                }
                            }
                        }
                    }
                }
            }
        } catch {}
    }

    # 增强 3：全盘常见默认路径深度匹配池
    foreach ($d in $fixedDrives) {
        $purpleCandidates = @(
            (Join-Path $d 'AION 2'),
            (Join-Path $d 'Aion2'),
            (Join-Path $d 'Games\AION 2'),
            (Join-Path $d 'Games\Aion2'),
            (Join-Path $d 'PurpleGames\AION 2'),
            (Join-Path $d 'PurpleGames\Aion2'),
            (Join-Path $d 'Purple\Games\AION 2'),
            (Join-Path $d 'NC\AION 2'),
            (Join-Path $d 'NCSOFT\AION 2'),
            (Join-Path $d 'NCSOFT\Purple\Games\AION 2'),
            (Join-Path $d 'Program Files\NCSOFT\Purple\AION 2'),
            (Join-Path $d 'Program Files (x86)\NCSOFT\Purple\AION 2')
        )
        foreach ($pc in $purpleCandidates) {
            if (Test-Path (Join-Path $pc 'Aion2\Content\Paks\L10N')) {
                if (-not ($detected | Where-Object { $_.Path.ToLower() -eq $pc.ToLower() })) {
                    $detected += [PSCustomObject]@{
                        ClientType = "NCSoft PURPLE 国际服 (全盘扫描)"
                        Path       = $pc
                    }
                }
            }
        }
    }

    return $detected
}

# ==================== 构建独立现代化 UI 窗口 ====================
$mainForm = New-Object System.Windows.Forms.Form
$mainForm.Text = "永恒之塔2 (AION 2) 国际服简繁一键汉化 v$CurrentVersion - B站@吃素的佩奇"
$mainForm.Size = New-Object System.Drawing.Size(760, 725)
$mainForm.StartPosition = 'CenterScreen'
$mainForm.FormBorderStyle = 'FixedDialog'
$mainForm.MaximizeBox = $false
# 现代桌面专业配色：清晰高对比度，告别发暗发糊
$mainForm.BackColor = [System.Drawing.Color]::FromArgb(243, 244, 246)
$mainForm.ForeColor = [System.Drawing.Color]::FromArgb(31, 41, 55)
$mainForm.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 9.5)

# --- 顶部头部面板 ---
$topPanel = New-Object System.Windows.Forms.Panel
$topPanel.Dock = 'Top'
$topPanel.Height = 72
$topPanel.BackColor = [System.Drawing.Color]::FromArgb(255, 255, 255)
$topPanel.BorderStyle = 'None'

$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Text = "永恒之塔2 (AION 2) 国际服简繁一键汉化"
$lblTitle.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 16, [System.Drawing.FontStyle]::Bold)
$lblTitle.ForeColor = [System.Drawing.Color]::FromArgb(17, 24, 39)
$lblTitle.Location = New-Object System.Drawing.Point(22, 20)
$lblTitle.AutoSize = $true

$btnBili = New-Object System.Windows.Forms.Button
$btnBili.Text = "关注作者B站"
$btnBili.Location = New-Object System.Drawing.Point(620, 18)
$btnBili.Size = New-Object System.Drawing.Size(100, 36)
$btnBili.BackColor = [System.Drawing.Color]::FromArgb(251, 114, 153)
$btnBili.ForeColor = [System.Drawing.Color]::White
$btnBili.FlatStyle = 'Flat'
$btnBili.FlatAppearance.BorderSize = 0
$btnBili.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 9, [System.Drawing.FontStyle]::Bold)
$btnBili.Cursor = [System.Windows.Forms.Cursors]::Hand
$btnBili.Add_Click({ [System.Diagnostics.Process]::Start("https://space.bilibili.com/3379443") })

$topPanel.Controls.AddRange(@($lblTitle, $btnBili))
$mainForm.Controls.Add($topPanel)

# --- 客户端识别区域 ---
$grpClients = New-Object System.Windows.Forms.GroupBox
$grpClients.Text = " 游戏客户端检测 (支持 Steam / 紫P 同时汉化) "
$grpClients.Location = New-Object System.Drawing.Point(20, 98)
$grpClients.Size = New-Object System.Drawing.Size(705, 142)
$grpClients.ForeColor = [System.Drawing.Color]::FromArgb(31, 41, 55)
$grpClients.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 9.5, [System.Drawing.FontStyle]::Bold)

$chkListClients = New-Object System.Windows.Forms.CheckedListBox
$chkListClients.Location = New-Object System.Drawing.Point(16, 26)
$chkListClients.Size = New-Object System.Drawing.Size(550, 100)
$chkListClients.BackColor = [System.Drawing.Color]::FromArgb(255, 255, 255)
$chkListClients.ForeColor = [System.Drawing.Color]::FromArgb(17, 24, 39)
$chkListClients.BorderStyle = 'FixedSingle'
$chkListClients.CheckOnClick = $true
$chkListClients.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 9.5)

$btnRescan = New-Object System.Windows.Forms.Button
$btnRescan.Text = "重新深度扫描"
$btnRescan.Location = New-Object System.Drawing.Point(580, 26)
$btnRescan.Size = New-Object System.Drawing.Size(110, 42)
$btnRescan.BackColor = [System.Drawing.Color]::FromArgb(255, 255, 255)
$btnRescan.ForeColor = [System.Drawing.Color]::FromArgb(55, 65, 81)
$btnRescan.FlatStyle = 'Flat'
$btnRescan.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(209, 213, 219)
$btnRescan.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 9)
$btnRescan.Cursor = [System.Windows.Forms.Cursors]::Hand

$btnBrowse = New-Object System.Windows.Forms.Button
$btnBrowse.Text = "手动选择路径"
$btnBrowse.Location = New-Object System.Drawing.Point(580, 80)
$btnBrowse.Size = New-Object System.Drawing.Size(110, 42)
$btnBrowse.BackColor = [System.Drawing.Color]::FromArgb(255, 255, 255)
$btnBrowse.ForeColor = [System.Drawing.Color]::FromArgb(55, 65, 81)
$btnBrowse.FlatStyle = 'Flat'
$btnBrowse.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(209, 213, 219)
$btnBrowse.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 9)
$btnBrowse.Cursor = [System.Windows.Forms.Cursors]::Hand

$grpClients.Controls.AddRange(@($chkListClients, $btnRescan, $btnBrowse))
$mainForm.Controls.Add($grpClients)

# --- 免责声明与操作区域 ---
$grpActions = New-Object System.Windows.Forms.GroupBox
$grpActions.Text = " 汉化与还原操作 "
$grpActions.Location = New-Object System.Drawing.Point(20, 250)
$grpActions.Size = New-Object System.Drawing.Size(705, 172)
$grpActions.ForeColor = [System.Drawing.Color]::FromArgb(31, 41, 55)
$grpActions.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 9.5, [System.Drawing.FontStyle]::Bold)

$lblDiscText = New-Object System.Windows.Forms.Label
$lblDiscText.Text = "本工具完全免费且开源，仅供个人交流学习，严禁任何淘宝/网店倒卖牟利！"
$lblDiscText.Location = New-Object System.Drawing.Point(16, 24)
$lblDiscText.Size = New-Object System.Drawing.Size(675, 24)
$lblDiscText.ForeColor = [System.Drawing.Color]::FromArgb(75, 85, 99)
$lblDiscText.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 9.5)

$chkAgree = New-Object System.Windows.Forms.CheckBox
$chkAgree.Text = "我已知晓安装汉化将替换客户端文本数据，自愿承担相关风险，承诺不用于商业牟利"
$chkAgree.Location = New-Object System.Drawing.Point(16, 56)
$chkAgree.Size = New-Object System.Drawing.Size(670, 26)
$chkAgree.ForeColor = [System.Drawing.Color]::FromArgb(180, 83, 9)
$chkAgree.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 9.5, [System.Drawing.FontStyle]::Bold)
$chkAgree.Cursor = [System.Windows.Forms.Cursors]::Hand

$btnInstallZh = New-Object System.Windows.Forms.Button
$btnInstallZh.Text = "一键应用【简体中文】"
$btnInstallZh.Location = New-Object System.Drawing.Point(18, 96)
$btnInstallZh.Size = New-Object System.Drawing.Size(205, 54)
$btnInstallZh.BackColor = [System.Drawing.Color]::FromArgb(229, 231, 235)
$btnInstallZh.ForeColor = [System.Drawing.Color]::FromArgb(156, 163, 175)
$btnInstallZh.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 11, [System.Drawing.FontStyle]::Bold)
$btnInstallZh.FlatStyle = 'Flat'
$btnInstallZh.FlatAppearance.BorderSize = 0
$btnInstallZh.Enabled = $false
$btnInstallZh.Cursor = [System.Windows.Forms.Cursors]::Hand

$btnInstallTw = New-Object System.Windows.Forms.Button
$btnInstallTw.Text = "一键应用【繁体中文】"
$btnInstallTw.Location = New-Object System.Drawing.Point(248, 96)
$btnInstallTw.Size = New-Object System.Drawing.Size(205, 54)
$btnInstallTw.BackColor = [System.Drawing.Color]::FromArgb(229, 231, 235)
$btnInstallTw.ForeColor = [System.Drawing.Color]::FromArgb(156, 163, 175)
$btnInstallTw.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 11, [System.Drawing.FontStyle]::Bold)
$btnInstallTw.FlatStyle = 'Flat'
$btnInstallTw.FlatAppearance.BorderSize = 0
$btnInstallTw.Enabled = $false
$btnInstallTw.Cursor = [System.Windows.Forms.Cursors]::Hand

$btnRestore = New-Object System.Windows.Forms.Button
$btnRestore.Text = "一键还原【官方英文】"
$btnRestore.Location = New-Object System.Drawing.Point(480, 96)
$btnRestore.Size = New-Object System.Drawing.Size(205, 54)
$btnRestore.BackColor = [System.Drawing.Color]::FromArgb(220, 38, 38)
$btnRestore.ForeColor = [System.Drawing.Color]::White
$btnRestore.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 11, [System.Drawing.FontStyle]::Bold)
$btnRestore.FlatStyle = 'Flat'
$btnRestore.FlatAppearance.BorderSize = 0
$btnRestore.Cursor = [System.Windows.Forms.Cursors]::Hand

# 勾选免责声明联动控制
$chkAgree.Add_CheckedChanged({
    if ($chkAgree.Checked) {
        $btnInstallZh.Enabled = $true
        $btnInstallZh.BackColor = [System.Drawing.Color]::FromArgb(22, 163, 74)
        $btnInstallZh.ForeColor = [System.Drawing.Color]::White

        $btnInstallTw.Enabled = $true
        $btnInstallTw.BackColor = [System.Drawing.Color]::FromArgb(2, 132, 199)
        $btnInstallTw.ForeColor = [System.Drawing.Color]::White
        Append-Log "已确认免责声明，汉化功能已解锁。"
    } else {
        $btnInstallZh.Enabled = $false
        $btnInstallZh.BackColor = [System.Drawing.Color]::FromArgb(229, 231, 235)
        $btnInstallZh.ForeColor = [System.Drawing.Color]::FromArgb(156, 163, 175)

        $btnInstallTw.Enabled = $false
        $btnInstallTw.BackColor = [System.Drawing.Color]::FromArgb(229, 231, 235)
        $btnInstallTw.ForeColor = [System.Drawing.Color]::FromArgb(156, 163, 175)
        Append-Log "请勾选上方免责声明以启用汉化按钮。"
    }
})

$grpActions.Controls.AddRange(@($lblDiscText, $chkAgree, $btnInstallZh, $btnInstallTw, $btnRestore))
$mainForm.Controls.Add($grpActions)

# --- 交互日志输出区域 ---
$grpLog = New-Object System.Windows.Forms.GroupBox
$grpLog.Text = " 操作实时日志与状态提示 "
$grpLog.Location = New-Object System.Drawing.Point(20, 432)
$grpLog.Size = New-Object System.Drawing.Size(705, 235)
$grpLog.ForeColor = [System.Drawing.Color]::FromArgb(31, 41, 55)
$grpLog.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 9.5, [System.Drawing.FontStyle]::Bold)

$txtLog = New-Object System.Windows.Forms.TextBox
$txtLog.Location = New-Object System.Drawing.Point(16, 25)
$txtLog.Size = New-Object System.Drawing.Size(675, 195)
$txtLog.Multiline = $true
$txtLog.ReadOnly = $true
$txtLog.ScrollBars = 'Vertical'
$txtLog.BackColor = [System.Drawing.Color]::FromArgb(17, 24, 39)
$txtLog.ForeColor = [System.Drawing.Color]::FromArgb(52, 211, 153)
$txtLog.Font = New-Object System.Drawing.Font("Consolas", 9.5)

$grpLog.Controls.Add($txtLog)
$mainForm.Controls.Add($grpLog)

# ==================== 辅助 UI 日志函数 ====================
function Append-Log($msg) {
    $time = (Get-Date).ToString("HH:mm:ss")
    $txtLog.AppendText("[$time] $msg`r`n")
    $txtLog.SelectionStart = $txtLog.TextLength
    $txtLog.ScrollToCaret()
    [System.Windows.Forms.Application]::DoEvents()
}

$Global:DetectedRoots = @()

function Run-Scan {
    $chkListClients.Items.Clear()
    $Global:DetectedRoots = @()
    Append-Log "正在执行全盘与注册表深度扫描..."
    
    $roots = @(Get-AllGameRoots -LogCallback { param($m) Append-Log $m })
    $Global:DetectedRoots = $roots
    
    $foundCount = $roots.Count
    if ($foundCount -eq 0) {
        Append-Log "【提示】未扫描到 AION 2 游戏目录，请确认游戏是否已下载完成，或点击[手动选择路径]。"
    } else {
        foreach ($r in $roots) {
            $idx = $chkListClients.Items.Add("[$($r.ClientType)] $($r.Path)", $true)
            Append-Log "-> 检出客户端: $($r.ClientType) -> $($r.Path)"
        }
        Append-Log "共成功识别到 $foundCount 个有效游戏客户端版本！"
    }
}

# --- 重新扫描按钮 ---
$btnRescan.Add_Click({
    Run-Scan
})

# --- 手动浏览按钮 ---
$btnBrowse.Add_Click({
    $fbd = New-Object System.Windows.Forms.FolderBrowserDialog
    $fbd.Description = "请选择 AION 2 游戏根目录（包含 Aion2 文件夹的目录）"
    if ($fbd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $p = $fbd.SelectedPath
        $exe = Join-Path $p "Aion2\Binaries\Win64\Aion2-Win64-Shipping.exe"
        if (Test-Path $exe) {
            $obj = [PSCustomObject]@{
                ClientType = "手动选择客户端"
                Path       = $p
            }
            $Global:DetectedRoots += $obj
            $chkListClients.Items.Add("[$($obj.ClientType)] $($obj.Path)", $true)
            Append-Log "手动添加客户端成功: $p"
        } else {
            [System.Windows.Forms.MessageBox]::Show("所选目录未包含 AION 2 游戏可执行文件，请检查！", "路径错误", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        }
    }
})

# --- 获取选中的客户端 ---
function Get-SelectedTargets {
    $selected = @()
    for ($i = 0; $i -lt $chkListClients.Items.Count; $i++) {
        if ($chkListClients.GetItemChecked($i)) {
            $selected += $Global:DetectedRoots[$i].Path
        }
    }
    return $selected
}

# --- 安全释放冲突进程 ---
function Release-FileLocks {
    Append-Log "正在检查游戏与启动器冲突进程并释放文件锁..."
    $conflictList = @("Aion2", "Aion2-Win64-Shipping", "NCLauncher", "NCLauncher2", "Purple", "PurpleApp")
    foreach ($proc in $conflictList) {
        $p = Get-Process -Name $proc -ErrorAction SilentlyContinue
        if ($p) {
            Append-Log "-> 检测到正在运行的进程: $proc，正在安全结束占用..."
            Stop-Process -Name $proc -Force -ErrorAction SilentlyContinue
            Start-Sleep -Milliseconds 500
        }
    }
}

# --- 执行安装操作 ---
function Execute-Install($langCode, $langTitle, $sourceDir) {
    $targets = Get-SelectedTargets
    if ($targets.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("请至少勾选一个目标游戏客户端！", "未选择客户端", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }

    $srcDat = Join-Path $sourceDir "L10NString.dat"
    $srcPak = Join-Path $sourceDir "pakchunk502000-Windows_0_P.pak"
    if (-not (Test-Path $srcDat)) {
        Append-Log "【错误】未找到汉化数据文件: $srcDat"
        return
    }

    Release-FileLocks

    $cnt = 0
    foreach ($gameRoot in $targets) {
        $cnt++
        Append-Log ">>> 正在处理目标客户端 [$cnt/$($targets.Count)]: $gameRoot"
        
        $backupDir   = Join-Path $gameRoot "Aion2_English_Backup_Safe"
        $enUsL10nDir = Join-Path $gameRoot "Aion2\Content\L10N\Text\en-US"
        $enUsPaksDir = Join-Path $gameRoot "Aion2\Content\Paks\L10N\Text\en-US"

        # 1. 备份原版
        if (-not (Test-Path $backupDir)) {
            Append-Log "-> 正在创建官方原版英文备份..."
            New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
            $curPak = Join-Path $enUsPaksDir "pakchunk502000-Windows_0_P.pak"
            if ((Test-Path $curPak) -and ((Get-Item $curPak).Length -gt 1000)) {
                Copy-Item "$enUsPaksDir\*" $backupDir -Force
                Append-Log "-> 官方原版已安全备份至: $backupDir"
            }
        }

        # 2. 释放 L10NString.dat
        Append-Log "-> 正在部署 $langTitle 数据表..."
        New-Item -ItemType Directory -Path $enUsL10nDir -Force | Out-Null
        Copy-Item $srcDat (Join-Path $enUsL10nDir "L10NString.dat") -Force

        # 3. 释放 Stub 回退文件
        Append-Log "-> 正在注入虚幻5引擎本地化回退机制..."
        $sigFiles = @(
            (Join-Path $enUsPaksDir "pakchunk502000-Windows_0_P.sig"),
            (Join-Path $enUsPaksDir "pakchunk502000-Windows_0_P.ucas"),
            (Join-Path $enUsPaksDir "pakchunk502000-Windows_0_P.utoc")
        )
        foreach ($sf in $sigFiles) {
            if (Test-Path $sf) {
                Clear-Content -Path $sf -Force -ErrorAction SilentlyContinue
                Remove-Item $sf -Force -ErrorAction SilentlyContinue
                if (Test-Path $sf) {
                    [System.IO.File]::WriteAllBytes($sf, @()) 2>$null
                }
            }
        }
        Copy-Item $srcPak (Join-Path $enUsPaksDir "pakchunk502000-Windows_0_P.pak") -Force
        Append-Log "-> 该客户端 $langTitle 汉化部署完成！"
    }

    Append-Log "=========================================================="
    Append-Log "恭喜！已全部成功应用 $langTitle (共处理 $cnt 个客户端)！"
    Append-Log "【核心提示】游戏内语言请保持默认的英文（English），进游戏即直接显示中文！"
    Append-Log "=========================================================="

    [System.Windows.Forms.MessageBox]::Show("AION 2 $($langTitle)补丁安装成功 (共处理 $cnt 个客户端)！`n`n【提示】：游戏内语言保持默认英文（English）即可直接享受中文！`n`n制作：B站@吃素的佩奇", "汉化成功", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
}

# --- 执行还原操作 ---
function Execute-Restore {
    $targets = Get-SelectedTargets
    if ($targets.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("请至少勾选一个目标游戏客户端！", "未选择客户端", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }

    Release-FileLocks

    $cnt = 0
    foreach ($gameRoot in $targets) {
        $cnt++
        Append-Log ">>> 正在还原目标客户端 [$cnt/$($targets.Count)]: $gameRoot"
        
        $backupDir   = Join-Path $gameRoot "Aion2_English_Backup_Safe"
        $enUsPaksDir = Join-Path $gameRoot "Aion2\Content\Paks\L10N\Text\en-US"
        $l10nRoot    = Join-Path $gameRoot "Aion2\Content\L10N"

        Append-Log "-> 正在清理汉化数据缓存..."
        if (Test-Path $l10nRoot) {
            Remove-Item $l10nRoot -Recurse -Force -ErrorAction SilentlyContinue
        }

        Append-Log "-> 正在还原官方英文包..."
        if (Test-Path $backupDir) {
            Copy-Item "$backupDir\*" $enUsPaksDir -Force
            Append-Log "-> 已完整恢复官方原版英文状态！"
        } else {
            Append-Log "-> 未检测到本地备份，已清除汉化缓存，建议在启动器中检验游戏完整性。"
        }
    }

    Append-Log "=========================================================="
    Append-Log "全部还原操作已完成 (共恢复 $cnt 个客户端)！"
    Append-Log "=========================================================="

    [System.Windows.Forms.MessageBox]::Show("已成功还原为官方原版英文客户端 (共恢复 $cnt 个客户端)！`n`n制作：B站@吃素的佩奇", "还原成功", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
}

# --- 按钮绑定事件 ---
$btnInstallZh.Add_Click({ Execute-Install "zh" "简体中文" $ZhDir })
$btnInstallTw.Add_Click({ Execute-Install "zh-TW" "繁体中文" $ZhTwDir })
$btnRestore.Add_Click({ Execute-Restore })

# --- 窗口加载初始化 ---
$mainForm.Add_Shown({
    Append-Log "欢迎使用 AION 2 国际服简繁双语一键汉化大师 v$CurrentVersion！"
    Append-Log "本工具完全开源免费交流，由 B站@吃素的佩奇 制作维护。"
    Run-Scan
})

# 启动窗口
[System.Windows.Forms.Application]::Run($mainForm)