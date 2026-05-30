# Learner Profile Management

This directory contains learner profiles and profile management tools for the MSSA Mentor system.

## Structure

```
.profiles/
├── profiles/
│   ├── mentors/          ← Mentor/developer test profiles
│   │   └── jasteenb.json
│   └── mentees/          ← MSSA learner profiles
│       ├── alex_smith.json
│       └── sarah_johnson.json
├── ProfileTests/         ← xUnit validation tests
│   ├── ProfileTests.csproj
│   └── LearnerProfileCompletenessTests.cs
├── edit-profile.ps1      ← Interactive profile editor
├── validate-profile.ps1  ← Schema validation runner
└── README.md             ← This file
```

## Workflow

### Creating a new profile

When `@Mentor` detects a new learner (no profile exists):

1. Mentor runs 10-question interview
2. Mentor creates `.profiles/mentees/{username}.json`
3. Mentor runs validation: `.\validate-profile.ps1 -Username {username}`
4. If valid, commits with message: `"Add learner profile: {name}"`
5. If invalid, fixes missing fields and re-validates

### Editing an existing profile

**Interactive (recommended):**
```powershell
.\.profiles\edit-profile.ps1
```

- Menu-driven field editing
- Built-in validation before save
- Auto-commits with descriptive message

**Direct edit:**
```powershell
# 1. Edit the JSON manually
code .profiles/mentees/jasteenb.json

# 2. Validate
.\.profiles\validate-profile.ps1 -Username jasteenb

# 3. Commit if valid
git add .profiles/mentees/jasteenb.json
git commit -m "Update learner profile: Jay (revised pace)"
```

### Validating all profiles

**From repo root:**
```powershell
.\.profiles\validate-profile.ps1
```

**From any subdirectory:**
```powershell
& "$env:USERPROFILE\source\repos\MSSAMentorAgent\.profiles\validate-profile.ps1"
```

Or set up a PowerShell alias for convenience:
```powershell
# Add to your PowerShell profile
function Validate-LearnerProfile { & "C:\Users\jasteenb\source\repos\MSSAMentorAgent\.profiles\validate-profile.ps1" @args }
Set-Alias -Name vlp -Value Validate-LearnerProfile
```

Then from anywhere:
```powershell
vlp -Username jasteenb
```

Runs xUnit tests against all profiles in `mentees/`. Useful for:
- Verifying schema changes don't break existing profiles
- Pre-commit checks
- CI/CD validation

### Validating a single profile

**From repo root:**
```powershell
.\.profiles\validate-profile.ps1 -Username jasteenb
```

**From any subdirectory (use call operator `&`):**
```powershell
& "$env:USERPROFILE\source\repos\MSSAMentorAgent\.profiles\validate-profile.ps1" -Username jasteenb
```

Runs only tests for the specified profile. Faster for checking recent edits.

**Note:** PowerShell requires scripts invoked with relative paths to use the `&` call operator when outside the script's directory. The script itself handles finding the repo root automatically.

## Profile schema

See [`.github/skills/learner-profile/SKILL.md`](../.github/skills/learner-profile/SKILL.md) for the full schema and field guide.

**Required fields:**
- `name`, `preferred_name`, `github_username`
- `learning_style.prefers`, `pace_preference`, `when_stuck`
- `personality.self_description`, `motivation`
- `military.branch`, `job_description` (can't be "N/A" for MSSA learners)
- `progress.current_track`, `current_project`
- Timestamps: `created`, `last_updated`
- At least one `session_history` entry

## Validation rules

Tests check:
- All required string fields are non-empty
- Military fields are NOT "N/A" (unless explicitly a test/dev profile)
- Arrays have at least one element
- Dictionaries have at least one key
- Timestamps are valid ISO 8601 format
- Military data is internally consistent

Tests live in `.github/tests/ProfileTests/`.

## Git workflow

All profile operations are tracked in Git:
- Profile creation → committed immediately
- Milestone completion → profile updated + committed
- Session end → history appended + committed
- Profile edits → validated + committed

Profiles travel with the repo so progress syncs automatically across learners and machines.

## Multi-learner coordination

When multiple learners work in the same repo:
- Each has their own profile in `mentees/`
- Mentor detects dependencies (e.g., Sarah finished the data model, Alex can now start the controller)
- Merge conflicts on code are expected — resolving them is part of the learning
- Profile files rarely conflict (each learner has their own)

## Troubleshooting

**Profile validation fails:**
- Run `.\.profiles\validate-profile.ps1 -Username {name}` to see specific errors
- Common issues: empty required fields, "N/A" in military fields, missing session history

**Can't find profile:**
- Check `.profiles/mentees/{username}.json` exists
- Verify username matches Git config: `git config user.name`

**Corrupt JSON:**
- Mentor will detect parse errors and offer to rebuild from Git history
- Always fixable — Git log has all the data
