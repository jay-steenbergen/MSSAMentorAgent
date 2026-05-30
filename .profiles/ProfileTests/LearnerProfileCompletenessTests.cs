using System;
using System.Collections.Generic;
using System.IO;
using System.Text.Json;
using System.Text.Json.Serialization;
using Xunit;

namespace MSSAMentorAgent.Tests;

public class LearnerProfileCompletenessTests
{
    // Path relative to test DLL location (bin/Debug/net8.0)
    // Works regardless of where 'dotnet test' is invoked from
    private static readonly string MenteesDirectory = Path.Combine(
        AppContext.BaseDirectory,
        "../../../../profiles/mentees"
    );
    
    private static readonly string MentorsDirectory = Path.Combine(
        AppContext.BaseDirectory,
        "../../../../profiles/mentors"
    );

    [Theory]
    [InlineData("jasteenb.json", true)]  // true = mentor (test profile)
    public void Profile_ShouldHaveAllRequiredFields(string profileFileName, bool isMentor = false)
    {
        // Arrange
        var directory = isMentor ? MentorsDirectory : MenteesDirectory;
        var profilePath = Path.Combine(directory, profileFileName);
        var json = File.ReadAllText(profilePath);
        var profile = JsonSerializer.Deserialize<LearnerProfile>(json);

        // Assert
        Assert.NotNull(profile);
        Assert.False(string.IsNullOrWhiteSpace(profile.Name), "Name is required");
        Assert.False(string.IsNullOrWhiteSpace(profile.PreferredName), "PreferredName is required");
        Assert.False(string.IsNullOrWhiteSpace(profile.GithubUsername), "GithubUsername is required");
        Assert.NotNull(profile.LearningStyle);
        Assert.NotNull(profile.Personality);
        Assert.NotNull(profile.Military);
        Assert.NotNull(profile.Progress);
        Assert.NotNull(profile.SessionHistory);
    }

    [Theory]
    [InlineData("jasteenb.json", true)]  // true = mentor (test profile)
    public void Profile_LearningStyle_ShouldBeComplete(string profileFileName, bool isMentor = false)
    {
        // Arrange
        var directory = isMentor ? MentorsDirectory : MenteesDirectory;
        var profilePath = Path.Combine(directory, profileFileName);
        var json = File.ReadAllText(profilePath);
        var profile = JsonSerializer.Deserialize<LearnerProfile>(json);

        // Assert
        Assert.NotNull(profile?.LearningStyle);
        Assert.NotNull(profile.LearningStyle.Prefers);
        Assert.NotEmpty(profile.LearningStyle.Prefers);
        Assert.False(string.IsNullOrWhiteSpace(profile.LearningStyle.PacePreference), "PacePreference is required");
        Assert.False(string.IsNullOrWhiteSpace(profile.LearningStyle.WhenStuck), "WhenStuck is required");
    }

    [Theory]
    [InlineData("jasteenb.json", true)]  // true = mentor (test profile)
    public void Profile_Personality_ShouldBeComplete(string profileFileName, bool isMentor = false)
    {
        // Arrange
        var directory = isMentor ? MentorsDirectory : MenteesDirectory;
        var profilePath = Path.Combine(directory, profileFileName);
        var json = File.ReadAllText(profilePath);
        var profile = JsonSerializer.Deserialize<LearnerProfile>(json);

        // Assert
        Assert.NotNull(profile?.Personality);
        Assert.False(string.IsNullOrWhiteSpace(profile.Personality.SelfDescription), "SelfDescription is required");
        Assert.False(string.IsNullOrWhiteSpace(profile.Personality.Motivation), "Motivation is required");
    }

    [Theory]
    [InlineData("jasteenb.json", true)]  // true = mentor (test profile)
    [InlineData("test_incomplete.json", false)]  // false = mentee (test validation failure)
    public void Profile_Military_ShouldBeComplete(string profileFileName, bool isMentor = false)
    {
        // Arrange
        var directory = isMentor ? MentorsDirectory : MenteesDirectory;
        var profilePath = Path.Combine(directory, profileFileName);
        var json = File.ReadAllText(profilePath);
        var profile = JsonSerializer.Deserialize<LearnerProfile>(json);

        // Assert
        Assert.NotNull(profile?.Military);
        
        // NO field should contain "N/A" - reject it everywhere
        Assert.False(string.Equals(profile.Military.Branch, "N/A", StringComparison.OrdinalIgnoreCase), 
            "Branch should not be N/A - use 'Civilian' for non-military");
        Assert.False(string.Equals(profile.Military.Rank, "N/A", StringComparison.OrdinalIgnoreCase), 
            "Rank should not be N/A - use empty string for civilians");
        Assert.False(string.Equals(profile.Military.MOS, "N/A", StringComparison.OrdinalIgnoreCase), 
            "MOS should not be N/A - use empty string for civilians");
        Assert.False(string.Equals(profile.Military.MOSTitle, "N/A", StringComparison.OrdinalIgnoreCase), 
            "MOS Title should not be N/A - use empty string for civilians");
        
        // Branch determines whether military or civilian
        var branch = profile.Military.Branch;
        bool isCivilian = string.IsNullOrWhiteSpace(branch) || 
                          string.Equals(branch, "Civilian", StringComparison.OrdinalIgnoreCase) ||
                          string.Equals(branch, "None", StringComparison.OrdinalIgnoreCase);
        
        if (!isCivilian)
        {
            // Military service - all fields must be filled
            Assert.False(string.IsNullOrWhiteSpace(profile.Military.Rank), "Rank is required for military service");
            Assert.False(string.IsNullOrWhiteSpace(profile.Military.MOS), "MOS is required for military service");
            Assert.False(string.IsNullOrWhiteSpace(profile.Military.MOSTitle), "MOS Title is required for military service");
            Assert.True(profile.Military.YearsOfService > 0, "Years of service must be > 0 for military");
        }
        
        // Job description, concepts, and translations are required for EVERYONE (military or civilian)
        Assert.False(string.IsNullOrWhiteSpace(profile.Military.JobDescription), 
            "JobDescription is required (military responsibilities or civilian professional background)");
        
        Assert.NotNull(profile.Military.ExtractedConcepts);
        Assert.NotEmpty(profile.Military.ExtractedConcepts);
        Assert.True(profile.Military.ExtractedConcepts.Length >= 3, 
            "Should have at least 3 extracted concepts from work experience");
        
        Assert.NotNull(profile.Military.TranslationToCode);
        Assert.NotEmpty(profile.Military.TranslationToCode);
    }

    [Theory]
    [InlineData("jasteenb.json", true)]  // true = mentor (test profile)
    public void Profile_Military_ExtractedConcepts_ShouldNotBeEmpty(string profileFileName, bool isMentor = false)
    {
        // Arrange
        var directory = isMentor ? MentorsDirectory : MenteesDirectory;
        var profilePath = Path.Combine(directory, profileFileName);
        var json = File.ReadAllText(profilePath);
        var profile = JsonSerializer.Deserialize<LearnerProfile>(json);

        // Assert
        Assert.NotNull(profile?.Military?.ExtractedConcepts);
        Assert.NotEmpty(profile.Military.ExtractedConcepts);
    }

    [Theory]
    [InlineData("jasteenb.json", true)]  // true = mentor (test profile)
    public void Profile_Military_TranslationToCode_ShouldNotBeEmpty(string profileFileName, bool isMentor = false)
    {
        // Arrange
        var directory = isMentor ? MentorsDirectory : MenteesDirectory;
        var profilePath = Path.Combine(directory, profileFileName);
        var json = File.ReadAllText(profilePath);
        var profile = JsonSerializer.Deserialize<LearnerProfile>(json);

        // Assert
        Assert.NotNull(profile?.Military?.TranslationToCode);
        Assert.NotEmpty(profile.Military.TranslationToCode);
    }

    [Theory]
    [InlineData("jasteenb.json", true)]  // true = mentor (test profile)
    public void Profile_Progress_ShouldBeValid(string profileFileName, bool isMentor = false)
    {
        // Arrange
        var directory = isMentor ? MentorsDirectory : MenteesDirectory;
        var profilePath = Path.Combine(directory, profileFileName);
        var json = File.ReadAllText(profilePath);
        var profile = JsonSerializer.Deserialize<LearnerProfile>(json);

        // Assert
        Assert.NotNull(profile?.Progress);
        Assert.False(string.IsNullOrWhiteSpace(profile.Progress.CurrentTrack), "CurrentTrack is required");
        Assert.False(string.IsNullOrWhiteSpace(profile.Progress.CurrentProject), "CurrentProject is required");
        Assert.NotNull(profile.Progress.CompletedMilestones);
    }

    [Theory]
    [InlineData("jasteenb.json", true)]  // true = mentor (test profile)
    public void Profile_SessionHistory_ShouldNotBeEmpty(string profileFileName, bool isMentor = false)
    {
        // Arrange
        var directory = isMentor ? MentorsDirectory : MenteesDirectory;
        var profilePath = Path.Combine(directory, profileFileName);
        var json = File.ReadAllText(profilePath);
        var profile = JsonSerializer.Deserialize<LearnerProfile>(json);

        // Assert
        Assert.NotNull(profile?.SessionHistory);
        Assert.NotEmpty(profile.SessionHistory);
    }

    [Theory]
    [InlineData("jasteenb.json", true)]  // true = mentor (test profile)
    public void Profile_Timestamps_ShouldBeValidISO8601(string profileFileName, bool isMentor = false)
    {
        // Arrange
        var directory = isMentor ? MentorsDirectory : MenteesDirectory;
        var profilePath = Path.Combine(directory, profileFileName);
        var json = File.ReadAllText(profilePath);
        var profile = JsonSerializer.Deserialize<LearnerProfile>(json);

        // Assert
        Assert.NotNull(profile);
        Assert.False(string.IsNullOrWhiteSpace(profile.Created), "Created timestamp is required");
        Assert.False(string.IsNullOrWhiteSpace(profile.LastUpdated), "LastUpdated timestamp is required");
        
        // Verify they're valid DateTimes
        Assert.True(DateTime.TryParse(profile.Created, out _), "Created should be valid ISO 8601 timestamp");
        Assert.True(DateTime.TryParse(profile.LastUpdated, out _), "LastUpdated should be valid ISO 8601 timestamp");
        
        if (profile.Progress?.StartedAt != null)
        {
            Assert.True(DateTime.TryParse(profile.Progress.StartedAt, out _), 
                "StartedAt should be valid ISO 8601 timestamp");
        }
    }
}

public class LearnerProfile
{
    [JsonPropertyName("name")]
    public string Name { get; set; } = string.Empty;
    
    [JsonPropertyName("preferred_name")]
    public string PreferredName { get; set; } = string.Empty;
    
    [JsonPropertyName("github_username")]
    public string GithubUsername { get; set; } = string.Empty;
    
    [JsonPropertyName("created")]
    public string Created { get; set; } = string.Empty;
    
    [JsonPropertyName("last_updated")]
    public string LastUpdated { get; set; } = string.Empty;
    
    [JsonPropertyName("learning_style")]
    public LearningStyleInfo LearningStyle { get; set; } = new();
    
    [JsonPropertyName("personality")]
    public PersonalityInfo Personality { get; set; } = new();
    
    [JsonPropertyName("military")]
    public MilitaryInfo Military { get; set; } = new();
    
    [JsonPropertyName("progress")]
    public ProgressInfo Progress { get; set; } = new();
    
    [JsonPropertyName("session_history")]
    public SessionHistoryEntry[] SessionHistory { get; set; } = Array.Empty<SessionHistoryEntry>();
}

public class LearningStyleInfo
{
    [JsonPropertyName("prefers")]
    public string[] Prefers { get; set; } = Array.Empty<string>();
    
    [JsonPropertyName("pace_preference")]
    public string PacePreference { get; set; } = string.Empty;
    
    [JsonPropertyName("when_stuck")]
    public string WhenStuck { get; set; } = string.Empty;
    
    [JsonPropertyName("notes")]
    public string? Notes { get; set; }
}

public class PersonalityInfo
{
    [JsonPropertyName("self_description")]
    public string SelfDescription { get; set; } = string.Empty;
    
    [JsonPropertyName("motivation")]
    public string Motivation { get; set; } = string.Empty;
    
    [JsonPropertyName("notes")]
    public string? Notes { get; set; }
}

public class MilitaryInfo
{
    [JsonPropertyName("branch")]
    public string Branch { get; set; } = string.Empty;
    
    [JsonPropertyName("rank")]
    public string? Rank { get; set; }
    
    [JsonPropertyName("mos")]
    public string? MOS { get; set; }
    
    [JsonPropertyName("mos_title")]
    public string? MOSTitle { get; set; }
    
    [JsonPropertyName("years_of_service")]
    public int YearsOfService { get; set; }
    
    [JsonPropertyName("job_description")]
    public string JobDescription { get; set; } = string.Empty;
    
    [JsonPropertyName("extracted_concepts")]
    public string[] ExtractedConcepts { get; set; } = Array.Empty<string>();
    
    [JsonPropertyName("translation_to_code")]
    public Dictionary<string, string> TranslationToCode { get; set; } = new();
}

public class ProgressInfo
{
    [JsonPropertyName("current_track")]
    public string CurrentTrack { get; set; } = string.Empty;
    
    [JsonPropertyName("current_project")]
    public string CurrentProject { get; set; } = string.Empty;
    
    [JsonPropertyName("current_step")]
    public int CurrentStep { get; set; }
    
    [JsonPropertyName("completed_milestones")]
    public string[] CompletedMilestones { get; set; } = Array.Empty<string>();
    
    [JsonPropertyName("started_at")]
    public string? StartedAt { get; set; }
}

public class SessionHistoryEntry
{
    [JsonPropertyName("date")]
    public string Date { get; set; } = string.Empty;
    
    [JsonPropertyName("duration_minutes")]
    public int DurationMinutes { get; set; }
    
    [JsonPropertyName("milestones_completed")]
    public string[] MilestonesCompleted { get; set; } = Array.Empty<string>();
    
    [JsonPropertyName("notes")]
    public string? Notes { get; set; }
}
