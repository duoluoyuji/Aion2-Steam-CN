# -*- coding: utf-8 -*-
# AION 2 (Steam / PURPLE 正式版) 简体中文一键汉化与还原工具
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

$ToolDir        = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$ZhDir          = Join-Path $ToolDir 'zh'
$CurrentVersion = '1.1.1'
# 3393110 为 Steam 正式服 AppID，4972320 为 Steam Playtest 测试服 AppID
$AppIds         = @('3393110', '4972320')
$RemoteVersionUrl   = 'https://raw.githubusercontent.com/duoluoyuji/Aion2-Steam-CN/main/version.json'
$FallbackVersionUrl = 'https://ghp.ci/https://raw.githubusercontent.com/duoluoyuji/Aion2-Steam-CN/main/version.json'

# ==================== 安装前置检查与文件校验 ====================
function Assert-PatchPayload {
    $required = @(
        @{ Path = (Join-Path $ZhDir 'L10NString.dat'); MinSize = 1 },
        @{ Path = (Join-Path $ZhDir 'pakchunk502000-Windows_0_P.pak'); MinSize = 1 }
    )

    foreach ($item in $required) {
        if (-not (Test-Path -LiteralPath $item.Path -PathType Leaf)) {
            throw "汉化资源缺失：$($item.Path)"
        }

        $length = (Get-Item -LiteralPath $item.Path).Length
        if ($length -lt $item.MinSize) {
            throw "汉化资源为空或损坏：$($item.Path)"
        }
    }
}

function Assert-GameNotRunning {
    $running = @(Get-Process -Name 'Aion2' -ErrorAction SilentlyContinue)
    if ($running.Count -gt 0) {
        throw '检测到 AION 2 正在运行。请完全退出游戏后再重试，避免修改中的文件被锁定。'
    }
}

function Assert-BackupIsValid {
    param([Parameter(Mandatory)][string]$BackupDir)

    $backupPak = Join-Path $BackupDir 'pakchunk502000-Windows_0_P.pak'
    if (-not (Test-Path -LiteralPath $backupPak -PathType Leaf)) {
        throw "已有备份目录但缺少原版语言包：$BackupDir。为避免覆盖唯一备份，请先检查该目录。"
    }

    if ((Get-Item -LiteralPath $backupPak).Length -le 1000) {
        throw "已有备份目录中的原版语言包异常：$backupPak。为避免覆盖唯一备份，请先检查该目录。"
    }
}

function Copy-FileVerified {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Destination
    )

    Copy-Item -LiteralPath $Source -Destination $Destination -Force
    $sourceHash = (Get-FileHash -LiteralPath $Source -Algorithm SHA256).Hash
    $destinationHash = (Get-FileHash -LiteralPath $Destination -Algorithm SHA256).Hash
    if ($sourceHash -ne $destinationHash) {
        throw "文件校验失败：$Destination"
    }
}

function New-VerifiedBackup {
    param(
        [Parameter(Mandatory)][string]$SourceDir,
        [Parameter(Mandatory)][string]$BackupDir
    )

    $temporaryBackupDir = "$BackupDir.creating-$([Guid]::NewGuid().ToString('N'))"
    try {
        New-Item -ItemType Directory -Path $temporaryBackupDir -Force | Out-Null
        Copy-Item -Path (Join-Path $SourceDir '*') -Destination $temporaryBackupDir -Force
        Assert-BackupIsValid -BackupDir $temporaryBackupDir
        Move-Item -LiteralPath $temporaryBackupDir -Destination $BackupDir
    }
    catch {
        Remove-Item -LiteralPath $temporaryBackupDir -Recurse -Force -ErrorAction SilentlyContinue
        throw
    }
}

function Invoke-PatchFileChanges {
    param(
        [Parameter(Mandatory)][string]$PatchDir,
        [Parameter(Mandatory)][string]$EnUsL10nDir,
        [Parameter(Mandatory)][string]$EnUsPaksDir
    )

    New-Item -ItemType Directory -Path $EnUsL10nDir -Force | Out-Null
    Copy-FileVerified `
        -Source (Join-Path $PatchDir 'L10NString.dat') `
        -Destination (Join-Path $EnUsL10nDir 'L10NString.dat')

    foreach ($sidecar in @('sig', 'ucas', 'utoc')) {
        Remove-Item -LiteralPath (Join-Path $EnUsPaksDir "pakchunk502000-Windows_0_P.$sidecar") -Force -ErrorAction SilentlyContinue
    }
    Copy-FileVerified `
        -Source (Join-Path $PatchDir 'pakchunk502000-Windows_0_P.pak') `
        -Destination (Join-Path $EnUsPaksDir 'pakchunk502000-Windows_0_P.pak')
}

function Install-PatchForGameRoot {
    param(
        [Parameter(Mandatory)][string]$GameRoot,
        [string]$PatchDir = $script:ZhDir
    )

    $backupDir   = Join-Path $GameRoot 'Aion2_English_Backup_Safe'
    $enUsL10nDir = Join-Path $GameRoot 'Aion2\Content\L10N\Text\en-US'
    $enUsPaksDir = Join-Path $GameRoot 'Aion2\Content\Paks\L10N\Text\en-US'
    $curPak      = Join-Path $enUsPaksDir 'pakchunk502000-Windows_0_P.pak'

    Write-Host "[2/4] 正在建立官方原版英文语言备份..." -ForegroundColor Cyan
    if (Test-Path -LiteralPath $backupDir -PathType Container) {
        Assert-BackupIsValid -BackupDir $backupDir
        Write-Host "-> 本地已存在安全备份，跳过覆盖。" -ForegroundColor Gray
    }
    else {
        if (-not (Test-Path -LiteralPath $curPak -PathType Leaf)) {
            throw "未找到官方英文语言包：$curPak"
        }
        if ((Get-Item -LiteralPath $curPak).Length -le 1000) {
            throw "首次安装需要完整的官方英文语言包：$curPak。请先在启动器中验证游戏文件完整性。"
        }

        New-VerifiedBackup -SourceDir $enUsPaksDir -BackupDir $backupDir
        Write-Host "-> 官方原版英文文件已安全备份至: $backupDir" -ForegroundColor Green
    }

    $targetFiles = @(
        (Join-Path $enUsL10nDir 'L10NString.dat'),
        $curPak,
        (Join-Path $enUsPaksDir 'pakchunk502000-Windows_0_P.sig'),
        (Join-Path $enUsPaksDir 'pakchunk502000-Windows_0_P.ucas'),
        (Join-Path $enUsPaksDir 'pakchunk502000-Windows_0_P.utoc')
    )
    $rollbackDir = Join-Path $GameRoot ('.Aion2CNTool-rollback-' + [Guid]::NewGuid().ToString('N'))
    $snapshot = @()
    $l10nDirExisted = Test-Path -LiteralPath $enUsL10nDir -PathType Container

    try {
        New-Item -ItemType Directory -Path $rollbackDir -Force | Out-Null
        for ($index = 0; $index -lt $targetFiles.Count; $index++) {
            $target = $targetFiles[$index]
            $existed = Test-Path -LiteralPath $target -PathType Leaf
            $snapshotPath = Join-Path $rollbackDir "$index.bin"
            if ($existed) {
                Copy-FileVerified -Source $target -Destination $snapshotPath
            }
            $snapshot += [PSCustomObject]@{
                Path         = $target
                Existed      = $existed
                SnapshotPath = $snapshotPath
            }
        }

        Write-Host "[3/4] 正在释放中文数据表 (L10NString.dat)..." -ForegroundColor Cyan
        Write-Host "[4/4] 正在注入虚幻5回退机制 Stub..." -ForegroundColor Cyan
        Invoke-PatchFileChanges -PatchDir $PatchDir -EnUsL10nDir $enUsL10nDir -EnUsPaksDir $enUsPaksDir
    }
    catch {
        $installError = $_.Exception.Message
        $rollbackErrors = @()

        foreach ($item in $snapshot) {
            try {
                if ($item.Existed) {
                    $parentDir = Split-Path -Parent $item.Path
                    New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
                    Copy-FileVerified -Source $item.SnapshotPath -Destination $item.Path
                }
                else {
                    Remove-Item -LiteralPath $item.Path -Force -ErrorAction SilentlyContinue
                }
            }
            catch {
                $rollbackErrors += "$($item.Path): $($_.Exception.Message)"
            }
        }

        if (-not $l10nDirExisted -and (Test-Path -LiteralPath $enUsL10nDir -PathType Container)) {
            $remainingFiles = @(Get-ChildItem -LiteralPath $enUsL10nDir -Force -ErrorAction SilentlyContinue)
            if ($remainingFiles.Count -eq 0) {
                Remove-Item -LiteralPath $enUsL10nDir -Force -ErrorAction SilentlyContinue
            }
        }

        if ($rollbackErrors.Count -gt 0) {
            throw "汉化安装失败，且自动回滚不完整：$installError`n$($rollbackErrors -join "`n")"
        }
        throw "汉化安装失败，已自动恢复修改前文件：$installError"
    }
    finally {
        Remove-Item -LiteralPath $rollbackDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    Write-Host "-> 该目录汉化部署完成！" -ForegroundColor Green
}

# ==================== 控制台作者署名横幅 ====================
function Show-Banner {
    Write-Host "========================================================================" -ForegroundColor Magenta
    Write-Host "      AION 2 (Steam / PURPLE 正式版) 简体中文汉化工具 v$CurrentVersion" -ForegroundColor Cyan
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
        if ($remoteJson.version -and ($remoteJson.version -ne $CurrentVersion) -and ($remoteJson.version -ne '1.0.1')) {
            Write-Host ">>> 发现新版本: v$($remoteJson.version)！" -ForegroundColor Yellow
            $tip = "发现 AION 2 汉化工具最新版本：v$($remoteJson.version)`n`n公告内容：`n$($remoteJson.announcement)`n`n是否立即打开下载页面？"
            $box = [System.Windows.Forms.MessageBox]::Show($tip, "版本更新提示 - B站@吃素的佩奇", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
            if ($box -eq [System.Windows.Forms.DialogResult]::Yes) {
                [System.Diagnostics.Process]::Start("https://github.com/duoluoyuji/Aion2-Steam-CN/releases")
            }
        } else {
            Write-Host "-> 当前已是最新正式版本 (v$CurrentVersion)。" -ForegroundColor DarkGray
        }
    } else {
        Write-Host "-> 网络检测超时，使用离线模式继续运行。" -ForegroundColor DarkGray
    }
}

# ==================== 扫描全盘所有已安装的 AION 2 版本 ====================
function Get-AllGameRoots {
    $detected = @()
    $fixedDrives = (Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Free -ne $null -and $_.Root }).Root
    
    # 1. 扫描 Steam 游戏库
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

    # 优先精确匹配 Steam appmanifest (兼顾 3393110 正式服 与 4972320 测试服)
    foreach ($r in $steamRoots) {
        foreach ($aid in $AppIds) {
            $acf = Join-Path $r "appmanifest_$aid.acf"
            if (Test-Path $acf) {
                $txt = Get-Content $acf -Raw
                if ($txt -match '"installdir"\s+"([^"]+)"') {
                    $gameAbs = Join-Path (Join-Path $r 'common') $matches[1]
                    if (Test-Path (Join-Path $gameAbs 'Aion2\Content\Paks\L10N')) {
                        $label = if ($aid -eq '3393110') { "Steam 国际正式版" } else { "Steam 测试服版" }
                        if (-not ($detected | Where-Object { $_.Path.ToLower() -eq $gameAbs.ToLower() })) {
                            $detected += [PSCustomObject]@{
                                Platform = $label
                                Path     = $gameAbs
                                Type     = "Steam"
                            }
                        }
                    }
                }
            }
        }

        # 扫描 common 目录下未挂载 acf 或自定义命名的 Aion2
        $common = Join-Path $r 'common'
        if (Test-Path $common) {
            $hits = Get-ChildItem $common -Directory -ErrorAction SilentlyContinue | Where-Object {
                Test-Path (Join-Path $_.FullName 'Aion2\Content\Paks\L10N')
            }
            foreach ($h in $hits) {
                if (-not ($detected | Where-Object { $_.Path.ToLower() -eq $h.FullName.ToLower() })) {
                    $detected += [PSCustomObject]@{
                        Platform = "Steam 游戏库 ($($h.Name))"
                        Path     = $h.FullName
                        Type     = "Steam"
                    }
                }
            }
        }
    }

    # 2. 搜寻 PURPLE 国际服 / 全球版独立安装路径
    foreach ($d in $fixedDrives) {
        $purpleCandidates = @(
            (Join-Path $d 'AION 2'),
            (Join-Path $d 'Games\AION 2'),
            (Join-Path $d 'NC\AION 2'),
            (Join-Path $d 'Program Files (x86)\NC\AION 2'),
            (Join-Path $d 'Program Files\NC\AION 2'),
            (Join-Path $d 'NCSOFT\AION 2')
        )
        foreach ($pc in $purpleCandidates) {
            if (Test-Path (Join-Path $pc 'Aion2\Content\Paks\L10N')) {
                if (-not ($detected | Where-Object { $_.Path.ToLower() -eq $pc.ToLower() })) {
                    $detected += [PSCustomObject]@{
                        Platform = "NCSoft PURPLE 国际服"
                        Path     = $pc
                        Type     = "PURPLE"
                    }
                }
            }
        }
    }

    return $detected
}

# 手动选择游戏目录保底
function Select-GameFolder {
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    $dlg.Description = "未自动检测到游戏安装位置。`n请手动选择 AION 2 游戏根目录（包含 Aion2 文件夹的那一层，名字通常为 AION 2 或 AION 2 Playtest）："
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

# ==================== 智能版本决策与多版本选择窗口 ====================
function Select-TargetGameRoots {
    param([string]$ActionName = "汉化")

    $all = @(Get-AllGameRoots)

    # 场景 0: 全盘未搜到任何版本 -> 弹窗手动选择
    if ($all.Count -eq 0) {
        Write-Host "未能自动定位到游戏安装路径，请在弹出的窗口中手动指定..." -ForegroundColor Yellow
        $manual = Select-GameFolder
        if ($manual) {
            return @($manual)
        }
        return @()
    }

    # 场景 1: 只检测到 1 个版本 -> 直接自动采用，无需用户费神多点一次
    if ($all.Count -eq 1) {
        Write-Host "-> 检测到唯一安装版本: $($all[0].Platform) [$($all[0].Path)]" -ForegroundColor Green
        return @($all[0].Path)
    }

    # 场景 2: 检测到 2 个或以上不同版本 (例如同时存在 Steam 与 PURPLE) -> 弹出交互窗口让用户勾选
    Write-Host ">>> 检测到电脑中安装了多个不同版本的 AION 2 ($($all.Count) 个)，正在弹出选择窗口..." -ForegroundColor Cyan

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "AION 2 游戏版本选择 - B站@吃素的佩奇"
    $formHeight = 310 + ($all.Count * 45)
    $form.Size = New-Object System.Drawing.Size(650, $formHeight)
    $form.StartPosition = 'CenterScreen'
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.BackColor = [System.Drawing.Color]::FromArgb(24, 24, 28)
    $form.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 9.5)

    # 顶部横幅
    $banner = New-Object System.Windows.Forms.Panel
    $banner.Dock = 'Top'
    $banner.Height = 70
    $banner.BackColor = [System.Drawing.Color]::FromArgb(35, 35, 45)
    $form.Controls.Add($banner)

    $title = New-Object System.Windows.Forms.Label
    $title.Text = "检测到多个游戏版本，请选择要【$ActionName】的目标："
    $title.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 12, [System.Drawing.FontStyle]::Bold)
    $title.ForeColor = [System.Drawing.Color]::FromArgb(100, 200, 255)
    $title.Location = New-Object System.Drawing.Point(20, 14)
    $title.AutoSize = $true
    $banner.Controls.Add($title)

    $subtitle = New-Object System.Windows.Forms.Label
    $subtitle.Text = "您可以在下方选择其中一个版本，或选择「同时处理全部版本」"
    $subtitle.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 9)
    $subtitle.ForeColor = [System.Drawing.Color]::FromArgb(180, 180, 190)
    $subtitle.Location = New-Object System.Drawing.Point(22, 42)
    $subtitle.AutoSize = $true
    $banner.Controls.Add($subtitle)

    # 中部列表单选区
    $body = New-Object System.Windows.Forms.Panel
    $body.Dock = 'Fill'
    $body.Padding = New-Object System.Windows.Forms.Padding(25, 15, 25, 10)
    $form.Controls.Add($body)
    $form.Controls.SetChildIndex($body, 0)

    $radioList = @()
    $y = 15

    for ($i = 0; $i -lt $all.Count; $i++) {
        $rb = New-Object System.Windows.Forms.RadioButton
        $rb.Text = "$($all[$i].Platform)  |  $($all[$i].Path)"
        $rb.Location = New-Object System.Drawing.Point(25, $y)
        $rb.Size = New-Object System.Drawing.Size(580, 36)
        $rb.ForeColor = [System.Drawing.Color]::FromArgb(235, 235, 240)
        $rb.Tag = @($all[$i].Path)
        if ($i -eq 0) { $rb.Checked = $true } # 默认高亮排在第一顺位的版本
        $body.Controls.Add($rb)
        $radioList += $rb
        $y += 42
    }

    # 选项：同时处理全部版本 (两端均生效)
    $rbAll = New-Object System.Windows.Forms.RadioButton
    $rbAll.Text = "★ 同时${ActionName}以上全部版本 (推荐，两端都享受中文)"
    $rbAll.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 10, [System.Drawing.FontStyle]::Bold)
    $rbAll.Location = New-Object System.Drawing.Point(25, $y)
    $rbAll.Size = New-Object System.Drawing.Size(580, 36)
    $rbAll.ForeColor = [System.Drawing.Color]::FromArgb(255, 215, 0)
    $allPaths = @($all | ForEach-Object { $_.Path })
    $rbAll.Tag = $allPaths
    $body.Controls.Add($rbAll)
    $radioList += $rbAll

    # 底部按钮栏
    $btnRow = New-Object System.Windows.Forms.Panel
    $btnRow.Dock = 'Bottom'
    $btnRow.Height = 60
    $btnRow.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 36)
    $form.Controls.Add($btnRow)

    $btnOk = New-Object System.Windows.Forms.Button
    $btnOk.Text = "确认执行"
    $btnOk.DialogResult = 'OK'
    $btnOk.BackColor = [System.Drawing.Color]::FromArgb(70, 130, 180)
    $btnOk.ForeColor = [System.Drawing.Color]::White
    $btnOk.FlatStyle = 'Flat'
    $btnOk.Location = New-Object System.Drawing.Point(390, 14)
    $btnOk.Size = New-Object System.Drawing.Size(110, 32)
    $btnRow.Controls.Add($btnOk)

    $btnCancel = New-Object System.Windows.Forms.Button
    $btnCancel.Text = "取消"
    $btnCancel.DialogResult = 'Cancel'
    $btnCancel.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 70)
    $btnCancel.ForeColor = [System.Drawing.Color]::White
    $btnCancel.FlatStyle = 'Flat'
    $btnCancel.Location = New-Object System.Drawing.Point(515, 14)
    $btnCancel.Size = New-Object System.Drawing.Size(95, 32)
    $btnRow.Controls.Add($btnCancel)

    $form.AcceptButton = $btnOk
    $form.CancelButton = $btnCancel

    $dialogRes = $form.ShowDialog()
    if ($dialogRes -eq 'OK') {
        foreach ($rb in $radioList) {
            if ($rb.Checked) {
                return $rb.Tag
            }
        }
    }

    Write-Host "用户已取消版本选择。" -ForegroundColor Yellow
    return @()
}

# ==================== 专属定制免责声明弹窗 ====================
function Show-Disclaimer {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "AION 2 正式版汉化工具 - 制作: B站@吃素的佩奇"
    $form.Size = New-Object System.Drawing.Size(580, 480)
    $form.StartPosition = 'CenterScreen'
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.BackColor = [System.Drawing.Color]::FromArgb(24,24,28)

    # 顶部横幅
    $banner = New-Object System.Windows.Forms.Panel
    $banner.Dock = 'Top'
    $banner.Height = 65
    $banner.BackColor = [System.Drawing.Color]::FromArgb(35,35,45)
    $form.Controls.Add($banner)

    $icon = New-Object System.Windows.Forms.Label
    $icon.Text = '!'
    $icon.Font = New-Object System.Drawing.Font('Arial', 24, [System.Drawing.FontStyle]::Bold)
    $icon.ForeColor = [System.Drawing.Color]::FromArgb(255,165,0)
    $icon.Location = New-Object System.Drawing.Point(16,12)
    $icon.Size = New-Object System.Drawing.Size(36,40)
    $icon.TextAlign = 'MiddleCenter'
    $banner.Controls.Add($icon)

    $title = New-Object System.Windows.Forms.Label
    $title.Text = '重要操作风险说明 (Steam / PURPLE 通用)'
    $title.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 15, [System.Drawing.FontStyle]::Bold)
    $title.ForeColor = [System.Drawing.Color]::FromArgb(255,165,0)
    $title.Location = New-Object System.Drawing.Point(58,16)
    $title.AutoSize = $true
    $banner.Controls.Add($title)

    # 中部说明文字区
    $body = New-Object System.Windows.Forms.Panel
    $body.Dock = 'Fill'
    $body.BackColor = [System.Drawing.Color]::FromArgb(28,28,34)
    $body.Padding = New-Object System.Windows.Forms.Padding(20,12,20,0)
    $form.Controls.Add($body)
    $form.Controls.SetChildIndex($body, 0)

    $items = @(
        '1. 本工具会向游戏目录释放汉化数据文件，并备份原版英文语言包。',
        '2. 任何客户端修改都可能违反游戏服务条款，相关风险由使用者自行承担。',
        '3. 执行过程中请勿启动游戏或中断任务，避免客户端文件损坏。',
        '4. 本工具操作前会先自动备份原文件，可用「一键还原英文」随时恢复。'
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

    # 声明栏
    $authorBanner = New-Object System.Windows.Forms.Label
    $authorBanner.Text = "★ 本补丁支持 Steam / PURPLE 正式版 | 免费分享严禁倒卖"
    $authorBanner.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 9, [System.Drawing.FontStyle]::Bold)
    $authorBanner.ForeColor = [System.Drawing.Color]::FromArgb(160,130,240)
    $newY = $y + 4
    $authorBanner.Location = New-Object System.Drawing.Point(16, $newY)
    $authorBanner.Size = New-Object System.Drawing.Size(515,22)
    $authorBanner.TextAlign = 'MiddleLeft'
    $body.Controls.Add($authorBanner)

    # 底部勾选确认栏
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
    $btnCancel.Text = '取消退出'
    $btnCancel.BackColor = [System.Drawing.Color]::FromArgb(55,55,62)
    $btnCancel.ForeColor = [System.Drawing.Color]::FromArgb(200,200,200)
    $btnCancel.FlatStyle = 'Flat'
    $btnCancel.Location = New-Object System.Drawing.Point(20,15)
    $btnCancel.Size = New-Object System.Drawing.Size(100,34)
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
    $res = Show-Disclaimer
    if ($res -ne 'OK') {
        Write-Host "用户已取消操作。" -ForegroundColor Yellow
        exit 0
    }

    Assert-PatchPayload
    Assert-GameNotRunning
    Check-Update

    Write-Host "[1/4] 正在全盘扫描检测 AION 2 游戏版本 (Steam / PURPLE)..." -ForegroundColor Cyan
    $selectedRoots = @(Select-TargetGameRoots -ActionName "安装汉化")
    if ($selectedRoots.Count -eq 0) {
        Write-Host "未选择有效游戏目录，操作已终止。" -ForegroundColor Red
        exit 1
    }

    $processedCount = 0
    foreach ($gameRoot in $selectedRoots) {
        $processedCount++
        Write-Host ""
        Write-Host "========================================================================" -ForegroundColor DarkCyan
        Write-Host ">>> 正在处理目标游戏目录 [$processedCount/$($selectedRoots.Count)]: $gameRoot" -ForegroundColor Green
        Write-Host "========================================================================" -ForegroundColor DarkCyan

        Install-PatchForGameRoot -GameRoot $gameRoot
    }

    Write-Host ""
    Write-Host "========================================================================" -ForegroundColor Green
    Write-Host ">>> 恭喜！AION 2 简体中文汉化全部安装成功 (共处理 $processedCount 个客户端)！" -ForegroundColor Green
    Write-Host ">>> 【核心提示】游戏内语言请保持默认的英文（English），进游戏即可直接显示中文！" -ForegroundColor Yellow
    Write-Host ">>> 制作与维护：B站@吃素的佩奇 | 欢迎关注获取公测最新汉化！" -ForegroundColor Magenta
    Write-Host "========================================================================" -ForegroundColor Green
    [System.Windows.Forms.MessageBox]::Show("AION 2 汉化补丁安装成功 (共处理 $processedCount 个客户端)！`n`n【提示】：游戏内语言保持默认英文（English）即可直接享受中文！`n`n制作：B站@吃素的佩奇`n欢迎关注获取最新汉化动态！", "汉化成功 - B站@吃素的佩奇", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
}
elseif ($Restore) {
    Assert-GameNotRunning
    Write-Host "[1/3] 正在全盘扫描检测 AION 2 游戏版本 (Steam / PURPLE)..." -ForegroundColor Cyan
    $selectedRoots = @(Select-TargetGameRoots -ActionName "还原英文")
    if ($selectedRoots.Count -eq 0) {
        Write-Host "未选择有效游戏目录，操作已终止。" -ForegroundColor Red
        exit 1
    }

    $processedCount = 0
    foreach ($gameRoot in $selectedRoots) {
        $processedCount++
        Write-Host ""
        Write-Host "========================================================================" -ForegroundColor DarkCyan
        Write-Host ">>> 正在还原目标游戏目录 [$processedCount/$($selectedRoots.Count)]: $gameRoot" -ForegroundColor Green
        Write-Host "========================================================================" -ForegroundColor DarkCyan

        $backupDir   = Join-Path $gameRoot "Aion2_English_Backup_Safe"
        $enUsPaksDir = Join-Path $gameRoot "Aion2\Content\Paks\L10N\Text\en-US"

        Write-Host "[2/3] 清理汉化数据表..." -ForegroundColor Cyan
        $l10nRoot = Join-Path $gameRoot "Aion2\Content\L10N"
        if (Test-Path $l10nRoot) {
            Remove-Item $l10nRoot -Recurse -Force -ErrorAction SilentlyContinue
        }

        Write-Host "[3/3] 还原官方原版英文语言包..." -ForegroundColor Cyan
        if (Test-Path $backupDir) {
            Assert-BackupIsValid -BackupDir $backupDir
            Copy-Item "$backupDir\*" $enUsPaksDir -Force
            Write-Host "-> 还原成功！已完整恢复官方原版英文状态。" -ForegroundColor Green
        } else {
            Write-Host "-> 未检测到本地备份，已为您清理汉化数据，建议检验文件完整性。" -ForegroundColor Yellow
        }
    }

    Write-Host ""
    Write-Host "========================================================================" -ForegroundColor Green
    Write-Host ">>> 全部还原操作已完成 (共恢复 $processedCount 个客户端)！" -ForegroundColor Green
    Write-Host "========================================================================" -ForegroundColor Green
    [System.Windows.Forms.MessageBox]::Show("已成功还原为官方原版英文客户端 (共恢复 $processedCount 个版本)！`n`n制作：B站@吃素的佩奇", "还原成功", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
}
