#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Extract a code graph from the live repository.
.DESCRIPTION
    Walks the repo, parses each tracked file by type, and emits code-graph.json:
      - code-file       : every tracked file
      - code-func       : PowerShell functions, C# methods
      - code-param      : script/function parameters
      - code-section    : markdown ## headings (one level deep)
      - code-schema     : every JSON file's top-level shape
      - code-field      : first-level keys of every JSON object
      - code-test       : every *.test.md
      - code-scenario   : "Test Scenario" / "Setup" headings inside tests
      - code-class      : C# classes
      - code-import     : C# using directives, PowerShell dot-sources

    Edges:
      - contains, defined_in, calls (PS function-by-name),
        references (markdown → repo paths),
        tests (test → skill/file via Tests: frontmatter),
        instance_of (json instance → schema file)

    Auto-bridges: for every system-graph node with a 'file' field that matches
    a code-file ID, emits a system→code bridge resolved into 'implemented_by'
    edges by merge.ps1.

    Excludes: bin/, obj/, node_modules/, .git/, the knowledge-graph folder itself
    (we don't graph the graph).
.EXAMPLE
    pwsh .github/knowledge-graph/code/extract.ps1
#>
[CmdletBinding()]
param(
    [string]$Output = "data/MentorAgent/code/code-graph.json"
)

$ErrorActionPreference = "Stop"

# ---------- bootstrap ----------
$scriptDir = $PSScriptRoot
$kgRoot = Split-Path (Split-Path $scriptDir -Parent) -Parent  # .github/knowledge-graph/
$outPath = Join-Path $kgRoot $Output

# Repo root = walk up from script until .github exists alongside .profiles
$repoRoot = $scriptDir
while ($repoRoot -and -not ((Test-Path (Join-Path $repoRoot ".github")) -and (Test-Path (Join-Path $repoRoot ".profiles")))) {
    $repoRoot = Split-Path $repoRoot -Parent
}
if (-not $repoRoot) {
    Write-Host "ERROR: Could not find repo root" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Code Graph Extraction" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Repo: $repoRoot" -ForegroundColor DarkGray
Write-Host ""

# ---------- helpers ----------
function To-RepoRelative($fullPath) {
    $rel = $fullPath.Substring($repoRoot.Length).TrimStart('\', '/')
    return $rel -replace '\\', '/'
}

function To-CodeId($relPath, $suffix = $null) {
    if ($suffix) { return "code-file:$relPath::$suffix" }
    return "code-file:$relPath"
}

function Sanitize-IdPart($s) {
    return ($s -replace '[^a-zA-Z0-9_\-\.]', '_').Substring(0, [Math]::Min($s.Length, 80))
}

function Resolve-RepoRelative($fromRel, $toPath) {
    # Resolve a path written inside file $fromRel to a repo-relative slash-normalized path.
    # Strips ./, processes ../, normalizes backslashes.
    if (-not $toPath) { return $null }
    $toPath = $toPath -replace '\\', '/'
    # absolute (starts with .github, .profiles, docs — with or without trailing slash) — use as-is
    if ($toPath -match '^(\.github|\.profiles|docs)(/|$)') { return $toPath.TrimEnd('/') }
    # leading ./ or ../ — resolve relative to $fromRel's directory
    $fromDir = Split-Path ($fromRel -replace '\\', '/') -Parent
    $fromDir = $fromDir -replace '\\', '/'
    $parts = ($fromDir + '/' + $toPath) -split '/'
    $stack = New-Object System.Collections.ArrayList
    foreach ($p in $parts) {
        if ($p -eq '' -or $p -eq '.') { continue }
        if ($p -eq '..') {
            if ($stack.Count -gt 0) { [void]$stack.RemoveAt($stack.Count - 1) }
            continue
        }
        [void]$stack.Add($p)
    }
    return ($stack -join '/').TrimEnd('/')
}

function Classify-FileCluster($rel) {
    if ($rel -like '.github/agents/*')            { return 'agents-source' }
    if ($rel -like '.github/skills/*')            { return 'skills-source' }
    if ($rel -like '.github/tests/*')             { return 'tests-source' }
    if ($rel -like '.github/knowledge-graph/lib/*') { return 'scripts-source' }
    if ($rel -like '.github/knowledge-graph/cli/*') { return 'scripts-source' }
    if ($rel -like '.github/copilot-fundamentals/*') { return 'docs-source' }
    if ($rel -like '.github/copilot-instructions.md') { return 'docs-source' }
    if ($rel -like '.profiles/ProfileTests/*')    { return 'tests-source' }
    if ($rel -like '.profiles/*.ps1')             { return 'scripts-source' }
    if ($rel -like '.profiles/profiles/*')        { return 'schemas-source' }
    if ($rel -like 'extensions/*')                { return 'scripts-source' }
    if ($rel -like '*.json')                      { return 'schemas-source' }
    if ($rel -like '*.ps1')                       { return 'scripts-source' }
    if ($rel -like 'docs/*')                      { return 'docs-source' }
    if ($rel -eq 'README.md')                     { return 'docs-source' }
    return 'docs-source'
}

# ---------- discover files ----------
Write-Host "Walking repo..." -ForegroundColor Cyan

$includePatterns = @(
    '.github/agents',
    '.github/hooks',                    # Git hooks (pre-commit, install)
    '.github/skills',
    '.github/tests',
    '.github/copilot-fundamentals',
    '.github/copilot-instructions.md',
    '.github/knowledge-graph/lib',      # PowerShell modules
    '.github/knowledge-graph/cli',      # CLI scripts
    '.github/knowledge-graph/queries',  # Query scripts
    '.github/knowledge-graph/build',    # Build pipeline scripts (core/advanced/repair)
    '.github/knowledge-graph/tests',    # NEW test infrastructure (unit/integration/gate/e2e)
    '.github/knowledge-graph/AUTHORING.md',  # Authoring conventions doc
    '.profiles',
    'extensions',                       # VS Code extensions
    'docs',
    'README.md'
)

# Exclude build outputs and internal graph data, but allow lib/ cli/ build/
# Note: .vscode-test/, coverage/, .nyc_output/, tmp/ are test-harness scratch dirs that
# pull in bundled VS Code extensions; scanning them creates hundreds of disconnected islands.
# knowledge-graph/cli/archive/ holds historical scripts the agent no longer uses; including
# them creates dangling code-file nodes with no upstream cli-tool wrapper (auto-discover
# also skips archive/ — keep both in sync).
# knowledge-graph/tests/ IS scanned (intentional): the new test infrastructure lives there
# (unit/, integration/, gate/, e2e/, _harness.psm1, run-tests.ps1) and we want code-file
# nodes for every test so the audit can verify [tests] edges.
$excludeMatch = @(
    '\\bin\\', '\\obj\\', '\\node_modules\\', '\\.git\\',
    '\\knowledge-graph\\data\\',
    '\\knowledge-graph\\cli\\archive\\',
    # Template / scaffolding files in tests/ — these start with `_` and are
    # never invoked by run-tests.ps1; they exist for copy-paste only.
    # Without this exclude they become orphan code-file nodes.
    '\\knowledge-graph\\tests\\.*\\_[^\\]+\.test\.ps1$',
    '\\.vscode-test\\', '\\coverage\\', '\\.nyc_output\\', '\\tmp\\', '\\out\\', '\\dist\\', '\\.vsix-temp\\'
)

$allFiles = @()
foreach ($p in $includePatterns) {
    $full = Join-Path $repoRoot $p
    if (-not (Test-Path $full)) { continue }
    # Use -PathType + -Force for dotfile compatibility on Linux PowerShell.
    # Get-Item on hidden directories (e.g. .profiles) without -Force throws
    # "Could not find item" on Linux even when Test-Path succeeds.
    if (Test-Path $full -PathType Container) {
        $allFiles += Get-ChildItem $full -Recurse -File -Force `
            -Include *.md, *.ps1, *.psm1, *.json, *.cs, *.csproj, *.ts, *.tsx
    } else {
        $allFiles += Get-Item $full -Force
    }
}

# also grab top-level .md files directly in .github/ (PROFICIENCY_SYSTEM_*, etc.) without recursing
$githubRoot = Join-Path $repoRoot '.github'
if (Test-Path $githubRoot) {
    $allFiles += Get-ChildItem $githubRoot -File -Filter *.md
}

# also grab extensionless executables in .github/hooks/ (pre-commit, etc.) that the -Include filter above skips
$hooksRoot = Join-Path $repoRoot '.github/hooks'
if (Test-Path $hooksRoot) {
    $allFiles += Get-ChildItem $hooksRoot -File | Where-Object { -not $_.Extension }
}

# filter excludes
$files = $allFiles | Where-Object {
    $p = $_.FullName
    -not ($excludeMatch | Where-Object { $p -match $_ })
} | Sort-Object FullName -Unique

Write-Host "  Tracked files: $($files.Count)" -ForegroundColor Green
Write-Host ""

# ---------- output containers ----------
$nodes = New-Object System.Collections.ArrayList
$edges = New-Object System.Collections.ArrayList
$nodeIdIndex = @{}   # guard against duplicate node IDs
$edgeIdIndex = @{}   # dedup edges by (source|target|type) key

function Add-Node($id, $type, $label, $cluster, $file = $null, $description = $null, $extra = $null) {
    # dedupe: if ID already exists, append a counter
    if ($nodeIdIndex.ContainsKey($id)) {
        $nodeIdIndex[$id]++
        $id = "$id#$($nodeIdIndex[$id])"
    } else {
        $nodeIdIndex[$id] = 1
    }
    $n = [ordered]@{
        id = $id
        type = $type
        label = $label
        cluster = $cluster
    }
    if ($file)        { $n.file = $file }
    if ($description) { $n.description = $description }
    if ($extra)       { foreach ($k in $extra.Keys) { $n[$k] = $extra[$k] } }
    [void]$nodes.Add([PSCustomObject]$n)
    return $id
}

function Add-Edge($source, $target, $type, $label = $null) {
    # Dedup: skip if (source, target, type) already added
    $key = "$source|$target|$type"
    if ($script:edgeIdIndex.ContainsKey($key)) { return }
    $script:edgeIdIndex[$key] = $true
    $e = [ordered]@{ source = $source; target = $target; type = $type }
    if ($label) { $e.label = $label }
    [void]$edges.Add([PSCustomObject]$e)
}

# ---------- per-file extractors ----------

function Extract-PowerShell($file, $rel, $fileId) {
    $content = Get-Content $file.FullName -Raw
    $lines = $content -split "`r?`n"

    # script-level param() block
    $paramMatch = [regex]::Match($content, '(?ms)^\s*param\s*\(([^)]*)\)')
    $scriptParams = @()
    if ($paramMatch.Success) {
        $block = $paramMatch.Groups[1].Value
        # capture parameter names: [type]$Name or [Type[]]$Name or $Name
        $paramMatches = [regex]::Matches($block, '\$([A-Za-z_][A-Za-z0-9_]*)')
        $scriptParams = $paramMatches | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique
        foreach ($p in $scriptParams) {
            $paramId = "code-param:$rel`::script::$p"
            $paramId = Add-Node $paramId 'code-param' $p 'scripts-source' $rel "Script parameter -$p"
            Add-Edge $fileId $paramId 'contains'
        }
    }

    # functions: function Name { ... } or function Verb-Noun {
    $funcMatches = [regex]::Matches($content, '(?m)^\s*function\s+([A-Za-z_][A-Za-z0-9_\-]*)\s*[\({]')
    $funcsInFile = @()
    foreach ($m in $funcMatches) {
        $fname = $m.Groups[1].Value
        $fid = "code-func:$rel`::$fname"
        $funcsInFile += $fname
        $fid = Add-Node $fid 'code-func' $fname 'scripts-source' $rel "PowerShell function $fname in $rel"
        Add-Edge $fileId $fid 'contains'
        Add-Edge $fid $fileId 'defined_in'
    }

    # dot-sources: . ./file.ps1   or  . "$PSScriptRoot/..."
    $dotSources = [regex]::Matches($content, '(?m)^\s*\.\s+["'']?([^"''`\s\r\n]+\.ps1)["'']?')
    foreach ($d in $dotSources) {
        $path = $d.Groups[1].Value
        # Skip paths with unresolved PowerShell variables ($PSScriptRoot, $env:..., etc.)
        if ($path -match '\$') { continue }
        $importId = "code-import:$rel`::dot-source::" + (Sanitize-IdPart $path)
        $importId = Add-Node $importId 'code-import' ('dot-source ' + $path) 'scripts-source' $rel "Dot-source of $path"
        Add-Edge $fileId $importId 'imports'
    }

    # script invocations: & ./<script>  or  pwsh -File <script>  or  Invoke-Pester <test>
    # (comment uses placeholders so the extractor doesn't parse itself into phantom code-file nodes)
    $invokeMatches = @()
    $invokeMatches += [regex]::Matches($content, '(?m)&\s*["'']?([^\s"''`]+\.ps1)["'']?') | ForEach-Object { $_.Groups[1].Value }
    $invokeMatches += [regex]::Matches($content, '(?m)pwsh[^\r\n]*?-File\s+["'']?([^\s"''`]+\.ps1)["'']?') | ForEach-Object { $_.Groups[1].Value }
    $invokeMatches += [regex]::Matches($content, '(?m)powershell[^\r\n]*?-File\s+["'']?([^\s"''`]+\.ps1)["'']?') | ForEach-Object { $_.Groups[1].Value }
    foreach ($iv in ($invokeMatches | Select-Object -Unique)) {
        # Skip paths with unresolved PowerShell variables
        if ($iv -match '\$') { continue }
        $resolved = Resolve-RepoRelative $rel $iv
        if (-not $resolved) { continue }
        Add-Edge $fileId ("code-file:$resolved") 'invokes' "invokes $iv"
    }

    return @{ Functions = $funcsInFile }
}

function Extract-TypeScript($file, $rel, $fileId) {
    Write-Verbose "  [TypeScript] Extracting from $rel"
    $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
    if (-not $content) {
        Write-Verbose "    ⚠️ Could not read file"
        return @{ Functions = @() }
    }
    
    # Functions: export function name(...) or function name(...) or const name = (...) =>
    # Note: (?:async\s+)? lets us match async function / export async function
    $funcPatterns = @(
        '(?m)^\s*export\s+(?:async\s+)?function\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(',
        '(?m)^\s*(?:async\s+)?function\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(',
        '(?m)^\s*(?:export\s+)?const\s+([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(?:async\s*)?\([^)]*\)\s*=>'
    )
    
    $funcsInFile = @()
    foreach ($pattern in $funcPatterns) {
        $funcMatches = [regex]::Matches($content, $pattern)
        foreach ($m in $funcMatches) {
            $fname = $m.Groups[1].Value
            if ($funcsInFile -notcontains $fname) {
                $fid = "code-func:$rel`::$fname"
                $funcsInFile += $fname
                Write-Verbose "    ✓ Found function: $fname"
                $fid = Add-Node $fid 'code-func' $fname 'scripts-source' $rel "TypeScript function $fname in $rel"
                Add-Edge $fileId $fid 'contains'
                Add-Edge $fid $fileId 'defined_in'
            }
        }
    }
    
    # Imports: import { X } from './file' or import X from './file'
    $importMatches = [regex]::Matches($content, '(?m)^\s*import\s+.*?\s+from\s+[''"]([^''"]+)[''"]')
    foreach ($imp in $importMatches) {
        $importPath = $imp.Groups[1].Value
        if ($importPath -notlike './*' -and $importPath -notlike '../*') { continue }  # skip external modules
        
        # Resolve relative imports
        $resolved = Resolve-RepoRelative $rel $importPath
        if (-not $resolved) { continue }
        
        # Add .ts extension if missing (TypeScript convention)
        if ($resolved -notmatch '\.(ts|tsx|js)$') { $resolved = "$resolved.ts" }
        
        $importId = "code-import:$rel`::$importPath"
        $importId = Add-Node $importId 'code-import' "import from $importPath" 'scripts-source' $rel "Import from $importPath"
        Add-Edge $fileId $importId 'imports'
        Add-Edge $importId "code-file:$resolved" 'references'
    }
    
    Write-Verbose "    Extracted $($funcsInFile.Count) functions"
    return @{ Functions = $funcsInFile }
}

function Extract-Markdown($file, $rel, $fileId) {
    $content = Get-Content $file.FullName -Raw
    $lines = $content -split "`r?`n"

    # ---------- YAML frontmatter ----------
    # Capture between leading `---` ... `---`
    $fmMatch = [regex]::Match($content, '(?ms)\A---\s*\r?\n(.*?)\r?\n---\s*\r?\n')
    $yamlSkillsList = @()
    if ($fmMatch.Success) {
        $fm = $fmMatch.Groups[1].Value
        $fmLines = $fm -split "`r?`n"

        # 1) scalar keys: key: "value"  or  key: value  (single line only — multi-line literals ignored)
        $scalarKeys = @('name', 'description', 'model', 'applyTo', 'core_behavior', 'tools')
        foreach ($key in $scalarKeys) {
            $km = [regex]::Match($fm, '(?m)^' + [regex]::Escape($key) + ':\s*(.+?)\s*$')
            if ($km.Success) {
                $val = $km.Groups[1].Value.Trim().TrimStart('"').TrimEnd('"').TrimStart("'").TrimEnd("'")
                if ($val -eq '|' -or $val -eq '>') { continue }   # block scalar — skip value, still emit field
                $yid = "code-yaml-field:$rel`::$key"
                $yid = Add-Node $yid 'code-yaml-field' $key (Classify-FileCluster $rel) $rel "Frontmatter '${key}: $val'" @{ value = $val }
                Add-Edge $fileId $yid 'contains'
            }
        }

        # 2) list keys: skills: \n  - "path"  \n  - "path"
        $listKeys = @('skills', 'tags', 'tools')
        foreach ($key in $listKeys) {
            # find the key line
            $idx = -1
            for ($i = 0; $i -lt $fmLines.Count; $i++) {
                if ($fmLines[$i] -match ('^' + [regex]::Escape($key) + ':\s*$')) { $idx = $i; break }
            }
            if ($idx -lt 0) { continue }

            $items = @()
            for ($j = $idx + 1; $j -lt $fmLines.Count; $j++) {
                $ln = $fmLines[$j]
                if ($ln -match '^\s{0,3}-\s+(.+?)\s*$') {
                    $items += $matches[1].Trim().TrimStart('"').TrimEnd('"').TrimStart("'").TrimEnd("'")
                } elseif ($ln -match '^\S') {
                    break  # next top-level key
                }
            }
            if ($items.Count -eq 0) { continue }

            $listId = "code-yaml-field:$rel`::$key"
            $listId = Add-Node $listId 'code-yaml-field' $key (Classify-FileCluster $rel) $rel "Frontmatter list '$key' ($($items.Count) items)" @{ items = $items }
            Add-Edge $fileId $listId 'contains'

            if ($key -eq 'skills') { $yamlSkillsList = $items }
        }

        # 3) agent.composes -> skill : turn each skills list entry into a 'composes' edge to the resolved code-file
        if ($yamlSkillsList.Count -gt 0) {
            foreach ($skillRef in $yamlSkillsList) {
                # resolve relative path (paths in skills: are usually ../skills/x/SKILL.md from agents/)
                $resolved = Resolve-RepoRelative $rel $skillRef
                if ($resolved) {
                    Add-Edge $fileId ("code-file:$resolved") 'composes' "composes $skillRef"
                }
            }
        }
    }

    # ---------- ## level-2 headings ----------
    $sectionMatches = [regex]::Matches($content, '(?m)^(#{2,3})\s+(.+?)\s*$')
    foreach ($m in $sectionMatches) {
        $level = $m.Groups[1].Value.Length
        if ($level -gt 2) { continue }  # only ## for now to keep graph manageable
        $title = $m.Groups[2].Value.Trim()
        $sid = "code-section:$rel`::" + (Sanitize-IdPart $title)
        $sid = Add-Node $sid 'code-section' $title (Classify-FileCluster $rel) $rel "Section '$title' in $rel"
        Add-Edge $fileId $sid 'contains'
    }

    # YAML frontmatter — look for Tests: line in test files
    $isTest = $rel -like '*.test.md'
    if ($isTest) {
        # convert this file node into a test (we still keep code-file too)
        $testId = "code-test:$rel"
        $testId = Add-Node $testId 'code-test' (Split-Path $rel -Leaf) 'tests-source' $rel "Behavioral test scenario file"
        Add-Edge $testId $fileId 'defined_in'

        # parse 'Tests:' or '**Tests:**' line
        $testsLine = [regex]::Match($content, '(?m)^\*?\*?Tests:\*?\*?\s*(.+?)$')
        if ($testsLine.Success) {
            $target = $testsLine.Groups[1].Value.Trim()
            $targetIdPart = Sanitize-IdPart $target
            $covId = "code-import:$rel`::tests::$targetIdPart"
            $covId = Add-Node $covId 'code-import' "tests $target" 'tests-source' $rel "Test asserts behavior of $target"
            Add-Edge $testId $covId 'tests' "Tests: $target"
        }

        # extract scenarios (any ### inside a Test Scenario block, or just ## Test Scenario itself)
        $scenarioMatches = [regex]::Matches($content, '(?m)^#{2,3}\s*(Test Scenario|Setup|Expected Behavior|Pass Criteria|Actual Result)\s*$')
        foreach ($s in $scenarioMatches) {
            $sname = $s.Groups[1].Value.Trim()
            $scid = "code-scenario:$rel`::" + (Sanitize-IdPart $sname)
            $scid = Add-Node $scid 'code-scenario' $sname 'tests-source' $rel "Scenario step '$sname'"
            Add-Edge $testId $scid 'contains'
        }
    }

    # markdown references to other repo paths — ONLY inline [text](path) markdown links.
    # Backtick mentions are excluded because skill curriculum frequently uses backticks for
    # teaching content (e.g. "Create `.github/agents/foo.agent.md`") which are not real refs.
    $refRegex = '\[[^\]]+\]\(((?:\.github|\.profiles|docs)/[A-Za-z0-9_\-/\.]+\.(?:md|json|ps1|cs))\)'
    $refMatches = [regex]::Matches($content, $refRegex)
    $refsSeen = @{}
    foreach ($r in $refMatches) {
        $target = $r.Groups[1].Value -replace '\\', '/'
        if ($target -eq $rel) { continue }  # skip self-references
        if ($refsSeen.ContainsKey($target)) { continue }
        $refsSeen[$target] = $true
        $tid = "code-file:$target"
        Add-Edge $fileId $tid 'references' $target
    }

    # script invocations inside markdown code blocks (pwsh -File <script>, & ./<script>, Invoke-Pester <test>)
    # require .ps1 extension to avoid catching directories or generic prose
    # (comment uses placeholders so the extractor doesn't parse itself into phantom code-file nodes)
    $mdInvokes = @()
    $mdInvokes += [regex]::Matches($content, '(?m)pwsh[^\r\n]*?(?:-File\s+|\s+)["'']?((?:\.github|\.profiles|docs|\.\.?\/)[^\s"''`]*?\.ps1)["'']?') | ForEach-Object { $_.Groups[1].Value }
    $mdInvokes += [regex]::Matches($content, '(?m)Invoke-Pester\s+["'']?((?:\.github|\.profiles|docs)[^\s"''`]*?\.ps1)["'']?') | ForEach-Object { $_.Groups[1].Value }
    $mdInvokes += [regex]::Matches($content, '(?m)&\s+["'']?((?:\.github|\.profiles|docs)[^\s"''`]+\.ps1)["'']?') | ForEach-Object { $_.Groups[1].Value }
    foreach ($iv in ($mdInvokes | Select-Object -Unique)) {
        $resolved = Resolve-RepoRelative $rel $iv
        if (-not $resolved) { continue }
        if ($resolved -notlike '*.ps1') { continue }   # safety: only file-level invocations
        Add-Edge $fileId ("code-file:$resolved") 'invokes' "invokes $iv"
    }
}

function Extract-Json($file, $rel, $fileId) {
    try {
        $raw = Get-Content $file.FullName -Raw
        $data = $raw | ConvertFrom-Json -ErrorAction Stop
    } catch {
        Write-Host "  WARN: skipped invalid JSON: $rel" -ForegroundColor Yellow
        return
    }

    $schemaId = "code-schema:$rel"
    $shape = if ($data -is [System.Collections.IEnumerable] -and -not ($data -is [string])) { 'array' } else { 'object' }
    $schemaId = Add-Node $schemaId 'code-schema' (Split-Path $rel -Leaf) 'schemas-source' $rel "JSON shape: $shape" @{ shape = $shape }
    Add-Edge $fileId $schemaId 'contains'

    # first-level keys only — keeps graph tractable
    if ($shape -eq 'object' -and $data.PSObject -and $data.PSObject.Properties) {
        foreach ($prop in $data.PSObject.Properties) {
            $kname = $prop.Name
            $kid = "code-field:$rel`::" + (Sanitize-IdPart $kname)
            $vtype = if ($null -eq $prop.Value) {
                'null'
            } elseif ($prop.Value -is [bool])    { 'bool' }
              elseif ($prop.Value -is [int] -or $prop.Value -is [long] -or $prop.Value -is [double]) { 'number' }
              elseif ($prop.Value -is [string]) { 'string' }
              elseif ($prop.Value -is [System.Collections.IEnumerable]) { 'array' }
              else { 'object' }
            $kid = Add-Node $kid 'code-field' $kname 'schemas-source' $rel "Field '$kname' (type=$vtype)" @{ value_type = $vtype }
            Add-Edge $schemaId $kid 'contains'
        }
    }
}

function Extract-CSharp($file, $rel, $fileId) {
    $content = Get-Content $file.FullName -Raw

    # using directives
    $usingMatches = [regex]::Matches($content, '(?m)^\s*using\s+([A-Za-z_][A-Za-z0-9_\.]*)\s*;')
    foreach ($u in $usingMatches) {
        $ns = $u.Groups[1].Value
        $uid = "code-import:$rel`::using::" + (Sanitize-IdPart $ns)
        $uid = Add-Node $uid 'code-import' "using $ns" 'tests-source' $rel "C# using directive: $ns"
        Add-Edge $fileId $uid 'imports'
    }

    # classes
    $classMatches = [regex]::Matches($content, '(?m)^\s*public\s+class\s+([A-Za-z_][A-Za-z0-9_]*)')
    foreach ($c in $classMatches) {
        $cname = $c.Groups[1].Value
        $cid = "code-class:$rel`::$cname"
        $cid = Add-Node $cid 'code-class' $cname 'tests-source' $rel "C# class $cname in $rel"
        Add-Edge $fileId $cid 'contains'
    }

    # public methods (test methods) — public [TypeOrVoid] Name(...)
    $methodMatches = [regex]::Matches($content, '(?m)^\s*public\s+(?:async\s+)?(?:[A-Za-z_][A-Za-z0-9_<>,\[\]\s]*?)\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(')
    foreach ($mm in $methodMatches) {
        $mname = $mm.Groups[1].Value
        if ($mname -in @('class', 'void', 'static', 'string', 'int', 'bool')) { continue }
        $mid = "code-func:$rel`::$mname"
        $mid = Add-Node $mid 'code-func' $mname 'tests-source' $rel "C# method $mname"
        Add-Edge $fileId $mid 'contains'
        Add-Edge $mid $fileId 'defined_in'
    }
}

# ---------- pass 1: create code-file nodes + per-type extraction ----------
$psFuncMap = @{}  # rel -> list of function names defined there

foreach ($f in $files) {
    $rel = To-RepoRelative $f.FullName
    $fileId = To-CodeId $rel
    $cluster = Classify-FileCluster $rel
    $ext = $f.Extension.ToLower()

    $extra = [ordered]@{
        extension = $ext
        size_bytes = $f.Length
    }
    $fileId = Add-Node $fileId 'code-file' (Split-Path $rel -Leaf) $cluster $rel "File: $rel" $extra

    switch ($ext) {
        '.ps1'    { $r = Extract-PowerShell $f $rel $fileId; if ($r.Functions) { $psFuncMap[$rel] = $r.Functions } }
        '.psm1'   { $r = Extract-PowerShell $f $rel $fileId; if ($r.Functions) { $psFuncMap[$rel] = $r.Functions } }
        '.md'     { Extract-Markdown $f $rel $fileId }
        '.json'   { Extract-Json $f $rel $fileId }
        '.cs'     { Extract-CSharp $f $rel $fileId }
        '.ts'     { $r = Extract-TypeScript $f $rel $fileId; if ($r.Functions) { $psFuncMap[$rel] = $r.Functions } }
        '.tsx'    { $r = Extract-TypeScript $f $rel $fileId; if ($r.Functions) { $psFuncMap[$rel] = $r.Functions } }
        '.csproj' { }  # just the file node
    }
}

# ---------- pass 1b: project structure edges ----------
Write-Host "Linking project structure (C# projects, npm packages, VS Code extensions)..." -ForegroundColor Cyan
$projectEdges = 0

# C# projects: link .csproj to all .cs files in same directory
$csprojFiles = $files | Where-Object { $_.Extension -eq '.csproj' }
foreach ($csproj in $csprojFiles) {
    $projDir = $csproj.DirectoryName
    $projRel = To-RepoRelative $csproj.FullName
    $projId = To-CodeId $projRel
    
    # Find all .cs files in same directory
    $csFiles = $files | Where-Object { $_.Extension -eq '.cs' -and $_.DirectoryName -eq $projDir }
    foreach ($cs in $csFiles) {
        $csRel = To-RepoRelative $cs.FullName
        $csId = To-CodeId $csRel
        [void]$edges.Add([PSCustomObject]@{
            source = $projId
            target = $csId
            type = 'contains'
        })
        $projectEdges++
    }
}

# npm packages: link package.json to *.ts, *.tsx in src/
$packageJsonFiles = $files | Where-Object { $_.Name -eq 'package.json' }
foreach ($pkg in $packageJsonFiles) {
    $pkgDir = $pkg.DirectoryName
    $srcDir = Join-Path $pkgDir 'src'
    if (-not (Test-Path $srcDir)) { continue }
    
    $pkgRel = To-RepoRelative $pkg.FullName
    $pkgId = To-CodeId $pkgRel
    
    # Find all .ts/.tsx files in src/
    $tsFiles = Get-ChildItem $srcDir -Recurse -File -Include *.ts, *.tsx
    foreach ($ts in $tsFiles) {
        $tsRel = To-RepoRelative $ts.FullName
        $tsId = To-CodeId $tsRel
        [void]$edges.Add([PSCustomObject]@{
            source = $pkgId
            target = $tsId
            type = 'contains'
        })
        $projectEdges++
    }
}

Write-Host "  Project structure edges: $projectEdges" -ForegroundColor Green

# ---------- pass 2: PS function call graph (best-effort) ----------
Write-Host "Inferring PowerShell call graph..." -ForegroundColor Cyan

# build name -> id index
$funcIndex = @{}
foreach ($n in $nodes) {
    if ($n.type -eq 'code-func' -and $n.id -like 'code-func:*.ps1::*') {
        if (-not $funcIndex.ContainsKey($n.label)) {
            $funcIndex[$n.label] = $n.id
        }
    }
}

# scan each PS file for invocations of known function names
$callCount = 0
foreach ($f in ($files | Where-Object { $_.Extension -eq '.ps1' })) {
    $rel = To-RepoRelative $f.FullName
    $fileId = To-CodeId $rel
    $content = Get-Content $f.FullName -Raw
    $seenCalls = @{}
    foreach ($name in $funcIndex.Keys) {
        # call site: name not preceded by 'function ', not inside a string (best-effort)
        $pattern = '(?<![\w\-])' + [regex]::Escape($name) + '(?![\w\-])'
        $matchHits = [regex]::Matches($content, $pattern)
        # must appear at least once beyond its own definition (PS funcs are usually called somewhere besides "function X")
        $defPattern = '(?m)^\s*function\s+' + [regex]::Escape($name) + '\s*[\({]'
        $isDefinedHere = [regex]::IsMatch($content, $defPattern)
        # SKIP self-calls: if the file already defines the function, the
        # [contains] edge carries the canonical relationship. Emitting [calls]
        # on the same source->target pair creates "multi-carrier" duplicate
        # edges that show up as edge-quality warnings in health.ps1.
        # External callers (file A calls function defined in file B) still get
        # the [calls] edge — that's the case the relationship was designed for.
        if ($isDefinedHere) { continue }
        if ($matchHits.Count -gt 0) {
            $key = $fileId + '|' + $funcIndex[$name]
            if (-not $seenCalls.ContainsKey($key)) {
                Add-Edge $fileId $funcIndex[$name] 'calls' "calls $name"
                $seenCalls[$key] = $true
                $callCount++
            }
        }
    }
}
Write-Host "  Inferred $callCount call edges" -ForegroundColor Green
Write-Host ""

# ---------- pass 3: auto-bridge to system graph ----------
Write-Host "Auto-bridging to system graph..." -ForegroundColor Cyan

$systemGraphPath = Join-Path $repoRoot ".github/knowledge-graph/data/MentorAgent/system/mentor-graph.json"
$bridges = @()
if (Test-Path $systemGraphPath) {
    $sysGraph = Get-Content $systemGraphPath -Raw | ConvertFrom-Json
    # build set of code-file IDs we just emitted
    $codeFileIds = @{}
    foreach ($n in $nodes) {
        if ($n.type -eq 'code-file') { $codeFileIds[$n.id] = $true }
    }
    foreach ($sn in $sysGraph.nodes) {
        if (-not $sn.file) { continue }
        if ($sn.file -match '\{.*\}') { continue }  # skip path templates
        $codeId = "code-file:" + ($sn.file -replace '\\', '/')
        if ($codeFileIds.ContainsKey($codeId)) {
            $bridges += [PSCustomObject]@{
                system = $sn.id
                code   = $codeId
                type   = 'implemented_by'
            }
        }
    }
    
    # Emit instance_of bridges for .progress.json and .profile.json files
    foreach ($n in $nodes) {
        if ($n.type -eq 'code-schema') {
            if ($n.id -match '\.progress\.json$') {
                $bridges += [PSCustomObject]@{
                    system = 'schema:progress-json'
                    code   = $n.id
                    type   = 'instance_of'
                }
            } elseif ($n.id -match '\.profile\.json$|/profile\.json$') {
                $bridges += [PSCustomObject]@{
                    system = 'schema:profile-json'
                    code   = $n.id
                    type   = 'instance_of'
                }
            } elseif ($n.id -match '\.profiles/profiles/(mentees|mentors)/[^/]+\.json$') {
                # Flat-structure profiles: mentees/{username}.json or mentors/{username}.json
                $bridges += [PSCustomObject]@{
                    system = 'schema:profile-json'
                    code   = $n.id
                    type   = 'instance_of'
                }
            }
        }
    }Write-Host "  Bridges: $($bridges.Count) system nodes mapped to code files" -ForegroundColor Green
} else {
    Write-Host "  WARN: system graph not found at $systemGraphPath" -ForegroundColor Yellow
}
Write-Host ""

# ---------- pass 4: edge connectivity audit ----------
Write-Host "Auditing edge connectivity..." -ForegroundColor Cyan

# rebuild node ID set from final $nodes
$allNodeIds = @{}
foreach ($n in $nodes) { $allNodeIds[$n.id] = $true }

$danglingEdges = New-Object System.Collections.ArrayList
$missingTargets = @{}   # id -> count of edges pointing at it
foreach ($e in $edges) {
    $srcMissing = -not $allNodeIds.ContainsKey($e.source)
    $tgtMissing = -not $allNodeIds.ContainsKey($e.target)
    if ($srcMissing) {
        [void]$danglingEdges.Add([PSCustomObject]@{ side='source'; id=$e.source; edge=$e })
    }
    if ($tgtMissing) {
        [void]$danglingEdges.Add([PSCustomObject]@{ side='target'; id=$e.target; edge=$e })
        if ($missingTargets.ContainsKey($e.target)) { $missingTargets[$e.target]++ } else { $missingTargets[$e.target] = 1 }
    }
}

# Stub-fill: for every missing target that looks like a code-file: id, create a stub node so the edge isn't dangling.
$stubCount = 0
foreach ($missingId in @($missingTargets.Keys)) {
    if ($missingId -notlike 'code-file:*') { continue }
    $missingRel = $missingId.Substring('code-file:'.Length)
    $stubNode = [ordered]@{
        id = $missingId
        type = 'code-file'
        label = (Split-Path $missingRel -Leaf)
        cluster = (Classify-FileCluster $missingRel)
        file = $missingRel
        description = "STUB: referenced by $($missingTargets[$missingId]) edge(s) but file not found on disk"
        missing = $true
    }
    [void]$nodes.Add([PSCustomObject]$stubNode)
    $allNodeIds[$missingId] = $true
    $stubCount++
}

# Recompute dangling after stubs
$realDangling = $danglingEdges | Where-Object { -not $allNodeIds.ContainsKey($_.id) }
$realDanglingCount = ($realDangling | Measure-Object).Count

# Orphan nodes (no inbound or outbound edges)
$nodesWithEdges = @{}
foreach ($e in $edges) {
    $nodesWithEdges[$e.source] = $true
    $nodesWithEdges[$e.target] = $true
}
$orphans = $nodes | Where-Object { -not $nodesWithEdges.ContainsKey($_.id) }
$orphanCount = ($orphans | Measure-Object).Count

Write-Host "  Total edges:        $($edges.Count)" -ForegroundColor Green
Write-Host "  Missing endpoints:  $($danglingEdges.Count) (before stubbing)" -ForegroundColor $(if ($danglingEdges.Count -gt 0) {'Yellow'} else {'Green'})
Write-Host "  Stub nodes added:   $stubCount" -ForegroundColor Cyan
Write-Host "  Still dangling:     $realDanglingCount" -ForegroundColor $(if ($realDanglingCount -gt 0) {'Red'} else {'Green'})
Write-Host "  Orphan nodes:       $orphanCount" -ForegroundColor $(if ($orphanCount -gt 0) {'Yellow'} else {'Green'})

# Sample report (top 5 by count)
if ($missingTargets.Count -gt 0) {
    Write-Host ""
    Write-Host "  Top missing reference targets:" -ForegroundColor DarkGray
    $missingTargets.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 5 | ForEach-Object {
        Write-Host ("    {0,3}x  {1}" -f $_.Value, $_.Key) -ForegroundColor DarkGray
    }
}
Write-Host ""

# ---------- assemble + write ----------
$graph = [ordered]@{
    metadata = [ordered]@{
        name = "MSSA Mentor — Code Graph (Source Map)"
        version = 1
        generated = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssK")
        generator = "code/extract.ps1"
        description = "Auto-generated source-level map of every tracked file and what's inside it. Sibling to ../system/mentor-graph.json. Merged via ../merge.ps1."
        id_prefixes = @(
            "code-file", "code-func", "code-param", "code-section",
            "code-schema", "code-field", "code-test", "code-scenario",
            "code-class", "code-import", "code-yaml-field"
        )
        stats = [ordered]@{
            files = ($nodes | Where-Object { $_.type -eq 'code-file' -and -not $_.missing }).Count
            stub_files = ($nodes | Where-Object { $_.type -eq 'code-file' -and $_.missing }).Count
            functions = ($nodes | Where-Object { $_.type -eq 'code-func' }).Count
            sections = ($nodes | Where-Object { $_.type -eq 'code-section' }).Count
            schemas = ($nodes | Where-Object { $_.type -eq 'code-schema' }).Count
            fields = ($nodes | Where-Object { $_.type -eq 'code-field' }).Count
            yaml_fields = ($nodes | Where-Object { $_.type -eq 'code-yaml-field' }).Count
            tests = ($nodes | Where-Object { $_.type -eq 'code-test' }).Count
            scenarios = ($nodes | Where-Object { $_.type -eq 'code-scenario' }).Count
            classes = ($nodes | Where-Object { $_.type -eq 'code-class' }).Count
            imports = ($nodes | Where-Object { $_.type -eq 'code-import' }).Count
            total_nodes = $nodes.Count
            total_edges = $edges.Count
            bridges = $bridges.Count
            dangling_edges = $realDanglingCount
            orphan_nodes = $orphanCount
        }
    }
    clusters = @(
        [ordered]@{ id = 'agents-source';   label = 'Agents (source)';            description = 'Files defining agent personas (.github/agents/*.agent.md)' }
        [ordered]@{ id = 'skills-source';   label = 'Skills (source)';            description = 'Files defining skills (.github/skills/**/SKILL.md) plus reference data' }
        [ordered]@{ id = 'scripts-source';  label = 'Scripts';                    description = 'PowerShell automation: validation, editing, audit' }
        [ordered]@{ id = 'schemas-source';  label = 'JSON schemas & instances';   description = 'profile.json, progress.json, method-proficiency-levels.json, etc.' }
        [ordered]@{ id = 'tests-source';    label = 'Tests';                      description = 'Behavioral .test.md files and xUnit ProfileTests project' }
        [ordered]@{ id = 'docs-source';     label = 'Documentation';              description = 'READMEs, MENTOR_DIRECTORY.md, copilot-fundamentals, etc.' }
    )
    nodes = @($nodes)
    edges = @($edges)
    bridges = @($bridges)
    analysis = [ordered]@{
        status = "auto-generated; rerun extract.ps1 to refresh"
        notes = @(
            "Markdown references that point at files not present in the repo appear as edges to missing nodes — merge.ps1 will detect these.",
            "PS function call inference is best-effort by name match. False positives possible when names collide with parameters or strings.",
            "Only first-level JSON fields are extracted to keep node count tractable; deepen by editing Extract-Json if needed."
        )
    }
}

$json = $graph | ConvertTo-Json -Depth 32
Set-Content -Path $outPath -Value $json -Encoding UTF8

# ---------- summary ----------
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
$s = $graph.metadata.stats
Write-Host ("  Files:        {0}" -f $s.files)        -ForegroundColor Green
Write-Host ("  Stub files:   {0}" -f $s.stub_files)   -ForegroundColor $(if ($s.stub_files -gt 0) {'Yellow'} else {'Green'})
Write-Host ("  Functions:    {0}" -f $s.functions)    -ForegroundColor Green
Write-Host ("  Sections:     {0}" -f $s.sections)     -ForegroundColor Green
Write-Host ("  Schemas:      {0}" -f $s.schemas)      -ForegroundColor Green
Write-Host ("  Fields:       {0}" -f $s.fields)       -ForegroundColor Green
Write-Host ("  YAML fields:  {0}" -f $s.yaml_fields)  -ForegroundColor Green
Write-Host ("  Tests:        {0}" -f $s.tests)        -ForegroundColor Green
Write-Host ("  Scenarios:    {0}" -f $s.scenarios)    -ForegroundColor Green
Write-Host ("  Classes:      {0}" -f $s.classes)      -ForegroundColor Green
Write-Host ("  Imports:      {0}" -f $s.imports)      -ForegroundColor Green
Write-Host ""
Write-Host ("  Nodes:        {0}" -f $s.total_nodes)   -ForegroundColor Cyan
Write-Host ("  Edges:        {0}" -f $s.total_edges)   -ForegroundColor Cyan
Write-Host ("  Bridges:      {0}" -f $s.bridges)       -ForegroundColor Cyan
Write-Host ("  Dangling:     {0}" -f $s.dangling_edges) -ForegroundColor $(if ($s.dangling_edges -gt 0) {'Red'} else {'Green'})
Write-Host ("  Orphans:      {0}" -f $s.orphan_nodes)   -ForegroundColor $(if ($s.orphan_nodes -gt 0) {'Yellow'} else {'Green'})
Write-Host ""
Write-Host "  Output: $Output" -ForegroundColor Green
Write-Host ""
