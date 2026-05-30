---
name: wbd-drawio-for-polished-diagrams
description: |
  Whiteboarding track project #7. Learner uses Draw.io / diagrams.net (free) to build
  polished architecture diagrams with cloud-provider icons, layers, and exports.
  Drills the Draw.io VS Code extension, AWS/Azure/GCP shape libraries, layer-based
  export, and the SVG-vs-PNG-vs-XML format question. Builds 2 diagrams: AWS 3-tier web
  app, Azure event-driven pipeline. Auto-load when the learner is in
  `whiteboarding/wbd-drawio-for-polished-diagrams` or asks about Draw.io, diagrams.net,
  polished diagrams, cloud icons, AWS/Azure architecture diagrams, or executive decks.
---

# Project: `wbd-drawio-for-polished-diagrams`

> **Track:** Whiteboarding · **Project:** 7 of 9 · **Time:** ~75 minutes
>
> Mermaid (project #6) is perfect for engineers reading READMEs. It's wrong for executive decks, customer-facing architecture documents, and anything that needs official cloud-provider iconography. Draw.io fills that gap — free, open-source, has every cloud icon you'd want, and exports to PNG / SVG / PDF. This project builds two real diagrams and codifies when to choose Draw.io over Mermaid.

## Project goal

When this project is done, the learner can:

- Install and use **Draw.io** (the VS Code extension or the web app at app.diagrams.net) — both free.
- Navigate the **shape libraries** (AWS, Azure, GCP, networking, UML) and drop the right stencils onto a diagram.
- Use **layers** to organize a diagram (logical layer / network layer / security layer) and export different combinations.
- Export to the right format: **SVG** for web (scalable), **PNG** for slides, **PDF** for print, **`.drawio`** XML for source-of-truth.
- Choose between Mermaid and Draw.io based on audience and durability.

## Scope guardrail

This is **2 diagrams built end-to-end + layer drill + export drill + decision tree**. We are not learning every Draw.io feature (templates, plugins, Confluence integration). The point: own the workflow for producing a polished diagram in under 30 minutes.

If the learner asks "should I pay for Lucidchart instead?" — answer honestly: *Lucidchart is polished and has real-time collaboration, but it's a subscription and the diagrams live in their cloud. Draw.io is free, runs locally, files are XML you control. For an individual learner with cost discipline, Draw.io is the right starting point. If your employer pays for Lucid, use it.*

## Prerequisites

| Prereq | Verify with |
|---|---|
| Completed [`wbd-box-and-arrow-diagrams`](../wbd-box-and-arrow-diagrams/SKILL.md) — comfortable with architecture diagram conventions | Can sketch a 3-tier web app on a whiteboard |
| Completed [`wbd-mermaid-as-code`](../wbd-mermaid-as-code/SKILL.md) — knows the diagrams-as-code mindset | Can write a Mermaid flowchart |
| VS Code installed | — |

## Phases

### Phase 1 — Install + first diagram (~10 min)

**Goal:** Draw.io running, you've placed a few shapes, you can save the file.

**Two install paths — choose one:**

**Option A: VS Code extension (recommended for this track):**

1. Open VS Code Extensions (`Ctrl+Shift+X`).
2. Search for `Draw.io Integration` (by Henning Dieterichs). Install.
3. Create a new file `architecture.drawio` (the file extension triggers the editor).
4. The Draw.io canvas opens inside VS Code. Drop a rectangle from the left panel onto the canvas.
5. Save (`Ctrl+S`). The file persists as XML.

**Option B: Web app:**

1. Browse to `https://app.diagrams.net`.
2. Choose where to save: "Device" (local file), Google Drive, or OneDrive. For learning, use Device.
3. Create a blank diagram. Drop a rectangle, save the file to your machine.

**Concepts to name out loud:**
- *This is **the `.drawio` file format as the source-of-truth*** — it's XML. You can commit it to git. The PNG you generate from it is a build artifact.
- *This is **the VS Code extension as a workflow win*** — your diagrams live next to your code, in the same editor, in the same git repo. No context switch.

**Common gotchas:**
- Don't save as `.png` directly as your working copy — you lose the editability. Always save as `.drawio` (or `.drawio.svg` which is editable XML disguised as SVG).
- The web app's "Device" mode forgets the file location — you have to re-open it each time.

**After-action prompt:** *"You created your first Draw.io file. If you committed it to git, your team could open it, edit it, save it, and the diff would be in the XML. Useful — but XML diffs are noisy. We'll address that with the export workflow."*

### Phase 2 — The shape libraries (~10 min)

**Goal:** Find the right stencils — especially cloud-provider icons.

**Where shapes live in Draw.io:**

- Left panel — default shapes (basic, advanced, ER, UML, flowchart).
- **Bottom of the left panel — "More Shapes..."** — this is where the cloud-provider libraries hide.
- Click `More Shapes` → check `Networking → AWS17`, `Networking → Azure`, `Networking → Google Cloud Platform` (and any others you want). Apply.
- Now those libraries appear in the left panel. Each has a search box.

**Drill — find these shapes (search by name):**

1. AWS Lambda
2. AWS S3 bucket
3. AWS DynamoDB
4. AWS EC2 instance
5. Azure App Service
6. Azure Cosmos DB
7. Azure Functions
8. GCP Cloud Run

Drop one of each onto the canvas. Notice the official iconography.

**Concepts to name out loud:**
- *This is **brand iconography as audience signal*** — using the official AWS Lambda icon (orange λ in a square) tells the audience "this is a Lambda" without you saying it. Generic rectangles labeled "Lambda" don't carry the same recognition.
- *This is **why cloud-provider docs and certification exam prep diagrams use these icons*** — they're the visual lingua franca of cloud architecture. Learning them is part of speaking the language.

**After-action prompt:** *"You found 8 shapes. The library has hundreds. In your actual diagrams, you'll use the same 10-20 over and over — pin them to favorites (right-click → 'Add to Favorites')."*

### Phase 3 — Diagram #1: AWS 3-tier web app (~20 min)

**Goal:** Build a polished diagram of a classic 3-tier web app on AWS.

**The components:**

- Users (use the basic User icon or AWS "User" shape)
- Route 53 (DNS)
- CloudFront (CDN)
- Application Load Balancer (ALB)
- EC2 instances (2, behind the ALB — represents the app tier)
- RDS (PostgreSQL — the data tier)
- ElastiCache Redis (cache tier)
- S3 (for static assets)

**Layout (top-to-bottom):**

```
              [ Users ]
                  │
                  ▼
              [ Route 53 ]
                  │
                  ▼
              [ CloudFront ]
                  │
                  ▼
              [ ALB ]
              /     \
          [ EC2 ]  [ EC2 ]
              \     /
               \   /
                ▼
              [ RDS ]    [ ElastiCache ]    [ S3 ]
```

**Steps:**

1. Drop all 7 shape types from the AWS library.
2. Arrange top-to-bottom (the user comes from the top, data is at the bottom).
3. Connect with arrows — hover over a shape to see arrows on its edges, drag to connect.
4. Label arrows where the flow is non-obvious (e.g., the ALB → EC2 connections don't need labels; the EC2 → ElastiCache should say "session cache" or similar).
5. Add a title at the top: "ShopApp — Production Architecture (AWS)."
6. Save as `aws-3-tier.drawio`.

**Polish tweaks:**

- Use a light background color for the "VPC" boundary (right-click → Edit Style or use Format → Fill).
- Group the two EC2 instances with a labeled container (`drag from "Container" in the basic library`) called "App Tier."
- Add a small legend in the corner if you used colors meaningfully (e.g., yellow = caching, green = persistent).

**Concepts to name out loud:**
- *This is **the difference between a sketch and a deliverable*** — the Phase 3 of project #2 sketched this same architecture in 15 minutes on a whiteboard. Now it took 20 minutes in Draw.io, but the result is presentation-quality and reusable.
- *This is **containers as visual grouping*** — the App Tier container is a single visual chunk. Reviewers see "everything inside this is the app layer" at a glance. Use containers for VPCs, subnets, regions, environments.
- *This is **the diminishing return on polish*** — for an exec deck, you might spend another 30 minutes adding shadows and brand colors. For an internal architecture doc, the version you have right now is enough. Know when to stop.

**Common gotchas:**
- Connecting arrows to the CENTER of a shape vs an EDGE matters in Draw.io — edge connections stay attached when you move the shape; center connections sometimes drift. Pay attention to which dot you click.
- Don't over-color. The cloud icons have their own colors. Adding background colors to every shape produces a coloring-book vibe. Restrain.

**After-action prompt:** *"You built a polished AWS diagram. Compare it to the hand-drawn version from project #2. Which would you put in a customer-facing architecture document? Which would you draw live in a meeting? The right answer is 'different tools for different jobs.'"*

### Phase 4 — Diagram #2: Azure event-driven pipeline + layers (~20 min)

**Goal:** Build an Azure-flavored diagram AND learn to use layers.

**The scenario:** A telemetry pipeline. Devices send events → Event Hubs → Stream Analytics → Cosmos DB. A separate Function reacts to alerts.

**Components:**

- IoT devices (use generic device shape or the Azure IoT icon)
- Azure Event Hubs
- Azure Stream Analytics
- Azure Cosmos DB
- Azure Functions
- Azure SignalR (real-time push to a dashboard)
- Web Dashboard (rounded rectangle)

**Layer drill — create 3 layers in Draw.io:**

1. Click the layers icon in the bottom-right of the editor (or `Edit → Layers`).
2. Create three layers: **Data Flow** (default), **Network**, **Security**.
3. Build the main pipeline on the **Data Flow** layer:
   - Devices → Event Hubs → Stream Analytics → Cosmos DB
   - Stream Analytics → Functions (alert path)
   - Functions → SignalR → Dashboard
4. Switch to the **Network** layer. Add a rectangle outlining "Azure VNet" around the components. (Hide the Data Flow layer briefly to see the network skeleton alone.)
5. Switch to the **Security** layer. Add small lock icons or "Managed Identity" callouts on the connections that use it (e.g., Functions → Cosmos DB authenticated with Managed Identity, not connection strings).
6. Toggle layers on/off to see each combination.

**Concepts to name out loud:**
- *This is **layers as separation of concerns*** — you can have one master diagram with multiple readings. For a network audit, hide everything but Network. For a security review, show Data Flow + Security. For an architecture overview, show everything.
- *This is **why layered diagrams beat 4 separate diagrams*** — 4 separate diagrams drift apart as the system evolves. One layered diagram stays in sync because there's one source of truth.

**Common gotchas:**
- A shape exists on exactly one layer by default. Use right-click → "Move Selection to..." to reorganize.
- Hiding a layer hides everything on it INCLUDING the arrows touching it. So if your arrow ends at a shape on layer X and X is hidden, the arrow looks like it ends in space. Either keep both ends on the same layer, or live with the visual.
- Don't make 10 layers — 2 or 3 are useful, 10 is unmanageable.

**After-action prompt:** *"You built a layered diagram. Toggle layers and imagine you're showing it in 3 different meetings (architecture review, network review, security review). Same source file, three audiences. That's the layer payoff."*

### Phase 5 — Export + the Mermaid-vs-Draw.io decision (~15 min)

**Goal:** Get diagrams out of Draw.io and into the world. Codify when to use which tool.

**Export from Draw.io:**

1. `File → Export As → ...`
2. **PNG** — raster image. Use for slides, README embeds, Confluence pages. Set the resolution (use 2x or "High" for retina-quality).
3. **SVG** — scalable vector. Use for web pages, docs that will be zoomed, anywhere infinite resolution matters.
4. **PDF** — for print or formal documents.
5. **`.drawio.svg`** — special format: looks like an SVG to viewers, but is editable XML to Draw.io. Best of both worlds for git: it renders inline on GitHub AND can be opened back in Draw.io for editing.

**Recommended workflow for git repos:**

- Save your working copy as `architecture.drawio` (the XML).
- Export `architecture.png` for any README that needs to display it.
- Commit both. Update the PNG when you update the source.
- OR use `architecture.drawio.svg` and reference it as `<img src="...">` — gets the editability AND the inline render.

**Now the decision tree — when Draw.io beats Mermaid:**

| Situation | Tool | Why |
|---|---|---|
| Exec deck or customer architecture review | **Draw.io** | Brand colors, cloud icons, polish |
| README in an engineering repo | **Mermaid** | Renders inline, diffable in PRs |
| Internal architecture doc | Either — depends on team norm | Pick one and be consistent |
| Quick sketch in a meeting | **Whiteboard / Excalidraw** | Speed > polish |
| Diagram needing official AWS/Azure/GCP icons | **Draw.io** | Mermaid has no cloud iconography |
| Diagram needing real-time collaboration | Whiteboard, Excalidraw, or Lucidchart | Draw.io has limited collab |
| Diagram that changes weekly with code | **Mermaid** | Diff-friendly |
| Diagram for compliance or audit document | **Draw.io** (PDF export) | Formal presentation |

**The honest summary:**

- **Mermaid:** developer-audience, version-controlled, ships with the code.
- **Draw.io:** customer-audience, polished, ships in decks and PDFs.
- **Whiteboard / Excalidraw:** brainstorm, live discussion, throwaway.
- **All three coexist** in mature teams. Mastery is knowing which to pick.

**Concepts to name out loud:**
- *This is **format-as-contract*** — PNG is a snapshot; XML/SVG is editable; PDF is for print. Picking the wrong format makes the diagram unusable for the recipient.
- *This is **the polish budget*** — every minute spent polishing a diagram is a minute not coding. For an exec deck: spend the time. For a Wednesday standup: don't. Be honest about which is which.

**After-action prompt:** *"You have three tools now: whiteboard, Mermaid, Draw.io. In the next month, pick one diagram from your real work and produce it in all three. Compare. The differences will teach you when each shines."*

## When to break the method

- Learner is on a Mac with Lucidchart available at work → mention it; the principles (shape libraries, layers, exports) transfer.
- Learner is going into a customer-facing role (solutions architect, presales) → spend more time on Phase 3-4 polish. Their daily output is polished diagrams.
- Time short → phases 1-3-5 are the must-do. Phase 4 (layers) is depth.

## Definition of done

Observable, the learner can:

- [ ] Install Draw.io (VS Code extension or web app) and save a `.drawio` file.
- [ ] Navigate shape libraries and place AWS, Azure, or GCP icons.
- [ ] Build a polished diagram with containers/groupings and labeled arrows.
- [ ] Use at least 2 layers and toggle them to show different views.
- [ ] Export to PNG, SVG, and PDF.
- [ ] Pick correctly between Mermaid and Draw.io for 5 audience scenarios.

## Next project

→ [`wbd-system-design-interview`](../wbd-system-design-interview/SKILL.md) — you have the diagramming skills. Now put them under pressure: a 45-minute system design interview, whiteboarded live, with an interviewer watching. Learn the framework, the time-box, and how to recover when you get stuck.
