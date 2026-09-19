# -*- coding: utf-8 -*-
# AION 2 Steam 测试版一键汉化与还原工具
# 作者: B站@吃素的佩奇 
# 开源主页: https://github.com/duoluoyuji/Aion2-Steam-CN

param(
    [switch]$Install,
    [switch]$Restore
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$ToolDir        = $PSScriptRoot
$ZhDir          = Join-Path $ToolDir 'zh'
$CurrentVersion = '1.0.0'
$AppId          = '4972320'
$RemoteVersionUrl   = 'https://raw.githubusercontent.com/duoluoyuji/Aion2-Steam-CN/main/version.json'
$FallbackVersionUrl = 'https://ghp.ci/https://raw.githubusercontent.com/duoluoyuji/Aion2-Steam-CN/main/version.json'

# ==================== 控制台作者署名横幅 ====================
function Show-Banner {
    Write-Host "========================================================================" -ForegroundColor Magenta
    Write-Host "      AION 2 (Steam 国际服测试版) 简体中文汉化工具 v$CurrentVersion" -ForegroundColor Cyan
    Write-Host "      作者/维护: 哔哩哔哩 @吃素的佩奇 " -ForegroundColor Yellow
    Write-Host "      开源主页: https://github.com/duoluoyuji/Aion2-Steam-CN" -ForegroundColor Gray
    Write-Host "      【声明】本工具完全免费分享，仅供交流学习，严禁倒卖牟利！" -ForegroundColor Red
    Write-Host "========================================================================" -ForegroundColor Magenta
    Write-Host ""
}

# ==================== 在线版本检测与自动更新提醒 ====================
function Check-Update {
    Write-Host "[0/4] 正在检查最新版本更新与公告..." -ForegroundColor DarkGray
    $remoteJson = $null
    $urls = @($RemoteVersionUrl, $FallbackVersionUrl)
    
    foreach ($u in $urls) {
        try {
            $req = [System.Net.HttpWebRequest]::Create($u)
            $req.Timeout = 3000
            $req.UserAgent = "Aion2CNTool"
            $resp = $req.GetResponse()
            $sr = New-Object System.IO.StreamReader($resp.GetResponseStream(), [System.Text.Encoding]::UTF8)
            $txt = $sr.ReadToEnd()
            $sr.Close()
            $resp.Close()
            if ($txt) {
                $remoteJson = ConvertFrom-Json $txt
                break
            }
        } catch {}
    }

    if ($remoteJson) {
        if ($remoteJson.version -and ($remoteJson.version -ne $CurrentVersion)) {
            Write-Host ">>> 发现新版本: v$($remoteJson.version)！" -ForegroundColor Yellow
            $tip = "发现 AION 2 汉化工具最新版本：v$($remoteJson.version)`n`n公告内容：`n$($remoteJson.announcement)`n`n是否立即打开下载页面？"
            $ask = [System.Windows.Forms.MessageBox]::Show($tip, "发现新版本 - B站@吃素的佩奇", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Information)
            if ($ask -eq [System.Windows.Forms.DialogResult]::Yes) {
                $url = if ($remoteJson.download_url) { $remoteJson.download_url } else { "https://github.com/duoluoyuji/Aion2-Steam-CN" }
                [System.Diagnostics.Process]::Start($url)
            }
        } else {
            Write-Host "-> 当前已是最新测试版本 (v$CurrentVersion)。" -ForegroundColor DarkGray
        }
    } else {
        Write-Host "-> 网络检测超时，使用离线模式继续运行。" -ForegroundColor DarkGray
    }
}

# ==================== 自动扫描全盘 Steam 游戏库 ====================
function Find-GameRoot {
    $roots = @()
    $fixedDrives = (Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Free -ne $null -and $_.Root }).Root
    
    foreach ($d in $fixedDrives) {
        $candidates = @(
            (Join-Path $d 'SteamLibrary\steamapps'),
            (Join-Path $d 'steamapps'),
            (Join-Path $d 'Program Files (x86)\Steam\steamapps'),
            (Join-Path $d 'Program Files\Steam\steamapps'),
            (Join-Path $d 'Steam\steamapps')
        )
        foreach ($c in $candidates) {
            if (Test-Path $c) { $roots += $c }
        }
    }
    
    try {
        $reg = Get-ItemProperty -Path "HKCU:\Software\Valve\Steam" -ErrorAction SilentlyContinue
        if ($reg -and $reg.SteamPath) {
            $regApps = Join-Path $reg.SteamPath 'steamapps'
            if (Test-Path $regApps) { $roots += $regApps }
        }
    } catch {}

    $roots = $roots | Select-Object -Unique

    # 优先匹配 appmanifest
    foreach ($r in $roots) {
        $acf = Join-Path $r "appmanifest_$AppId.acf"
        if (Test-Path $acf) {
            $txt = Get-Content $acf -Raw
            if ($txt -match '"installdir"\s+"([^"]+)"') {
                $gameAbs = Join-Path (Join-Path $r 'common') $matches[1]
                if (Test-Path (Join-Path $gameAbs 'Aion2\Content\Paks\L10N')) {
                    return $gameAbs
                }
            }
        }
    }

    # 特征识别 common 下目录
    foreach ($r in $roots) {
        $common = Join-Path $r 'common'
        if (Test-Path $common) {
            $hit = Get-ChildItem $common -Directory -ErrorAction SilentlyContinue | Where-Object {
                Test-Path (Join-Path $_.FullName 'Aion2\Content\Paks\L10N')
            } | Select-Object -First 1
            if ($hit) { return $hit.FullName }
        }
    }

    return $null
}

# 手动选择游戏目录保底
function Select-GameFolder {
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    $dlg.Description = "未自动检测到游戏安装位置。`n请手动选择 AION 2 Playtest 游戏根目录（包含 Aion2 文件夹的那一层）："
    $dlg.ShowNewFolderButton = $false
    if ($dlg.ShowDialog() -eq 'OK') {
        $sel = $dlg.SelectedPath
        if (Test-Path (Join-Path $sel 'Aion2\Content\Paks\L10N')) {
            return $sel
        } else {
            [System.Windows.Forms.MessageBox]::Show("所选目录不是有效的 AION 2 游戏根目录！`n该目录下必须包含 Aion2 文件夹。", "错误 - B站@吃素的佩奇", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
            return $null
        }
    }
    return $null
}

# ==================== 原版完整 4 条免责声明弹窗 ====================
function Show-Disclaimer {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "AION 2 汉化工具 [测试版] - 制作: B站@吃素的佩奇"
    $form.Size = New-Object System.Drawing.Size(580, 540)
    $form.StartPosition = 'CenterScreen'
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.BackColor = [System.Drawing.Color]::FromArgb(24,24,28)

    # 顶部横幅
    $banner = New-Object System.Windows.Forms.Panel
    $banner.Dock = 'Top'
    $banner.Height = 62
    $banner.BackColor = [System.Drawing.Color]::FromArgb(32,32,38)
    $form.Controls.Add($banner)

    $icon = New-Object System.Windows.Forms.Label
    $icon.Text = '!'
    $icon.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 18, [System.Drawing.FontStyle]::Bold)
    $icon.ForeColor = [System.Drawing.Color]::FromArgb(255,165,0)
    $icon.Location = New-Object System.Drawing.Point(16,10)
    $icon.Size = New-Object System.Drawing.Size(36,40)
    $icon.TextAlign = 'MiddleCenter'
    $banner.Controls.Add($icon)

    $title = New-Object System.Windows.Forms.Label
    $title.Text = '重要操作风险说明'
    $title.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 16, [System.Drawing.FontStyle]::Bold)
    $title.ForeColor = [System.Drawing.Color]::FromArgb(255,165,0)
    $title.Location = New-Object System.Drawing.Point(58,15)
    $title.AutoSize = $true
    $banner.Controls.Add($title)

    # 中部说明文字区（100% 还原原版 4 条，字字不差）
    $body = New-Object System.Windows.Forms.Panel
    $body.Dock = 'Fill'
    $body.BackColor = [System.Drawing.Color]::FromArgb(28,28,34)
    $body.Padding = New-Object System.Windows.Forms.Padding(20,12,20,0)
    $form.Controls.Add($body)
    $form.Controls.SetChildIndex($body, 0)

    $items = @(
        '1. 本工具会向游戏目录释放汉化数据文件，并可能修改本地配置文件。',
        '2. 任何客户端修改都可能违反游戏服务条款，相关风险由使用者自行承担。',
        '3. 执行过程中请勿启动游戏或中断任务，避免客户端文件损坏。',
        '4. 本工具操作前会先自动备份原文件，可用「卸载/还原」功能还原。'
    )
    $y = 12
    foreach ($it in $items) {
        $l = New-Object System.Windows.Forms.Label
        $l.Text = $it
        $l.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 10)
        $l.ForeColor = [System.Drawing.Color]::FromArgb(220,220,225)
        $l.AutoSize = $false
        $l.Location = New-Object System.Drawing.Point(16,$y)
        $l.Size = New-Object System.Drawing.Size(515,50)
        $l.TextAlign = 'TopLeft'
        $body.Controls.Add($l)
        $y += 56
    }

    # 强化作者署名与防倒卖栏
    $authorBanner = New-Object System.Windows.Forms.Label
    $authorBanner.Text = "★ 本补丁为测试版专属 | 免费分享严禁倒卖 | 制作: B站@吃素的佩奇 "
    $authorBanner.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 9, [System.Drawing.FontStyle]::Bold)
    $authorBanner.ForeColor = [System.Drawing.Color]::FromArgb(160,130,240)
    $newY = $y + 4
    $authorBanner.Location = New-Object System.Drawing.Point(16, $newY)
    $authorBanner.Size = New-Object System.Drawing.Size(515,22)
    $authorBanner.TextAlign = 'MiddleLeft'
    $body.Controls.Add($authorBanner)

    # 底部勾选确认栏（增强风险提示文案）
    $checkRow = New-Object System.Windows.Forms.Panel
    $checkRow.Dock = 'Bottom'
    $checkRow.Height = 56
    $checkRow.BackColor = [System.Drawing.Color]::FromArgb(20,20,26)
    $form.Controls.Add($checkRow)

    $chk = New-Object System.Windows.Forms.CheckBox
    $chk.Text = '我已充分了解修改客户端的潜在风险，并确认当前游戏已经完全关闭。'
    $chk.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 9.5)
    $chk.ForeColor = [System.Drawing.Color]::FromArgb(200,200,205)
    $chk.Location = New-Object System.Drawing.Point(18,16)
    $chk.AutoSize = $true
    $checkRow.Controls.Add($chk)

    # 按钮栏
    $btnRow = New-Object System.Windows.Forms.Panel
    $btnRow.Dock = 'Bottom'
    $btnRow.Height = 64
    $btnRow.BackColor = [System.Drawing.Color]::FromArgb(32,32,38)
    $form.Controls.Add($btnRow)

    $btnCancel = New-Object System.Windows.Forms.Button
    $btnCancel.Text = '暂不使用'
    $btnCancel.BackColor = [System.Drawing.Color]::FromArgb(60,60,68)
    $btnCancel.ForeColor = [System.Drawing.Color]::White
    $btnCancel.FlatStyle = 'Flat'
    $btnCancel.Location = New-Object System.Drawing.Point(20,15)
    $btnCancel.Size = New-Object System.Drawing.Size(120,34)
    $btnRow.Controls.Add($btnCancel)

    $btnBili = New-Object System.Windows.Forms.Button
    $btnBili.Text = '作者B站主页'
    $btnBili.BackColor = [System.Drawing.Color]::FromArgb(45,85,125)
    $btnBili.ForeColor = [System.Drawing.Color]::White
    $btnBili.FlatStyle = 'Flat'
    $btnBili.Location = New-Object System.Drawing.Point(150,15)
    $btnBili.Size = New-Object System.Drawing.Size(110,34)
    $btnBili.Add_Click({ [System.Diagnostics.Process]::Start("https://space.bilibili.com/3379443") })
    $btnRow.Controls.Add($btnBili)

    $btnGo = New-Object System.Windows.Forms.Button
    $btnGo.Text = '已了解，继续'
    $btnGo.BackColor = [System.Drawing.Color]::FromArgb(90,70,200)
    $btnGo.ForeColor = [System.Drawing.Color]::White
    $btnGo.FlatStyle = 'Flat'
    $btnGo.Location = New-Object System.Drawing.Point(410,15)
    $btnGo.Size = New-Object System.Drawing.Size(130,34)
    $btnGo.Enabled = $false
    $btnRow.Controls.Add($btnGo)

    $btnGo.Add_Click({ $form.DialogResult = 'OK'; $form.Close() })
    $btnCancel.Add_Click({ $form.DialogResult = 'Cancel'; $form.Close() })
    $chk.Add_CheckedChanged({ $btnGo.Enabled = $chk.Checked })

    $form.AcceptButton = $btnGo
    $form.CancelButton = $btnCancel
    return $form.ShowDialog()
}

# ==================== 主流程 ====================
Show-Banner

if ($Install) {
    # 1. 弹出免责声明与作者署名
    $res = Show-Disclaimer
    if ($res -ne 'OK') {
        Write-Host "用户已取消操作。" -ForegroundColor Yellow
        exit 0
    }

    # 2. 联网检查更新
    Check-Update

    Write-Host "[1/4] 正在全盘扫描检测 AION 2 Playtest 游戏目录..." -ForegroundColor Cyan
    $gameRoot = Find-GameRoot
    if (-not $gameRoot) {
        Write-Host "未能自动定位到游戏安装路径，请在弹出的窗口中手动指定..." -ForegroundColor Yellow
        $gameRoot = Select-GameFolder
        if (-not $gameRoot) {
            Write-Host "未选择有效游戏目录，操作已终止。" -ForegroundColor Red
            exit 1
        }
    }
    Write-Host "-> 成功定位游戏根目录: $gameRoot" -ForegroundColor Green

    $backupDir   = Join-Path $gameRoot "Aion2_English_Backup_Safe"
    $enUsL10nDir = Join-Path $gameRoot "Aion2\Content\L10N\Text\en-US"
    $enUsPaksDir = Join-Path $gameRoot "Aion2\Content\Paks\L10N\Text\en-US"

    Write-Host "[2/4] 正在建立原版纯英文语言备份..." -ForegroundColor Cyan
    if (-not (Test-Path $backupDir)) {
        New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
        $curPak = Join-Path $enUsPaksDir "pakchunk502000-Windows_0_P.pak"
        if ((Test-Path $curPak) -and ((Get-Item $curPak).Length -gt 1000)) {
            Copy-Item "$enUsPaksDir\*" $backupDir -Force
            Write-Host "-> 官方原版英文文件已安全备份至: $backupDir" -ForegroundColor Green
        }
    } else {
        Write-Host "-> 本地已存在安全备份，跳过覆盖。" -ForegroundColor Gray
    }

    Write-Host "[3/4] 正在释放中文数据表 (L10NString.dat)..." -ForegroundColor Cyan
    New-Item -ItemType Directory -Path $enUsL10nDir -Force | Out-Null
    Copy-Item (Join-Path $ZhDir "L10NString.dat") (Join-Path $enUsL10nDir "L10NString.dat") -Force

    Write-Host "[4/4] 正在注入虚幻5回退机制 Stub..." -ForegroundColor Cyan
    Remove-Item "$enUsPaksDir\pakchunk502000-Windows_0_P.sig" -Force -ErrorAction SilentlyContinue
    Remove-Item "$enUsPaksDir\pakchunk502000-Windows_0_P.ucas" -Force -ErrorAction SilentlyContinue
    Remove-Item "$enUsPaksDir\pakchunk502000-Windows_0_P.utoc" -Force -ErrorAction SilentlyContinue
    Copy-Item (Join-Path $ZhDir "pakchunk502000-Windows_0_P.pak") (Join-Path $enUsPaksDir "pakchunk502000-Windows_0_P.pak") -Force

    Write-Host ""
    Write-Host "========================================================================" -ForegroundColor Green
    Write-Host ">>> 恭喜！AION 2 测试版汉化安装成功！" -ForegroundColor Green
    Write-Host ">>> 【核心提示】游戏内语言请保持默认的英文（English），进游戏即可直接显示中文！" -ForegroundColor Yellow
    Write-Host ">>> 制作与维护：B站@吃素的佩奇  | 欢迎关注获取9.30公测最新汉化！" -ForegroundColor Magenta
    Write-Host "========================================================================" -ForegroundColor Green
    [System.Windows.Forms.MessageBox]::Show("AION 2 [测试版] 汉化补丁安装成功！`n`n【提示】：游戏内语言保持默认英文（English）即可直接享受中文！`n`n制作：B站@吃素的佩奇 `n欢迎关注获取9月30日公测最新汉化！", "汉化成功 - B站@吃素的佩奇", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
}
elseif ($Restore) {
    Write-Host "[1/3] 正在定位 AION 2 Playtest 游戏目录..." -ForegroundColor Cyan
    $gameRoot = Find-GameRoot
    if (-not $gameRoot) {
        $gameRoot = Select-GameFolder
        if (-not $gameRoot) { exit 1 }
    }
    Write-Host "-> 已定位游戏目录: $gameRoot" -ForegroundColor Green

    $backupDir   = Join-Path $gameRoot "Aion2_English_Backup_Safe"
    $enUsL10nDir = Join-Path $gameRoot "Aion2\Content\L10N\Text\en-US"
    $enUsPaksDir = Join-Path $gameRoot "Aion2\Content\Paks\L10N\Text\en-US"

    Write-Host "[2/3] 清理汉化数据表..." -ForegroundColor Cyan
    $l10nRoot = Join-Path $gameRoot "Aion2\Content\L10N"
    if (Test-Path $l10nRoot) {
        Remove-Item $l10nRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    Write-Host "[3/3] 还原官方原版英文语言包..." -ForegroundColor Cyan
    if (Test-Path $backupDir) {
        Copy-Item "$backupDir\*" $enUsPaksDir -Force
        Write-Host ">>> 还原成功！已完整恢复官方原版英文状态。" -ForegroundColor Green
        [System.Windows.Forms.MessageBox]::Show("已成功还原为官方原版英文客户端！`n`n制作：B站@吃素的佩奇", "还原成功", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    } else {
        Write-Host ">>> 未检测到本地备份，已为您清理汉化数据，建议在 Steam 检验文件完整性。" -ForegroundColor Yellow
        [System.Windows.Forms.MessageBox]::Show("已清理汉化数据。`n如需完全补全原版英文文件，可在 Steam 库中右键游戏 -> 属性 -> 验证游戏文件的完整性。", "提示 - B站@吃素的佩奇", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
    }
}