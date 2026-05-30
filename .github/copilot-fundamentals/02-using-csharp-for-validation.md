# Using C# for Profile Validation in a Skill

**Created:** 2026-05-29  
**Context:** MSSA Mentor Agent profile system

---

## The Problem

We needed schema validation for learner profiles (JSON files) that could run:
- During development (via command)
- From any directory (developers don't always work from repo root)
- As part of an interactive workflow (edit → validate → commit)
- With clear, actionable error messages

Validation logic needed to be:
1. **Testable** — run the same validation in tests and production
2. **Fast** — sub-second feedback for developers
3. **Portable** — same code works on Windows/macOS/Linux
4. **Integrated** — callable from PowerShell scripts

---

## Why C# + xUnit?

### The MSSA Connection

**The mentor teaches C#.** MSSA Cloud Application Development track uses C# + .NET. Having validation tests in the same language:
- Gives learners real-world examples they can read
- Demonstrates professional .NET patterns (testing, JSON deserialization, path handling)
- Shows how to build tooling around your application

### Technical Fit

| Requirement | How C# Delivers |
|---|---|
| **Schema validation** | `System.Text.Json` with strongly-typed models + `JsonPropertyName` attributes |
| **Test framework** | xUnit — industry standard, clean test discovery, parallel execution |
| **Path portability** | `Path.Combine()` + `AppContext.BaseDirectory` — works on any OS |
| **PowerShell integration** | `dotnet test` CLI — native interop, structured output |
| **IDE support** | IntelliSense, debugger, Test Explorer in VS Code |

---

## Architecture

```
.profiles/
├── profiles/
│   ├── mentors/              ← Test profiles (jasteenb.json)
│   └── mentees/              ← MSSA learner profiles
├── ProfileTests/             ← C# xUnit test project
│   ├── ProfileTests.csproj
│   └── LearnerProfileCompletenessTests.cs
├── validate-profile.ps1     ← PowerShell wrapper (builds + runs tests)
└── edit-profile.ps1         ← Editor (validates before save)
```

**Data flow:**
1. Developer edits profile JSON
2. Calls `validate-profile.ps1` (PowerShell)
3. Script builds C# test project
4. xUnit runs 9 validation tests
5. Results returned to PowerShell
6. PowerShell formats output for user

---

## C# Implementation Patterns

### 1. Snake_case JSON → PascalCase C# 

**Problem:** JSON uses `github_username`, C# convention is `GithubUsername`.

**Solution:** `JsonPropertyName` attributes

```csharp
public class LearnerProfile
{
    [JsonPropertyName("github_username")]
    public string GithubUsername { get; set; } = string.Empty;
    
    [JsonPropertyName("learning_style")]
    public LearningStyle LearningStyle { get; set; } = new();
}
```

**Why:** Keeps JSON readable for non-developers, C# code idiomatic.

### 2. Absolute Paths from Test DLL Location

**Problem:** `dotnet test` runs from `bin/Debug/net8.0`, not project root. Relative paths break.

**Solution:** `AppContext.BaseDirectory` + explicit traversal

```csharp
private static readonly string MenteesDirectory = Path.Combine(
    AppContext.BaseDirectory,  // Where the test DLL is
    "../../../../profiles/mentees"  // Walk up to repo root, then down
);
```

**Why:** Works regardless of where `dotnet test` is invoked from.

### 3. Parameterized Tests for Multiple Profiles

**Problem:** Same validation logic for all profiles.

**Solution:** xUnit `[Theory]` with `[InlineData]`

```csharp
[Theory]
[InlineData("alex_smith.json", false)]  // mentee
[InlineData("jasteenb.json", true)]     // mentor (test profile)
public void Profile_ShouldHaveAllRequiredFields(string profileFileName, bool isMentor = false)
{
    var directory = isMentor ? MentorsDirectory : MenteesDirectory;
    var profilePath = Path.Combine(directory, profileFileName);
    // ... validation logic
}
```

**Why:** One test method validates all profiles. Add new profile = add one line of `[InlineData]`.

### 4. Descriptive Assertions

**Problem:** Generic "assertion failed" doesn't tell you what's missing.

**Solution:** Assertion messages

```csharp
Assert.False(
    string.IsNullOrWhiteSpace(profile.Name), 
    "Name is required"  // ← Shows in failure output
);

Assert.True(
    profile.Military.ExtractedConcepts.Length >= 3,
    "Should have at least 3 extracted concepts from military experience"
);
```

**Why:** Developer sees exactly what to fix without reading test code.

---

## PowerShell Integration

### Building the Project

```powershell
$testProject = Join-Path $repoRoot ".profiles/ProfileTests/ProfileTests.csproj"
dotnet build $testProject --nologo --verbosity quiet
```

### Running Tests

```powershell
# All profiles
dotnet test --no-build --nologo --verbosity quiet

# One profile
dotnet test --no-build --filter "FullyQualifiedName~jasteenb"
```

### Parsing Failures

```powershell
if ($exitCode -ne 0) {
    $testResult | Select-String "Profile_" | ForEach-Object {
        if ($_ -match '\[FAIL\]') {
            $testName = ($_ -split '\(')[0] -replace '.*Profile_', ''
            Write-Host "  ✗ $testName" -ForegroundColor Red
        }
    }
}
```

---

## What This Teaches Learners

When an MSSA student looks at this code, they see:

1. **Professional project structure** — separate test project, proper dependencies
2. **JSON serialization** — real-world data interchange
3. **Testing patterns** — Theory/InlineData, arrange-act-assert
4. **Cross-platform path handling** — `Path.Combine`, not string concatenation
5. **Build automation** — PowerShell calling .NET CLI
6. **Error handling** — validation, clear messages, exit codes

This is production-quality tooling using the tech stack they're learning.

---

## Alternatives Considered

| Approach | Why Not |
|---|---|
| **PowerShell only** | No strong typing, JSON parsing is clunky, hard to test |
| **Python** | Not the language MSSA teaches; would need separate install |
| **JSON Schema** | Good for structure, but validation logic (e.g., "3+ concepts") requires code |
| **TypeScript** | Valid choice, but MSSA curriculum is C#-first |

---

## Key Takeaways

- **Use the learner's language** — validation in C# because we teach C#
- **Tests are documentation** — learners read tests to understand the profile schema
- **Path handling is hard** — always test from multiple directories
- **PowerShell wraps, C# executes** — each tool does what it's good at
- **Tooling is part of the lesson** — show learners how professionals build around their apps

---

## Try It Yourself

```powershell
# From repo root
.\.profiles\validate-profile.ps1 -Username jasteenb

# From test project
cd .profiles/ProfileTests
& "C:\path\to\repo\.profiles\validate-profile.ps1"

# Direct test run (for debugging)
cd .profiles/ProfileTests
dotnet test --verbosity normal
```
