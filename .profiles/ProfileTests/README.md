# Profile Tests

C# xUnit tests that validate learner profile completeness.

## Run Tests

```powershell
cd .github/tests/ProfileTests
dotnet test
```

## What Gets Validated

- All required fields are non-empty
- Learning style has preferences, pace, and when-stuck behavior
- Personality has self-description and motivation
- Military background is complete (for real learners, not test profiles)
- Military fields are NOT "N/A" for actual MSSA learners
- Extracted concepts exist and map to code patterns
- Progress tracking has current track and project
- Session history is not empty
- Timestamps are valid ISO 8601

## Adding New Profiles

When you create a new learner profile, add it to the `[InlineData]` attribute:

```csharp
[Theory]
[InlineData("jasteenb.json")]
[InlineData("new_learner.json")]  // Add here
public void Profile_ShouldHaveAllRequiredFields(string profileFileName)
```

## Expected Failures

Test profiles (like Jay's, where `military.branch = "N/A"`) will show warnings but pass tests. Real MSSA learner profiles MUST have complete military backgrounds or tests will fail.
