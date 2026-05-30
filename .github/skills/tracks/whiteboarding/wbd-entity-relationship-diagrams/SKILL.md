---
name: wbd-entity-relationship-diagrams
description: |
  Whiteboarding track project #5. Learner draws ER diagrams for relational data
  models. Drills entities, attributes, primary keys, foreign keys, and cardinality
  (one-to-one, one-to-many, many-to-many) using crow's foot notation. Walks 3 schemas:
  e-commerce, blog with tags, multi-tenant SaaS. Auto-load when the learner is in
  `whiteboarding/wbd-entity-relationship-diagrams` or asks how to draw an ER diagram,
  schema diagram, database diagram, or model relationships between tables.
---

# Project: `wbd-entity-relationship-diagrams`

> **Track:** Whiteboarding · **Project:** 5 of 9 · **Time:** ~75 minutes
>
> ER diagrams are the contract for your database. They precede `CREATE TABLE` and survive long after. Reading ER diagrams is mandatory for any engineer who touches data; drawing them is the difference between "I think we need a users table" and "here's the model, here's the cardinality, here's the join table." By the end of this project the learner can sketch any relational schema in under 10 minutes using crow's foot notation.

## Project goal

When this project is done, the learner can:

- Draw an entity (rectangle), list its attributes (inside the rectangle or attached), and underline the primary key.
- Draw relationships between entities with **crow's foot notation** for cardinality.
- Distinguish **one-to-one**, **one-to-many**, and **many-to-many** — and know that many-to-many always means **a junction table**.
- Spot a missing junction table in a half-finished diagram.
- Use ER diagrams to communicate schema BEFORE writing migrations.

## Scope guardrail

This is **3 schemas drawn + crow's foot drill + junction-table discipline**. We are not learning full Chen notation (the "diamond" form), DBML, or PlantUML class diagrams. The point: the 80% of ER notation used in working teams to discuss schema changes.

If the learner asks "what about NoSQL / document DBs?" — answer honestly: *ER diagrams are about relations. Document DBs need different tools (often a tree-style diagram). ER still helps for the conceptual model — entities and relationships exist regardless of storage*.

## Prerequisites

| Prereq | Verify with |
|---|---|
| Completed [`wbd-box-and-arrow-diagrams`](../wbd-box-and-arrow-diagrams/SKILL.md) — comfortable with rectangles and labeled arrows | Can draw a clean rectangle in 3 seconds |
| Basic understanding of relational tables (rows, columns, keys) | Can name what a primary key is |
| A whiteboard, paper, or [Excalidraw](https://excalidraw.com) | — |

## Phases

### Phase 1 — Entity, attributes, primary key (~10 min)

**Goal:** Draw a single entity with attributes and the primary key marked.

**The convention (most common):**

```
┌─────────────────┐
│      USER       │   ← entity name, ALL CAPS, singular noun
├─────────────────┤
│ id  (PK)        │   ← primary key, marked (PK) or underlined
│ email           │
│ display_name    │
│ created_at      │
└─────────────────┘
```

**Rules of thumb:**
- Entity name is **singular** (`USER`, not `USERS`). The TABLE name in the DB is plural; the entity name in the diagram is singular.
- Primary key first, then attributes in some logical order (identity, descriptive, audit timestamps last).
- Don't list every column — list the **important** ones. For audit columns (`created_at`, `updated_at`, `deleted_at`) one line saying `audit fields` is fine on a whiteboard.

**Drill — draw 3 entities:**

1. `PRODUCT` (id, sku, name, price, in_stock)
2. `ORDER` (id, user_id, total, status, placed_at)
3. `CATEGORY` (id, name, parent_category_id)

**Concepts to name out loud:**
- *This is **the entity as a noun, the attribute as a property*** — entities are things (USER, ORDER), attributes describe them (email, total).
- *This is **the primary key as the entity's identity*** — the one column (or set) that uniquely identifies a row. Without it, you can't reference the entity from elsewhere.
- *This is **why singular naming matters*** — `ORDER` is "an order"; relationships read naturally: "USER places ORDER" beats "USERS places ORDERS."

**After-action prompt:** *"You drew 3 entities. Cover the labels — can you tell which attribute is the primary key from the diagram alone? If not, your PK convention isn't visible enough."*

### Phase 2 — Cardinality + crow's foot notation (~15 min)

**Goal:** The most-confused part of ER. Make it visual.

**Crow's foot notation — read the symbol on the END of the line nearest the entity:**

| Symbol | Means | Read as |
|---|---|---|
| `─||` (two bars) | Exactly one (one, and only one) | "exactly one" |
| `─|o` (bar + circle) | Zero or one | "at most one" |
| `─}|` (crow's foot + bar) | One or many | "at least one" |
| `─}o` (crow's foot + circle) | Zero or many | "any number, possibly zero" |

**The four common relationships:**

```
USER ──||────||── PROFILE          one-to-one (each user has exactly one profile)

USER ──||────o{── ORDER            one-to-many (each user can have zero or many orders;
                                                 each order belongs to exactly one user)

USER ──}o────o{── ROLE             many-to-many (each user can have many roles;
                                                  each role can be held by many users)
                                                  → REQUIRES a junction table

ORDER ──||────|{── ORDER_ITEM      one-to-many, required (each order MUST have at least
                                                           one item; each item belongs
                                                           to exactly one order)
```

**Drill — for each relationship, draw it AND say it out loud:**

1. A blog `POST` and its `COMMENT`s — one-to-many (one post has many comments; each comment belongs to one post).
2. A `USER` and a `PASSWORD_RESET_TOKEN` — one-to-many (over time a user has many tokens; each token belongs to exactly one user).
3. A `STUDENT` and a `COURSE` — many-to-many (a student takes many courses; a course has many students). Junction table: `ENROLLMENT`.
4. A `CATEGORY` and itself (parent/child) — recursive one-to-many (each category has zero or one parent; can have many children).

**Concepts to name out loud:**
- *This is **read the symbol nearest the OTHER entity*** — the symbol on PROFILE's end of the USER—PROFILE line tells you "how many PROFILEs per USER." Common mistake: reading the symbol nearest the entity you're starting from.
- *This is **why "exactly one" vs "at most one" matters*** — exactly one (`||`) means the database enforces presence (NOT NULL). At most one (`|o`) means optional (NULLABLE). The difference is a real constraint with real consequences.
- *This is **many-to-many always means a junction table*** — the relational model can't store many-to-many directly. You need a third table whose rows are pairs (e.g., `ENROLLMENT(student_id, course_id)`).

**Common gotchas:**
- Drawing crow's feet inward (on both ends) for a one-to-one → wrong. Crow's feet mean "many."
- Drawing many-to-many as a direct line between two entities → looks valid on a whiteboard but doesn't translate to SQL. Always either draw the junction table OR annotate "(requires junction)".
- Saying "many-to-many" when you mean "one-to-many in one direction, one-to-many in the other" → that's just two one-to-many relationships through a shared entity. Different structure.

**After-action prompt:** *"You drew 4 cardinalities. Walk through each one out loud: 'each X relates to (zero/one/many) Y, and each Y relates to (zero/one/many) X.' If you can't say it cleanly, the diagram is ambiguous."*

### Phase 3 — Schema #1: e-commerce (~15 min)

**Goal:** A full e-commerce data model with the common entities.

**The entities:**

- `USER` (id PK, email, password_hash, created_at)
- `ADDRESS` (id PK, user_id FK, street, city, postal_code, country, is_default)
- `PRODUCT` (id PK, sku, name, description, price, in_stock)
- `CATEGORY` (id PK, name, parent_category_id FK self-ref)
- `PRODUCT_CATEGORY` (product_id FK, category_id FK)  — junction
- `ORDER` (id PK, user_id FK, address_id FK, total, status, placed_at)
- `ORDER_ITEM` (id PK, order_id FK, product_id FK, qty, price_at_purchase)
- `PAYMENT` (id PK, order_id FK, amount, status, processed_at, txn_id)

**Relationships to draw:**

- `USER ─||──o{─ ADDRESS` (user has many addresses)
- `USER ─||──o{─ ORDER` (user has many orders)
- `ADDRESS ─||──o{─ ORDER` (an address is used by many orders)
- `PRODUCT ─||──}o─ PRODUCT_CATEGORY ─o{──||─ CATEGORY` (M:N via junction)
- `CATEGORY ─|o──o{─ CATEGORY` (recursive: parent / children)
- `ORDER ─||──|{─ ORDER_ITEM` (order has at least one item)
- `PRODUCT ─||──o{─ ORDER_ITEM` (product appears in many items)
- `ORDER ─||──o{─ PAYMENT` (order can have many payments — retries, partial refunds)

**Draw it on the board, one cluster at a time:**

1. Start with `USER` in the center.
2. Add `ADDRESS` (1:N from user).
3. Add `ORDER` (1:N from user, 1:N from address).
4. Add `ORDER_ITEM` (1:N from order, 1:N from product).
5. Add `PRODUCT` (linked from ORDER_ITEM).
6. Add `PAYMENT` (1:N from order).
7. Add `CATEGORY` + `PRODUCT_CATEGORY` (M:N between product and category).

**Concepts to name out loud:**
- *This is **the central entity strategy*** — pick the most-connected entity (`USER` or `ORDER`) and draw out from it. Spaghetti ERs come from starting in a corner and adding entities randomly.
- *This is **why `price_at_purchase` exists on ORDER_ITEM*** — products change price over time, but a historical order must show the price the customer actually paid. Without this column, refunds and accounting break. The diagram makes this design decision visible.
- *This is **the recursive relationship on CATEGORY*** — parent/child relationships in the same table. A category can be a subcategory of another category. `parent_category_id` is nullable (top-level categories have no parent).

**Common gotchas:**
- Forgetting the junction `PRODUCT_CATEGORY` → many-to-many without a junction is unimplementable. Always draw it.
- Storing `quantity` on PRODUCT instead of ORDER_ITEM → conflates "stock on hand" with "how many were ordered." Two different things, two different columns.
- Making `ADDRESS.user_id` non-null AND making `ORDER.address_id` reference it → fine, but be sure the address can't be deleted while an order references it. ER diagrams don't show deletion rules; they're a separate conversation.

**After-action prompt:** *"You drew 8 entities. If you handed this to a backend engineer, could they write the migrations? If yes, the ER served its purpose."*

### Phase 4 — Schema #2: blog with tags (~10 min)

**Goal:** A small schema that exercises many-to-many cleanly.

**Entities:**

- `AUTHOR` (id, email, display_name)
- `POST` (id, author_id FK, title, body, published_at)
- `TAG` (id, name)
- `POST_TAG` (post_id FK, tag_id FK) — junction
- `COMMENT` (id, post_id FK, author_email, body, posted_at)

**Relationships:**

- `AUTHOR ─||──o{─ POST` (author has many posts)
- `POST ─||──}o─ POST_TAG ─o{──||─ TAG` (M:N via junction)
- `POST ─||──o{─ COMMENT` (post has many comments)

**Notice:** `COMMENT.author_email` is a string, not a foreign key. Why? Because comments can come from non-registered users. The diagram makes this design choice visible. (Alternative: separate `COMMENT_AUTHOR` entity with optional `user_id`. The diagram should reflect the choice.)

**Concepts to name out loud:**
- *This is **the tagging pattern as the canonical M:N*** — tags are the textbook many-to-many. Anything similar (skills on a resume, ingredients in a recipe, members of a group) follows the same pattern.
- *This is **why `POST_TAG` has no `id` column*** — its primary key is the composite `(post_id, tag_id)`. Junction tables typically use composite PKs. The diagram should show this (underline both columns, or note "PK: composite").

**After-action prompt:** *"You drew the tagging schema. If a feature request comes in — 'show me all posts tagged BOTH python AND testing' — your ER tells the query writer they need to join POST_TAG twice. Could you have predicted this from a less-clear diagram?"*

### Phase 5 — Schema #3: multi-tenant SaaS + the discipline of reviewing an ER (~25 min)

**Goal:** Bigger schema; practice spotting missing entities, missing junctions, missing constraints.

**The product:** a multi-tenant SaaS project management tool (think a simpler Asana).

**Entities to capture (some intentionally underspecified — the drill includes finding what's missing):**

- `TENANT` (id, name, plan, created_at)
- `USER` (id, email, name)
- `MEMBERSHIP` (user_id FK, tenant_id FK, role: 'admin'|'member'|'viewer')  — M:N junction (users belong to many tenants; tenants have many users)
- `PROJECT` (id, tenant_id FK, name, archived)
- `TASK` (id, project_id FK, title, description, status, assignee_user_id FK, due_date)
- `TAG` (id, tenant_id FK, name, color)
- `TASK_TAG` (task_id FK, tag_id FK) — M:N junction
- `COMMENT` (id, task_id FK, author_user_id FK, body, posted_at)

**Drill — the "review the diagram" exercise:**

Imagine a colleague drew this schema and asked you to review it. Ask these questions out loud:

1. **Can a USER belong to multiple TENANTs?** Yes — `MEMBERSHIP` is M:N. ✅
2. **Can a TASK be assigned to a USER who isn't a member of the TASK's TENANT?** The schema doesn't prevent it. This is a **referential integrity gap** — `TASK.assignee_user_id` should ideally be constrained to "user has membership in this tenant." Note it as a follow-up. ✋
3. **Can a TAG cross tenants?** No — `TAG.tenant_id` is per-tenant. ✅
4. **What happens if a PROJECT is deleted? What about its TASKs?** The diagram doesn't show cascade rules. Decide and document. ✋
5. **Where's the audit trail?** (created_at / updated_at / deleted_at?) Soft-delete vs hard-delete? Not in the diagram. ✋
6. **What about file attachments on tasks?** Not modeled. Add `ATTACHMENT(id, task_id, blob_url, uploaded_by)` if needed.
7. **What about subtasks (task hierarchy)?** Not modeled. Add `TASK.parent_task_id FK self-ref` if needed.

**Concepts to name out loud:**
- *This is **the ER as a review artifact*** — drawing the ER surfaces missing constraints, missing entities, and design decisions that haven't been made yet. The diagram BECOMES the conversation agenda.
- *This is **multi-tenancy as a horizontal concern*** — almost every entity needs a `tenant_id` for isolation. Forgetting it on one table is a data-leak bug. The diagram makes the omission visible.
- *This is **referential integrity gaps as out-of-diagram concerns*** — the ER shows entities and cardinality. It doesn't show constraints like "assignee must be a tenant member." That's a CHECK or trigger or application-level rule, and worth flagging.

**Common gotchas:**
- Forgetting `tenant_id` on TAG → tags from one tenant would leak to another. Multi-tenant data leaks are usually missed by review; the ER catches them.
- Drawing M:N without the junction → MEMBERSHIP can also be a M:N junction (user ↔ tenant), but it ALSO carries a `role` attribute. That's a hint: junctions can carry their own attributes, and when they do, they're "associative entities" not pure junctions.
- Skipping the review exercise → the value of the ER isn't drawing it, it's discussing it. Always ask the diagram questions.

**After-action prompt:** *"You reviewed the SaaS schema and found 4-5 gaps. In your next real schema review at work, run the same questions. The ER is most valuable when it's challenged."*

## When to break the method

- Learner already wrote SQL DDL → they know entities/columns. Skip Phase 1, drill Phase 2 (crow's foot is the under-taught notation).
- Learner is going into a database admin or data engineering role → spend more time on Phase 5 (multi-tenant review discipline). That's the daily skill.
- Time short → phases 2-3-5 are the must-do. Phase 4 (blog/tags) is a fast junction-table drill.

## Definition of done

Observable, the learner can:

- [ ] Draw 3 ER diagrams: e-commerce, blog with tags, multi-tenant SaaS.
- [ ] Use crow's foot notation correctly for one-to-one, one-to-many, many-to-many.
- [ ] Spot a missing junction table in a half-finished diagram.
- [ ] Walk through a 5-question review on someone else's ER and find gaps.
- [ ] Explain in one sentence each: junction tables, recursive relationships, `tenant_id` as horizontal isolation, ER-as-review-artifact.

## Next project

→ [`wbd-mermaid-as-code`](../wbd-mermaid-as-code/SKILL.md) — every diagram you've drawn so far has been by hand. Now learn Mermaid, the text-based diagramming language that renders in GitHub, VS Code, and PR descriptions. Your diagrams become version-controlled artifacts.
