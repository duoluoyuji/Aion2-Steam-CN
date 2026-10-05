$scriptPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'Aion2CNTool.ps1'
. $scriptPath

function New-TestLayout {
    param([Parameter(Mandatory)][string]$Root)

    $patchDir = Join-Path $Root 'patch'
    $paksDir = Join-Path $Root 'game\Aion2\Content\Paks\L10N\Text\en-US'
    $l10nDir = Join-Path $Root 'game\Aion2\Content\L10N\Text\en-US'
    New-Item -ItemType Directory -Path $patchDir, $paksDir, $l10nDir -Force | Out-Null

    $officialPak = Join-Path $paksDir 'pakchunk502000-Windows_0_P.pak'
    [IO.File]::WriteAllBytes($officialPak, (New-Object byte[] 2048))
    [IO.File]::WriteAllBytes((Join-Path $patchDir 'pakchunk502000-Windows_0_P.pak'), [byte[]](1, 2, 3, 4))
    [IO.File]::WriteAllBytes((Join-Path $patchDir 'L10NString.dat'), [byte[]](5, 6, 7, 8))
    foreach ($extension in @('sig', 'ucas', 'utoc')) {
        [IO.File]::WriteAllBytes((Join-Path $paksDir "pakchunk502000-Windows_0_P.$extension"), [byte[]](9, 10))
    }

    return @{
        GameRoot    = Join-Path $Root 'game'
        PatchDir    = $patchDir
        PaksDir     = $paksDir
        L10nDir     = $l10nDir
        OfficialPak = $officialPak
    }
}

Describe 'Install-PatchForGameRoot' {
    BeforeEach {
        $layout = New-TestLayout -Root (Join-Path $TestDrive ([Guid]::NewGuid().ToString('N')))
    }

    It 'creates a verified backup and installs the patch' {
        $officialHash = (Get-FileHash -LiteralPath $layout.OfficialPak -Algorithm SHA256).Hash

        Install-PatchForGameRoot -GameRoot $layout.GameRoot -PatchDir $layout.PatchDir

        $backupPak = Join-Path $layout.GameRoot 'Aion2_English_Backup_Safe\pakchunk502000-Windows_0_P.pak'
        (Get-FileHash -LiteralPath $backupPak -Algorithm SHA256).Hash | Should Be $officialHash
        (Get-FileHash -LiteralPath $layout.OfficialPak -Algorithm SHA256).Hash |
            Should Be (Get-FileHash -LiteralPath (Join-Path $layout.PatchDir 'pakchunk502000-Windows_0_P.pak') -Algorithm SHA256).Hash
    }

    It 'can be run repeatedly without overwriting the original backup' {
        Install-PatchForGameRoot -GameRoot $layout.GameRoot -PatchDir $layout.PatchDir
        $backupPak = Join-Path $layout.GameRoot 'Aion2_English_Backup_Safe\pakchunk502000-Windows_0_P.pak'
        $backupHash = (Get-FileHash -LiteralPath $backupPak -Algorithm SHA256).Hash

        { Install-PatchForGameRoot -GameRoot $layout.GameRoot -PatchDir $layout.PatchDir } | Should Not Throw

        (Get-FileHash -LiteralPath $backupPak -Algorithm SHA256).Hash | Should Be $backupHash
    }

    It 'restores every changed file when deployment fails' {
        $l10nFile = Join-Path $layout.L10nDir 'L10NString.dat'
        [IO.File]::WriteAllBytes($l10nFile, [byte[]](20, 21, 22))
        $trackedFiles = @(
            $l10nFile,
            $layout.OfficialPak,
            (Join-Path $layout.PaksDir 'pakchunk502000-Windows_0_P.sig'),
            (Join-Path $layout.PaksDir 'pakchunk502000-Windows_0_P.ucas'),
            (Join-Path $layout.PaksDir 'pakchunk502000-Windows_0_P.utoc')
        )
        $before = @{}
        foreach ($file in $trackedFiles) {
            $before[$file] = (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash
        }

        $patchPak = Join-Path $layout.PatchDir 'pakchunk502000-Windows_0_P.pak'
        Remove-Item -LiteralPath $patchPak -Force
        New-Item -ItemType Directory -Path $patchPak | Out-Null

        $caughtError = $null
        try {
            Install-PatchForGameRoot `
                -GameRoot $layout.GameRoot `
                -PatchDir $layout.PatchDir
        }
        catch {
            $caughtError = $_
        }

        ($null -ne $caughtError) | Should Be $true
        $caughtError.Exception.Message | Should Match '已自动恢复修改前文件'
        foreach ($file in $trackedFiles) {
            (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash | Should Be $before[$file]
        }
        @(Get-ChildItem -LiteralPath $layout.GameRoot -Directory -Filter '.Aion2CNTool-rollback-*').Count | Should Be 0
    }
}
