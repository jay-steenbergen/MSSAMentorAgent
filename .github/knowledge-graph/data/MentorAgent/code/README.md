# Code Graph — Source Map

Structured map of the actual SOURCE behind every concept in the system graph: files, functions, parameters, calls, JSON schemas/fields, tests, references between them.

Companion: [`../system/`](../system/) maps the CONCEPTS this code implements. [`../merge.ps1`](../merge.ps1) joins them.

---

## Status: skeleton only

`code-graph.json` is currently a scaffold with metadata, cluster definitions, and node-type taxonomy — but `nodes` and `edges` arrays are empty. **Phase B will populate it** by walking the repo.

---

## Planned scope (Phase B)

Every file in the repo becomes a node, plus what's inside it:

| File type | Top-level node | Child nodes extracted |
|---|---|---|
| `.ps1` PowerShell | `code-file` | `code-func`, `code-param`, `code-call`, `code-import` |
| `.json` schemas + instances | `code-file` + `code-schema` | `code-field` (recursive), `code-enum-value` |
| `.md` SKILL.md / agent.md / docs | `code-file` | `code-section`, `code-codeblock` |
| `.test.md` behavioral tests | `code-test` | `code-scenario`, `code-assertion` |
| `.cs` xUnit tests | `code-file` | `code-func`, `code-assertion` |

---

## Planned node types

| Type | Represents | Example ID |
|---|---|---|
| `code-file` | Any tracked file | `code-file:.github/agents/Mentor.agent.md` |
| `code-func` | Function inside a script | `code-func:.profiles/validate-profile.ps1::Test-Profile` |
| `code-param` | Parameter of a function | `code-param:.profiles/validate-profile.ps1::Test-Profile::Username` |
| `code-call` | A function call (edge target) | `code-call:.profiles/validate-profile.ps1::Test-Path` |
| `code-schema` | A JSON schema or instance shape | `code-schema:.profiles/profiles/mentees/alex/profile.json` |
| `code-field` | A key inside a JSON object | `code-field:profile.json::military.branch` |
| `code-enum-value` | A literal value in an enum | `code-enum-value:profile.json::pace_preference::fast` |
| `code-section` | A markdown `##` heading section | `code-section:Mentor.agent.md::How you behave` |
| `code-codeblock` | A fenced code block | `code-codeblock:learner-profile/SKILL.md::block-3` |
| `code-test` | A `.test.md` scenario | `code-test:.github/tests/session-flow.test.md` |
| `code-scenario` | Named scenario within a test | `code-scenario:session-flow::first-time-user` |
| `code-assertion` | Expected behavior line | `code-assertion:session-flow::asks-name` |
| `code-import` | Module / dot-source / reference | `code-import:audit.ps1::ConvertFrom-Json` |

---

## Planned edge types

| Type | Meaning |
|---|---|
| `contains` | File → function, function → param, schema → field |
| `calls` | Function → function (across files) |
| `imports` | File → file/module |
| `references` | Doc cites a file/function/field |
| `validates` | Script function → schema/field it validates |
| `instance_of` | JSON instance → its schema |
| `tests` | Test scenario → file/function/skill it exercises |
| `asserts` | Scenario → assertion |
| `defined_in` | Symbol → containing file |
| `reads` / `writes` | Function → field it reads or writes |
| `has_section` | File → section, section → subsection |

---

## Cross-graph bridges (Phase B)

The code graph will declare `bridges` in metadata mapping system IDs to code IDs:

```json
{
  "bridges": [
    { "system": "script:validate-profile-ps1", "code": "code-file:.profiles/validate-profile.ps1" },
    { "system": "skill:learner-profile",       "code": "code-file:.github/skills/learner-profile/SKILL.md" },
    { "system": "agent:mentor",                "code": "code-file:.github/agents/Mentor.agent.md" }
  ]
}
```

`merge.ps1` resolves each bridge into an `implemented_by` edge in the merged graph. After that, the system question "what protocol does this skill follow?" and the code question "what test covers this function?" answer from the same graph.

---

## Why this is useful

The system graph already tells you "the agent follows 10 behavioral rules" and "rule X is duplicated in 3 places." But it doesn't tell you which exact lines, which functions reference them, or which tests fail if the rule is broken.

The code graph closes that loop:
- **Refactor safely** — change a function signature, see every caller across `.ps1` and `.cs`
- **Find dead code** — functions with zero incoming `calls` edges
- **Coverage gap detection** — `code-func` nodes with no incoming `tests` edge
- **JSON schema drift** — instance files where fields don't match the schema
- **Documentation drift** — `code-section` nodes whose body hasn't been updated since referenced files changed

---

## When to (re)populate

Phase B will likely include a `extract.ps1` script that:
1. Walks the repo
2. Parses each file by type
3. Emits the code graph
4. Optionally diffs against the previous graph and reports drift

Until that lands, this graph stays as a typed skeleton.
