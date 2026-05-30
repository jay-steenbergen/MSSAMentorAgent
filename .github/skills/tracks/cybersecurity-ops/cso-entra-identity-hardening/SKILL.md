---
name: cso-entra-identity-hardening
description: |
  CSO track project #2. Learner creates a named location in Entra, builds a Conditional Access
  policy requiring MFA for all admins, simulates a risky sign-in via the What-If tool, then
  uses KQL to hunt sign-in logs for failed MFA challenges and impossible-location patterns.
  Auto-load when the learner is in `cybersecurity-ops/cso-entra-identity-hardening` or asks
  to learn Conditional Access, MFA enforcement, named locations, sign-in risk policies, or
  hunting in `SigninLogs`.
---

# Project: `cso-entra-identity-hardening`

> **Track:** Cybersecurity Operations · **Project:** 2 of 9 · **Time:** ~75 minutes
>
> Identity is the new perimeter — and Conditional Access is how you defend it. By the end of this project the learner has created a named location, written a CA policy enforcing MFA on admin roles, validated the policy with the What-If tool, and used KQL to find sign-ins that bypass or fail MFA.

## Project goal

When this project is done, the learner can:

- Configure a **named location** in Entra (trusted office IPs vs untrusted everywhere-else).
- Create a **Conditional Access policy** that requires MFA when an admin role signs in.
- Use the **What-If tool** to test which policies would apply to a given sign-in without actually triggering them.
- Query `SigninLogs` in KQL to find failed sign-ins, MFA-failed sign-ins, and risky users.
- Explain the difference between **sign-in risk** and **user risk**, and what triggers each.

## Scope guardrail

This is **one named location, one CA policy, KQL hunts on sign-in logs**. We are not implementing the full Zero Trust suite, not configuring Authentication Strengths, not building Token Protection (preview), not deploying Entra Private Access. One policy that enforces MFA for admin roles — that's the most common "first CA policy" in the world.

If the learner asks "what about phishing-resistant MFA?" — answer honestly: *FIDO2 / passkeys are the right answer for high-value accounts; this project teaches the baseline policy mechanics so you can build on them later*.

## Prerequisites

| Prereq | Verify with |
|---|---|
| An Entra tenant where you're a **Conditional Access Administrator** or **Global Administrator** | portal.azure.com → Microsoft Entra ID → Roles and administrators |
| At least one test user account in the tenant (not your admin — you'll need to lock yourself out testing) | Entra → Users |
| Entra ID **P1 license** or trial assigned to the tenant | Required for Conditional Access |
| Optional: a Sentinel-connected workspace ingesting `SigninLogs` | Project #5 if not done yet; for now query the Entra Audit & Sign-in tabs directly |

**Critical safety note:** CA policies that misfire can lock administrators out of their own tenant. Always: (a) create a **break-glass account** exempt from all CA policies, (b) start every policy in **Report-only** mode for 24 hours, (c) only flip to **On** after What-If and Sign-in logs show no false positives.

## Phases

### Phase 1 — Create a break-glass account first (~10 min)

**Goal:** Before any CA work, the learner has an emergency-access account that no CA policy can touch.

**Steps in the Azure portal:**
1. **Microsoft Entra ID → Users → + New user → Create new user**.
2. User name: `breakglass-1@yourtenant.onmicrosoft.com`. Display name: `Break Glass 1`.
3. Password: copy & store offline in a password manager you can reach without the tenant (printed in a safe, separate password vault, etc.).
4. **Assignments → + Add assignments → Global Administrator** role.
5. Save.

**Decision:** Don't enable MFA on this account, don't enable any CA policy on it. The whole point is that it's reachable when everything else is locked.

**Concepts to name out loud:**
- *This is **a break-glass account*** — Microsoft's recommended pattern: 1-2 cloud-only Global Admin accounts that are excluded from ALL CA policies. They're heavily monitored (alerts on every sign-in) and used only when the regular admin accounts are locked out.
- *This is **why "lock yourself out testing" is a real story*** — every IT admin who's done CA has at least one war story of being locked out. The break-glass account is the seatbelt.

**After-action prompt:** *"You created a break-glass account. What three things would you monitor about it in production?"*

### Phase 2 — Named locations (~15 min)

**Goal:** A named location representing "trusted" IPs (your home IP for lab purposes) exists in Entra.

**Steps:**
1. **Microsoft Entra ID → Security → Conditional Access → Named locations → + IP ranges location**.
2. Name: `MSSA Lab Home`. Type: **IP ranges**.
3. Add IP range: `<your-public-ip>/32` (get it with `Invoke-RestMethod -Uri https://api.ipify.org` in PowerShell).
4. Check **Mark as trusted location**. Save.

**Optional: add a "Countries" named location** to use in policy exclusions:
1. **+ Countries location** → Name `Allowed Countries` → pick 1-2 countries you actually travel to or operate in.
2. Save.

**Concepts to name out loud:**
- *This is **a named location as a reusable identity*** — instead of writing the same IP range in every CA policy, name it once and reference by name.
- *This is **trusted vs untrusted named locations*** — "trusted" can be used as a positive condition (e.g. "skip MFA from trusted location"). Untrusted-by-default. Use trusted sparingly; an attacker who gets your VPN exit IP becomes "trusted."
- *This is **the gap in IP-based identity*** — IPs change, NATs are shared, mobile carriers rotate. Use named locations as a hint, not a security boundary.

**Common gotchas:**
- IP changed since you saved → policy "trusted" no longer matches. Mobile / home IPs aren't stable. Update or use a wider range.
- Forgot `/32` → IP without mask is sometimes interpreted as `/24`. Be explicit.

**After-action prompt:** *"You marked your home IP as trusted. List two ways an attacker could appear to come from that IP — and what controls would catch them anyway."*

### Phase 3 — Conditional Access policy: MFA for admins (~20 min)

**Goal:** A CA policy exists, in Report-only mode, that requires MFA when a user with an admin role signs in.

**Steps:**
1. **Microsoft Entra ID → Security → Conditional Access → + New policy**.
2. **Name:** `Require MFA for admin roles`.
3. **Assignments:**
   - **Users:** Select **Users and groups** → **Directory roles** → check `Global Administrator`, `Privileged Role Administrator`, `Security Administrator`, `User Administrator`, `Conditional Access Administrator`.
   - **Exclude:** Users and groups → select the break-glass account.
4. **Target resources:** All cloud apps.
5. **Conditions:** Leave defaults.
6. **Access controls → Grant:**
   - Select **Grant access** → check **Require multi-factor authentication**. Click Select.
7. **Enable policy:** **Report-only**.
8. Create.

**Important:** Report-only means the policy is evaluated and logged but **not enforced**. You'll see in sign-in logs whether it *would* have applied / required MFA. Move to On only after 24-48 hours of clean Report-only.

**Concepts to name out loud:**
- *This is **CA policies as if-this-then-that*** — conditions (who, where, what, when, how) AND access controls (grant/block, MFA, compliant device, etc.). Evaluate all matching policies; if ANY says block, blocked. If grant policies require additional controls (e.g. MFA), all must be satisfied.
- *This is **role-based targeting*** — including users by **directory role** means new users assigned that role automatically inherit the policy. More resilient than naming individual users.
- *This is **Report-only as the safety pattern*** — never enable a new CA policy in On mode without Report-only first. Especially for tenant-wide or role-based policies.

**Common gotchas:**
- Excluded the wrong account → break-glass user is included. Re-check the exclusion.
- Selected "All users" instead of "Directory roles" → the policy applies to everyone, including the break-glass. Very common new-admin mistake.

**After-action prompt:** *"You created the policy in Report-only. Walk me through what you'd check after 24 hours before flipping it to On."*

### Phase 4 — What-If tool (~10 min)

**Goal:** Use the What-If tool to confirm the policy targets admins (and doesn't accidentally hit normal users or the break-glass account).

**Steps:**
1. **Conditional Access → What If**.
2. **User or workload identity:** select one of your tenant Global Admins. **What If**.
3. Inspect the **Policies that will apply** section — the `Require MFA for admin roles` policy should be listed.
4. **Change user** to your break-glass account. Re-run. The policy should **NOT** apply.
5. **Change user** to a regular test user with no admin role. Policy should NOT apply.

**Concepts to name out loud:**
- *This is **What-If as the deployment safety net*** — simulates a sign-in scenario and shows which policies would apply, with what controls. Doesn't actually trigger anything.
- *This is **why testing all three scenarios matters*** — confirm the policy hits the admins, **doesn't hit the break-glass** (most critical), and doesn't accidentally hit regular users.

**Common gotchas:**
- What-If shows policy applies to break-glass → exclusion is wrong. Fix before enabling.
- What-If shows policy doesn't apply to an admin → role assignment is wrong, or the policy targeting is wrong. Investigate before enabling.

**After-action prompt:** *"What-If said the policy applies to your admin but not your break-glass. If a colleague asks 'how do I know this is actually true at sign-in time?' what would you show them?"*

### Phase 5 — KQL hunt on sign-in logs (~20 min)

**Goal:** The learner writes 4 KQL queries against `SigninLogs` (in the demo workspace from project #1, or in their own Sentinel workspace if available).

**Q1 — Failed MFA challenges in the last 7 days:**
```kql
SigninLogs
| where TimeGenerated > ago(7d)
| where ResultType == 50074   // Strong auth required
   or ResultType == 50076   // MFA failed
   or ResultType == 500121  // MFA denied
| project TimeGenerated, UserPrincipalName, IPAddress, Location, AppDisplayName, ResultType, ResultDescription
| order by TimeGenerated desc
| take 50
```

**Q2 — Users signing in from more than 3 distinct countries in 24 hours (a textbook impossible-travel signal):**
```kql
SigninLogs
| where TimeGenerated > ago(1d)
| where ResultType == 0   // Success
| summarize countries=dcount(Location), country_list=make_set(Location) by UserPrincipalName
| where countries > 3
| order by countries desc
```

**Q3 — Risky sign-ins reported by Entra Identity Protection:**
```kql
SigninLogs
| where TimeGenerated > ago(7d)
| where RiskLevelDuringSignIn in ("medium", "high")
| project TimeGenerated, UserPrincipalName, IPAddress, Location, RiskLevelDuringSignIn, RiskDetail, AppDisplayName
| order by TimeGenerated desc
| take 20
```

**Q4 — Bulk failures from a single IP (brute force signal):**
```kql
SigninLogs
| where TimeGenerated > ago(1h)
| where ResultType != 0
| summarize failures=count(), distinct_users=dcount(UserPrincipalName), users=make_set(UserPrincipalName, 10) by IPAddress
| where failures > 50 and distinct_users > 5
| order by failures desc
```

**Concepts to name out loud:**
- *This is **`SigninLogs` as the auth event table*** — every authentication attempt that hits Entra lands here. Available in tenants with P1+ license (or via Sentinel data connector — project #5).
- *This is **`ResultType` as the success/failure code*** — `0` = success, anything else = failure with a numeric reason. Top codes: `50053` (account locked), `50074` (MFA required but not used), `50126` (wrong password). Memorize the top 10 if you want to investigate fast.
- *This is **sign-in risk vs user risk*** — sign-in risk is "this individual sign-in looks fishy" (impossible travel, anonymous IP, leaked credentials). User risk is "this user has accumulated enough risky activity that they're compromised." Two different policies fire on each.
- *This is **`make_set(col, max)`*** — `make_set` collects distinct values into a list; the `max` arg caps how many to keep. Useful for "show me the actual values, not just a count."

**Common gotchas:**
- Demo workspace doesn't have `SigninLogs` → it might. If not, you'll see "Failed to resolve table." The queries still work conceptually; sign-in logs require Entra P1+ to land in any workspace.
- ResultType code lookup → docs have the full list; memorize the top 10 (`0`, `50074`, `50076`, `50126`, `50053`, `500121`, `53003`, `50105`, `50140`, `50158`).

**After-action prompt:** *"You wrote 4 hunting queries. If a SOC analyst asked for 'the one query I should run every morning for 60 seconds,' which of yours would you give them and why?"*

## When to break the method

- Learner doesn't have an Entra P1 license / trial → still do phases 1-4 in the portal (named locations, CA policies, What-If all work without P1; only the *risk-based* features need P2). Use the demo workspace from project #1 for the KQL hunts.
- Learner is already a working IT admin with CA experience → skip phase 1-3, focus on phase 5 (the hunting queries are where most working admins lack depth).
- Time short → phases 1-3 are non-negotiable (break-glass, named location, MFA-for-admins policy). Phases 4-5 can be follow-up.

## Definition of done

Observable, the learner can:

- [ ] Show a break-glass account in Entra excluded from CA policies.
- [ ] Show the `Require MFA for admin roles` CA policy in Report-only mode.
- [ ] Use What-If to demonstrate the policy applies to admins and not to the break-glass or normal users.
- [ ] Run at least 2 of the 4 KQL queries against `SigninLogs` and explain the output.
- [ ] Explain in one sentence each: named location, Conditional Access, Report-only, sign-in risk vs user risk.

## Next project

→ [`cso-defender-endpoint-onboard`](../cso-defender-endpoint-onboard/SKILL.md) — extend the lab from identity to endpoint: onboard a Windows VM to Microsoft Defender for Endpoint, run a built-in attack simulation, and inspect the resulting alert.
