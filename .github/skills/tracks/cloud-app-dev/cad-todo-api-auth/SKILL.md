---
name: cad-todo-api-auth
description: Build progression that adds JWT authentication and per-user authorization to the TODO API from cad-todo-api-ef. Use when the learner wants to learn authentication vs authorization, JWT tokens, claims, [Authorize] filters, or user-scoped data hands-on. Pairs with the ride-along method.
---

# Skill: cad-todo-api-auth

The learner takes the persistent TODO API from `cad-todo-api-ef` and adds a login system. By the end, anonymous requests get **401 Unauthorized**, logged-in users can only see *their own* TODOs, and the learner can explain — in their own words — the difference between *authentication* (who you are) and *authorization* (what you're allowed to do).

This is project #5 in the [CAD track](../README.md). It is a **build recipe**, not a lecture. The mentor uses it to know what to build and which concepts to surface; *how* to teach those concepts lives in [`methods/ride-along`](../../../methods/ride-along/SKILL.md).

## Project goal

A working JWT-secured API with two users. Endpoints:

- `POST /auth/login` (anonymous) → exchanges username+password for a JWT
- `GET /todos`, `POST /todos`, etc. (authenticated) → each user only sees their own TODOs

The learner ends with `curl` requests that show 401 without a token, 200 with one, and a database where every TODO row has an `OwnerId` column.

> **Scope guardrail.** This project teaches the *shape* of JWT auth in ASP.NET Core, not a production identity system. We hardcode two users with plain-text passwords in `appsettings.json` so the learner can focus on tokens, claims, and `[Authorize]`. A real system uses ASP.NET Core Identity, hashed passwords, refresh tokens, and an identity provider (Entra ID, Auth0, etc.) — name those out loud so the learner knows what they're *not* doing here.

## Prerequisites

| Need | Why |
|---|---|
| `cad-todo-api-ef` complete OR equivalent | This project modifies that one. There must be a working EF-backed API to secure. |
| .NET 8 SDK installed | `dotnet --version` returns 8.x |
| Comfort with HTTP headers | We'll send `Authorization: Bearer <token>`. If the learner has never set a request header in `curl` or Swagger UI, do a 2-minute warm-up first. |
| Comfort with `appsettings.json` | We'll store the JWT signing key there. If learner has never opened `appsettings.json`, name it now — it's the standard ASP.NET Core config file. |

If the learner has not done `cad-todo-api-ef` — stop. This project modifies that one.

## Phases

Each phase ends with a working build the learner can run. After every phase, run a brief **after-action review** per the ride-along method.

### Phase 1 — Add JWT packages and configure authentication (~25 min)

**Goal:** Learner installs `Microsoft.AspNetCore.Authentication.JwtBearer`, adds a `Jwt` section to `appsettings.json` (issuer, audience, signing key), and registers JWT bearer auth in `Program.cs` with full token validation. App still runs and behaves exactly as before — no endpoint is protected yet.

**Files touched:**
- `<project>.csproj` (NuGet package added)
- `appsettings.json` — new `Jwt` section with `Issuer`, `Audience`, `Key` (32+ char string for dev)
- `Program.cs` — `AddAuthentication(...).AddJwtBearer(...)` with `TokenValidationParameters`, plus `AddAuthorization()`, plus `app.UseAuthentication()` / `app.UseAuthorization()` **in that order, before `MapControllers()`**

**Commands the learner runs:**
```
dotnet add package Microsoft.AspNetCore.Authentication.JwtBearer
```

**The Program.cs shape (services side):**
```csharp
var jwt = builder.Configuration.GetSection("Jwt");

// Keep "sub" as "sub" instead of letting .NET rewrite it to the long ClaimTypes.NameIdentifier URI.
JwtSecurityTokenHandler.DefaultInboundClaimTypeMap.Clear();

builder.Services
    .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true,
            ValidIssuer = jwt["Issuer"],
            ValidAudience = jwt["Audience"],
            IssuerSigningKey = new SymmetricSecurityKey(
                Encoding.UTF8.GetBytes(jwt["Key"]!))
        };
    });
builder.Services.AddAuthorization();
```
And in the middleware pipeline, **before** `app.MapControllers()`:
```csharp
app.UseAuthentication();
app.UseAuthorization();
```

**Concepts to name out loud:**
- *This is authentication vs authorization* — write these two words on whatever's at hand. Authentication = *"who are you?"* (proving identity). Authorization = *"are you allowed to do this?"* (checking permissions). The order matters: authenticate first, then authorize. ASP.NET Core has separate middleware for each, and they have to run in that order. Half of all auth bugs come from confusing the two — name the difference now and it'll save hours later.
- *This is JWT* — JSON Web Token. A signed string with three dot-separated parts: header, payload, signature. The payload contains **claims** (`sub` = subject/user, `exp` = expiry, etc.). The signature proves the server issued it. Anyone can *read* a JWT — it's not encrypted, just signed. Open [jwt.io](https://jwt.io) and paste a sample token together so the learner *sees* the structure.
- *This is the signing key* — a shared secret the server uses to sign tokens and to verify incoming ones. In dev, it lives in `appsettings.json`. In production, it lives in a secret store (Azure Key Vault, environment variables) — *never* in source control. Name this now; it pays off in `cad-deploy-app-service`.
- *This is `TokenValidationParameters`* — the contract that says *what counts as a valid token*: right issuer, right audience, not expired, signed with the key we know. Without it, `AddJwtBearer(...)` falls back to defaults and the learner gets either silent pass-through or confusing 401s on perfectly good tokens. This block IS the meat of Phase 1 — every line is a guard.
- *This is claim mapping* — by default, .NET 8's `JwtBearer` rewrites short claim names like `sub` into long XML URIs (e.g. `http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier`). The `DefaultInboundClaimTypeMap.Clear()` line turns that off so what we put in the token (`sub`) is what we read back. Without this, Phase 4 will hit a confusing claim-not-found bug. Name it now; it stays simple later.
- *This is middleware order* — `UseAuthentication` *must* come before `UseAuthorization`, and both must come before `MapControllers`. ASP.NET Core middleware runs in registration order; if you flip them, requests will reach controllers before tokens are validated. Order isn't preference; it's correctness.
- *This is HTTPS and bearer tokens* — a bearer token is a credential anyone holding can use. Over plain HTTP, anyone on the network reads it. Dev runs over both `http://` and `https://`; production must be HTTPS only. Two-sentence aside now, pays off in `cad-deploy-app-service`.

**Common gotchas:**
- Signing key shorter than 32 characters — JWT bearer middleware throws a confusing crypto error. The HS256 algorithm requires a 256-bit (32-byte) key minimum. Have the learner count characters.
- `appsettings.json` JSON syntax — trailing commas and missing quotes break the whole config silently. App may start with defaults and you'll wonder why auth isn't working.
- Middleware in the wrong order — no error at startup, just broken behavior. Symptom: `[Authorize]` endpoints return 200 to anonymous calls because the auth middleware never ran.

**After-action prompt:** *"In one sentence each: what is authentication, what is authorization, what is a JWT? Why does the middleware order matter — what happens if you flip `UseAuthentication` and `UseAuthorization`?"*

### Phase 2 — Add a login endpoint that issues tokens (~25 min)

**Goal:** New `AuthController` with `POST /auth/login`. Hardcoded users in `appsettings.json`. On valid credentials, return a JWT with the user's id as the `sub` claim. On invalid, return 401.

**Files touched:**
- `appsettings.json` — add a `Users` section (array of `{Username, Password, Id}` for two test users)
- `Controllers/AuthController.cs` (new) — `POST /auth/login` accepts `{username, password}`, validates against config, builds a JWT, returns `{token, expiresAt}`
- (Optional helper) `Services/JwtTokenService.cs` — wraps token creation so the controller stays thin

**Concepts to name out loud:**
- *This is a claim* — a key-value pair inside the JWT payload that asserts something about the user. `sub` (subject) is the conventional name for the user id. We can add custom claims too (`role`, `email`, etc.). Claims are how the server tells *future requests* who you are without looking the user up again.
- *This is token expiry* — set `exp` (we'll use 1 hour). Short expiry limits damage if a token is stolen. Production systems pair short-lived access tokens with refresh tokens — name that pattern, but don't build it.
- *This is `[AllowAnonymous]`* — even when global auth is on, the login endpoint must be reachable without a token (otherwise how do you log in?). The `[AllowAnonymous]` attribute is the escape hatch. Name it when you write it.
- *This is `IConfiguration`* — ASP.NET Core's config abstraction. Inject it via DI to read `appsettings.json` sections. We've seen DI for `TodoStore` (singleton), `TodoDbContext` (scoped), and now `IConfiguration` (singleton). Third time naming DI — pure recognition.

**Common gotchas:**
- Plain-text passwords being compared with `==` — works for two test users, would be catastrophic in production. Say this out loud as you write it. *"This is wrong on purpose, here's what right looks like (BCrypt/Argon2 hashing), we'll see it if you take the ASP.NET Core Identity path later."*
- Returning the token as a raw string vs an object — return `{token: "...", expiresAt: "..."}`. Clients need the expiry to know when to refresh.
- Forgetting `[AllowAnonymous]` once Phase 3 turns auth on globally — login endpoint will return 401, which makes login impossible. Loop trap.

**After-action prompt:** *"What's inside the token you just got back? Paste it into jwt.io. What claims do you see? What's signed? What's not encrypted?"*

### Phase 3 — Protect the TODO endpoints with `[Authorize]` (~20 min)

**Goal:** Add `[Authorize]` to `TodosController`. Confirm anonymous requests now get 401. Confirm requests with `Authorization: Bearer <token>` get through.

**Files touched:** `Controllers/TodosController.cs` (one attribute on the class).

**Concepts to name out loud:**
- *This is `[Authorize]`* — an authorization filter. Apply at the controller level (protects every action) or per-action. Without an argument, it just means *"the user must be authenticated."* With arguments (`[Authorize(Roles = "Admin")]`, `[Authorize(Policy = "...")]`), it gets more specific.
- *This is the `Authorization` header* — the standard place HTTP clients send credentials. Format: `Authorization: Bearer <jwt>`. In Swagger UI, the **Authorize** button (lock icon) lets you set it once for all requests.
- *This is 401 vs 403* — **401 Unauthorized** = *"I don't know who you are"* (no token, bad token, expired token). **403 Forbidden** = *"I know who you are, but you can't do this"* (wrong role, wrong permission). Most learners conflate these; name the distinction explicitly.

**Common gotchas:**
- Forgetting to send the token in subsequent requests — Swagger UI's **Authorize** button is sticky for the session; `curl` is not. Show both.
- Token expired since the login request — refresh by hitting `POST /auth/login` again. If the learner is confused by intermittent 401s, expiry is usually why.
- `[Authorize]` on `AuthController` by accident — locks the learner out of their own login endpoint. The `[AllowAnonymous]` from Phase 2 is what prevents this.

**After-action prompt:** *"Hit `GET /todos` three times: once with no token, once with a valid token, once with the token with one character changed. What status code did you get each time? Why?"*

### Phase 4 — Scope TODOs to the logged-in user (~30 min)

**Goal:** Each user only sees their own TODOs. Add `OwnerId` to the `Todo` model, generate and apply a migration, read the user id from the JWT in the controller, filter `GET` queries by `OwnerId`, set `OwnerId` on `POST`.

**Files touched:**
- `Models/Todo.cs` — add `public string OwnerId { get; set; } = "";`
- `Migrations/` — new migration appears after `dotnet ef migrations add AddOwnerId`
- `Controllers/TodosController.cs` — read `User.FindFirstValue(ClaimTypes.NameIdentifier)` (or `"sub"`) in each method, filter/assign accordingly

**Commands the learner runs:**
```
dotnet ef migrations add AddOwnerId
dotnet ef database update
```

**Concepts to name out loud:**
- *This is `ClaimsPrincipal`* — `HttpContext.User` (or just `User` in a controller) is a `ClaimsPrincipal` populated by the auth middleware after it validates the token. The user's claims from the JWT are now available via `User.FindFirstValue(...)`. This is how server code "knows who you are" on every request.
- *This is data scoping* — the most common authorization pattern after `[Authorize]`. The endpoint is permitted; the *data the endpoint returns* is filtered to what the caller owns. `_db.Todos.Where(t => t.OwnerId == currentUserId).ToListAsync()`. Name this as a pattern — it shows up in *every* real multi-user app.
- *This is the difference between `[Authorize]` and data scoping* — `[Authorize]` says *"you must be logged in to call this endpoint."* Data scoping says *"and even then, you only see your own rows."* Both are authorization. The first is at the door; the second is at the row level. Name it.
- *This is schema evolution again* — second time we've added a column with a migration. Recognition, not new learning. Note that existing rows from the previous project will have an empty `OwnerId` and won't be visible to either user. For a tutorial that's fine; in production you'd write a data migration to assign owners.

**Common gotchas:**
- Reading the claim from the wrong key — if claim mapping wasn't cleared in Phase 1, `sub` arrives as the long `ClaimTypes.NameIdentifier` URI and `User.FindFirstValue("sub")` returns null. If learner hits a claim-not-found bug here, send them back to Phase 1's `DefaultInboundClaimTypeMap.Clear()` line and check it landed.
- Forgetting to set `OwnerId` on `POST` — TODOs created without it have an empty string owner and effectively belong to nobody. Let the learner hit this, then ask *"who owns this TODO?"*
- Forgetting to filter `GET /todos/{id}` by `OwnerId` — endpoint returns *anyone's* TODO if you guess the id. This is an **IDOR** (Insecure Direct Object Reference) vulnerability. Name it out loud. It's the most common authorization bug in real codebases — by far. Worth a 2-minute aside even if the learner already filtered.

**After-action prompt:** *"You added authorization at two different layers in this project. What are they, and what would happen if you only had one and not the other?"*

### Phase 5 — Smoke-test auth end-to-end (~10 min)

**Goal:** Walk through the full auth flow as two different users. Prove that each user can only see their own data.

**What to do** (Swagger UI or `curl`):

1. `GET /todos` with no token → expect **401 Unauthorized**.
2. `POST /auth/login` with user A's credentials → expect **200** + JWT.
3. `POST /todos` with user A's token, body `{"title": "User A's bread"}` → expect **201**.
4. `GET /todos` with user A's token → expect a list containing User A's TODO.
5. `POST /auth/login` with user B's credentials → expect **200** + JWT.
6. `GET /todos` with user B's token → expect an empty list `[]` (B hasn't posted anything; A's TODO is invisible).
7. `POST /todos` with user B's token, body `{"title": "User B's milk"}` → expect **201**.
8. `GET /todos` with user A's token → expect User A's TODO only (User B's milk is invisible to A — this is the isolation assertion).
9. `GET /todos` with user B's token → expect User B's TODO only.
10. (Optional) Open `todos.db` and confirm each row has the correct `OwnerId`.

**Concepts to reinforce:**
- *Two layers worked together* — `[Authorize]` kept anonymous calls out (step 1); data scoping kept users in their own lane (steps 6 and 8).
- *The token carried identity across requests* — the server didn't look up either user in the database after login. Every request brought its own proof of identity.

**After-action prompt:** *"You proved two things in this smoke test. What are they? Which step proved which?"*

## When to break the method

The ride-along method assumes the learner can drive the keyboard. If during any phase you discover:

- **Learner doesn't know what an HTTP header is** — pause. 3 minutes on headers (`Content-Type`, `Authorization`, `Accept`) using `curl -v`. Resume.
- **Learner is shaky on JSON structure** — JWT payload is JSON; `appsettings.json` is JSON; request bodies are JSON. If `{}` vs `[]` is confusing, pause until it isn't.
- **Learner is overwhelmed by "auth" as a concept** — slow down. Most of the difficulty in auth comes from terms (authn/authz, JWT, claims, bearer, principal) all flying at once. Use the after-action prompt from Phase 1 as a checkpoint. If they can't answer it cleanly, do not move to Phase 2 yet.

These are not method failures. The ride-along method *expects* the mentor to drop into a 3-5 minute concept tangent when a foundation is missing — the rule is to name it out loud and return to the build.

## Definition of done

- API runs locally (`dotnet run`)
- All Phase 5 smoke-test steps produce the expected status codes and visibility
- Each TODO row in `todos.db` has a non-empty `OwnerId` matching the user that created it
- Learner can describe — without looking — the difference between authentication and authorization, what a JWT carries, what a claim is, and what data scoping protects against (IDOR)

## Next project

If learner wants to put the secured API in the cloud → [`cad-deploy-app-service`](../cad-deploy-app-service/SKILL.md) (where the signing key has to move out of `appsettings.json` and into a real secret store).
If learner wants to extend with file uploads → [`cad-blob-uploader`](../cad-blob-uploader/SKILL.md).
