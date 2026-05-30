# Military MOS → Software Concept Mappings

This reference file shows common military occupational specialties (MOS/Rating/AFSC) and how their operational experience maps to software engineering concepts. Use this when working with learners who have these backgrounds.

**Note:** This is NOT exhaustive. Most learners will have jobs not listed here. When that happens, the mentor interviews them about their actual responsibilities and builds the mapping on the fly.

---

## IT & Communications

### Army 25B — Information Technology Specialist
**Day-to-day:** Network setup, troubleshooting, server maintenance, user account management

**Maps to:**
- Network troubleshooting → Debugging distributed systems
- Change control procedures → Version control and code review
- User support → API design, error messages, documentation
- Server maintenance → DevOps, monitoring, incident response

**Teaching debugging:**
> *"Same isolation technique you used for network issues. Start at the user, work your way back through the stack, test each layer. The bug is hiding somewhere in that path — find which hop fails."*

---

### Navy IT — Information Systems Technician
**Day-to-day:** Satellite communications, cryptographic equipment, network operations

**Maps to:**
- Crypto key management → Authentication and secrets management
- Satellite comms → Distributed systems, latency considerations
- Network operations → Cloud architecture, service reliability

**Teaching authentication:**
> *"You managed crypto keys for comms gear. Same concept here — secrets that unlock access. Never hardcode them, rotate them regularly, control who has them. You already know this discipline."*

---

### Air Force 3D0X2 — Cyber Systems Operations
**Day-to-day:** Systems administration, virtualization, network operations

**Maps to:**
- Virtualization → Containers, cloud infrastructure
- Systems administration → Backend development, infrastructure as code
- Network operations → Service mesh, load balancing

**Teaching containerization:**
> *"Virtual machines, but lighter. You already know the concept — isolated environment, consistent configuration, deploy anywhere. Docker is the same idea at application level."*

---

## Intelligence & Analysis

### Army 35F — Intelligence Analyst
**Day-to-day:** Collect intelligence, analyze data, produce reports, brief leadership

**Maps to:**
- Data collection → ETL pipelines, data ingestion
- Analysis → Data processing, SQL queries, aggregation
- Report production → Data visualization, dashboards
- Briefing → Documentation, technical writing

**Teaching data pipelines:**
> *"You already know this workflow — collect raw data, validate it, transform it into something actionable, disseminate to the people who need it. That's Extract-Transform-Load."*

---

### Navy IS — Intelligence Specialist
**Day-to-day:** Process intelligence reports, maintain databases, produce analytical products

**Maps to:**
- Database maintenance → Database design, normalization, indexing
- Report processing → Data transformation, parsing, validation
- Analytical products → Business intelligence, reporting tools

**Teaching database design:**
> *"Same structure you maintained for intel reports. Every item has a unique ID, relationships between entities, queries to find specific information. You already think in these patterns."*

---

## Combat Arms → Software Concepts

### Marines 2336 — Explosive Ordnance Disposal Technician
**Day-to-day:** Render safe procedures, UXO identification, team leadership under high-stakes conditions

**Maps to:**
- Render safe procedures → Debugging production issues, incident response
- Failure analysis → Root cause analysis, postmortems
- Team leadership under pressure → Incident command, on-call rotation
- Risk assessment → Security analysis, threat modeling

**Teaching debugging:**
> *"Same discipline you used on render safe procedures. You don't guess and hope — you follow the steps, confirm each stage, and if something doesn't work, you stop and figure out why before proceeding. A bug in production is a live device. Treat it that way."*

**Teaching testing:**
> *"Think of your pre-mission checks. You never assumed the gear worked — you tested it every time. That's what unit tests are. Run them before you depend on the code in a high-stakes situation."*

---

### Army 11B — Infantry
**Day-to-day:** Mission planning, rehearsal, patrol execution, after-action reviews

**Maps to:**
- Mission planning → Requirements gathering, architecture design
- Rehearsal → Testing, staging environments
- Execution → Deployment, monitoring
- After-action review → Postmortem, retrospective

**Teaching testing:**
> *"This is your rehearsal. Walk through the mission before you go live. Find the problems in the safe environment, not in production. Same reason you rehearsed — you don't want surprises when it counts."*

---

## Logistics & Administration

### Army 88N — Transportation Management Coordinator
**Day-to-day:** Coordinate shipments, track inventory, manage schedules

**Maps to:**
- Inventory tracking → Database design, state management
- Shipment coordination → Workflow orchestration, event-driven systems
- Schedule management → Task queues, async processing

**Teaching databases:**
> *"This is inventory management at scale. Every item has a unique ID, you track quantities and locations, you log every transaction. Same principles you used, different medium."*

---

### Navy LS — Logistics Specialist
**Day-to-day:** Supply chain management, procurement, inventory control

**Maps to:**
- Supply chain → Data pipelines, dependency management
- Inventory control → Database design, transaction management
- Procurement → API integration, third-party services

**Teaching API design:**
> *"Think of this like your supply requisition process. You had a standard form, specific fields, validation rules, approval workflow. An API is the same — structured request, validation, processing, response."*

---

## Engineering & Technical

### Navy Nuke (various ratings: EM, ET, MM)
**Day-to-day:** Reactor plant operations, casualty procedures, precision troubleshooting

**Maps to:**
- Casualty procedures → Error handling, graceful degradation
- Precision troubleshooting → Debugging, instrumentation
- Watchstanding procedures → Monitoring, alerting, on-call

**Teaching error handling:**
> *"Same concept as your casualty procedures. You don't wait for the reactor to scram — you detect the fault, contain it, and fail safe. That's try-catch. Predict the failure modes, handle them explicitly."*

---

### Air Force 2A6X1 — Aerospace Propulsion
**Day-to-day:** Aircraft engine maintenance, troubleshooting, technical documentation

**Maps to:**
- Maintenance procedures → Refactoring, code maintenance
- Troubleshooting → Debugging, performance optimization
- Technical documentation → Code comments, API docs, runbooks

**Teaching code maintenance:**
> *"Same as maintaining a jet engine. You don't wait until it breaks — you inspect, you maintain, you replace worn parts before they fail. Refactoring is preventive maintenance for code."*

---

## Cyber & Information Warfare

### Air Force 1B4X1 — Cyber Warfare Operations
**Day-to-day:** Defensive/offensive cyber operations, vulnerability assessment, tool development

**Maps to:**
- Vulnerability assessment → Security testing, code review
- Tool development → Scripting, automation, tooling
- Defensive operations → Security architecture, threat detection

**Teaching security:**
> *"You already know defense-in-depth. Never trust, always verify. Multiple layers, assume breach, log everything. Same principles you applied defensively. Authentication, authorization, audit — all layers."*

---

## How to Use This Reference

1. **Check if the learner's MOS is listed** — if yes, use the mappings provided
2. **If not listed** — ask the learner about their actual responsibilities during the interview
3. **Extract operational concepts** — troubleshooting, planning, coordination, precision, high-stakes decisions
4. **Map to software equivalents** — what software concept uses the same mental model?
5. **Store in their profile** — save to `military.extracted_concepts` and `military.translation_to_code`
6. **Use throughout teaching** — when teaching that concept, reference their actual experience

## Contributing

When you encounter a learner with a new MOS and build a mapping:
1. Add it to this file
2. Include the MOS code, title, typical responsibilities
3. Show 2-3 software concept mappings
4. Provide at least one example teaching dialogue
