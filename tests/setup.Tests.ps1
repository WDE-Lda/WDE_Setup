#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }
# Runs the SHA-256 check lines taken from setup.ps1 itself, so the test follows the real script.

BeforeAll {
    $ast = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot '..\setup.ps1'), [ref]$null, [ref]$null)
    $lines = $ast.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.AssignmentStatementAst] -and
            $node.Left.Extent.Text -in '$expected', '$actual'
        }, $true) | ForEach-Object { $_.Extent.Text }
    $script:hashCheck = [scriptblock]::Create(($lines -join "`n") + "`n" + '$actual -eq $expected')

    $zip = Join-Path $TestDrive 'GitWorkflow.zip'
    $script:checksumFile = "$zip.sha256"
    [IO.File]::WriteAllText($zip, 'payload')
    $script:good = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLowerInvariant()
}

Describe 'setup.ps1 SHA-256 check' {
    It 'finds both hash lines in setup.ps1' {
        $lines.Count | Should -Be 2
    }
    It 'accepts the right hash' {
        [IO.File]::WriteAllText($script:checksumFile, "$script:good  GitWorkflow.zip`n")
        . $script:hashCheck | Should -BeTrue
    }
    It 'rejects a wrong hash' {
        [IO.File]::WriteAllText($script:checksumFile, ('0' * 64) + "  GitWorkflow.zip`n")
        . $script:hashCheck | Should -BeFalse
    }
    It 'rejects an empty checksum file' {
        [IO.File]::WriteAllText($script:checksumFile, '')
        . $script:hashCheck | Should -BeFalse
    }
}
