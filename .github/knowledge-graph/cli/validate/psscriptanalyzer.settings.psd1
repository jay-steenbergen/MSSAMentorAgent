@{
    # PSScriptAnalyzer settings for this repo.
    #
    # Severity: only Error and Warning by default.
    # Information rules are too noisy for this code base.
    Severity = @('Error', 'Warning')

    # Rules to skip — each entry justified.
    ExcludeRules = @(
        # Write-Host is the correct tool in our CLI hooks and inspect scripts.
        # We deliberately write to host for human-readable terminal output.
        'PSAvoidUsingWriteHost'

        # We use ASCII art and colored prompts in pre-commit. Style preference,
        # not a correctness rule.
        'PSAvoidUsingPositionalParameters'

        # We have several pwsh.exe -NoProfile invocations from PowerShell which
        # this rule incorrectly flags as Linux-incompatible. We run on Windows.
        'PSUseShouldProcessForStateChangingFunctions'

        # The repo uses Pascal-cased CmdletBinding params consistently. This
        # rule fights non-trivial intentional choices like $Quiet, $UpdateBaseline.
        'PSReviewUnusedParameter'
    )

    # Rules we explicitly include even if they are Information-severity.
    IncludeRules = @(
        # Catches `$x -eq $null` (wrong) vs `$null -eq $x` (right). The wrong
        # form silently fails on arrays. Adjacent to the strict-mode .Count
        # trap that bit us 2026-06-04.
        'PSPossibleIncorrectComparisonWithNull'

        # Catches `$null -eq $x` etc. — companion to the above.
        'PSAvoidNullOrEmptyHelpMessageAttribute'

        # Catches uninitialized variables used in conditional branches —
        # strict-mode lights these up at runtime; PSSA catches at lint time.
        'PSUseDeclaredVarsMoreThanAssignments'

        # Catches `if ($x.Length -eq 0)` on possibly-null. Adjacent class to
        # today's .Count bug.
        'PSPossibleIncorrectUsageOfRedirectionOperator'
    )
}
