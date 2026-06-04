# Mentee Questions for Jay

A running list of questions mentees have asked Jay about AI agents, learning paths, and the craft of building agentic systems. Answers land here as Jay (or the Mentor) works through them.

## How to use this doc

- **Mentees:** add your question to the bottom of the list with the date and your username. Keep it one question per item. If a thread of questions naturally clusters, group them under a single heading.
- **Jay / Mentor:** answers go directly under each question as a `**A:**` block. Leave the question text untouched so the original wording is preserved.
- **Format:** numbered list, oldest at the top, newest at the bottom. Don't renumber when adding — Markdown will.

---

## Questions

1. What are some of the areas you see agents being the most helpful, least helpful?

   **A (Jay):**

   **Most helpful: automation that frees me to think.**
   Agents are great at the work that used to chew up my day — creating work items, opening PRs, drafting Word docs, summarizing meetings, pulling data from systems. Every minute an agent handles that, I get back for learning new things and designing what's next. That's the real win: not "agent writes my code," but "agent clears my desk so I can build."

   **Least helpful: when I treat it like a chatbot.**
   If I just talk at it and hope, I get drift, hallucinated APIs, and code that compiles but does the wrong thing. The longer the conversation, the worse it gets. It will confidently invent function names, miss context I assumed it had, and quietly forget what we decided three messages ago.

   **Two shifts that changed everything for me:**

   1. **Build it tools, don't just chat with it.** Once I gave my agent real tools — scripts, MCP servers, custom commands — it stopped guessing and started doing. A tool returns a fact. A chat returns a vibe.
   2. **Write down what you learn and feed it back in.** When the agent gets something wrong, I write the lesson into an instruction file. Next session, my custom agent loads that instruction automatically. Same mistake doesn't happen twice. The agent only gets smarter if *you* make it smarter — it won't do that on its own.

   **The pattern:** agents win at the structured, repeatable, well-scoped stuff. They lose when you ask them to hold the whole world in their head and reason their way through it.

1. What resources would you recommend for someone who is transitioning from logistics into Software Engineering / AI-ML — and specifically for learning agents on your own (YouTube channels, websites, podcasts, etc.)? Outside of using ChatGPT, Claude, etc.

   **A (Jay):**

   **The good news: most of what you need is free.** YouTube is a goldmine. There's no resource gap — there's an attention gap.

   **Resources I've actually used:**

   - **YouTube** — best free resource for both fundamentals and bleeding-edge agent work. Pick a few creators and go deep instead of scrolling 50.
   - **"Vibe coding" books** — taught me how to *talk* to an LLM. That's a real skill. The model isn't reading your mind; you're learning to write specs in plain English.
   - ***Agentic Artificial Intelligence: Harnessing AI Agents to Reinvent Business, Work and Life*** (Bornet et al.) — solid mental model for how agents fit into work, not just code. [Amazon link](https://www.amazon.com/Agentic-Artificial-Intelligence-Harnessing-Reinvent/dp/B0F1KKYX4T)

   **The habit that beats any book: build something every day.**
   I learn the most by building. Doesn't have to be big — a script, a small agent, a tool that automates one annoying step. Reading about agents gets you 10%. Building one gets you the other 90%.

   **Warning — the real enemy is distraction.**
   With AI, you can build *anything*. That's the trap. Every shiny demo pulls you sideways. The hardest skill isn't writing code, it's staying on the one thing you said you'd do today. Pick a task, finish it, then look at the next shiny thing.

1. What projects would you recommend building to demonstrate AI agent skills to employers?

   **A (Jay):**

   **Honest answer: I don't know what an AI interview will look like.** The industry is figuring it out in real time. I'm curious myself. What I *can* tell you is what makes a project *feel* real vs. generic.

   **Build something that holds your attention.**
   The topic almost doesn't matter. What matters is that you care enough to keep coming back to it. The first version is a draft — not the finish line. Real skill shows in iteration 5, not iteration 1.

   **Vibe coding is still coding.**
   People think AI lets you skip the grind. It doesn't. You still iterate, debug, redesign, throw stuff out, and rebuild. The work is different, not less.

   **Avoid generic projects.**
   "Build a chatbot," "summarize a PDF," "RAG over Wikipedia" — every bootcamp graduate has one. Employers can smell a template. What stands out is creativity — solving a specific, weird, personal problem in a way only *you* would have thought of. There's an art to building. Show that you have taste.

   **A simple filter:** if you can describe your project in one sentence and a hundred other people built the same thing this month — pick something else. Or take that same project and push it somewhere weird and personal.

1. The idea of orchestrating many agents for a business idea of my own sounds very cool to me. From my understanding, this requires us to call LLM APIs (?) — any limitations in terms of our access to resources being an individual wanting to do something like this vs at a company? And how best to go about addressing it.

   **A (Jay):**

   **Yes — to build a multi-agent system, you're calling an LLM somehow.** That can mean a paid API (OpenAI, Anthropic, Azure OpenAI), a free/cheap hosted model (Google's free tier, OpenRouter, Groq), or running an open-source model locally (Ollama, LM Studio with Llama, Qwen, Mistral). All of these are real options for an individual.

   **Where individuals actually hit walls — and what to do:**

   | Limit | Reality for an individual | How to address it |
   |---|---|---|
   | **Token cost** | Multi-agent systems burn tokens fast. A single run can be $0.50–$5+ on frontier models. | Start with cheap/local models. Reserve frontier models for the steps that need them. Cache aggressively. |
   | **Rate limits** | Free tiers throttle hard. Frontier APIs gate by spend tier. | Add retries with backoff. Mix providers (OpenRouter is good for this). Pay $5–$20 to unlock a higher tier early. |
   | **Compute** | Local models need a decent GPU (or Apple Silicon). | An M-series Mac or a $300 used GPU runs surprisingly capable 7B–14B models. |
   | **Enterprise data** | Companies plug agents into Salesforce, SharePoint, SAP. You don't have that. | Build on data you *do* have: your inbox, your notes, public APIs, your own files. The pattern is the same. |
   | **Compliance / SSO / SOC2** | Companies need it. You don't, until you sell to one. | Ignore until you have a paying customer who asks. |

   **What's *not* as different as people think:**
   The orchestration, the prompts, the agent loops, the tool-calling patterns — all identical between a solo dev and a company. The frameworks (LangGraph, AutoGen, CrewAI, Semantic Kernel, plain Python) are free and open-source. You can build the same architecture a company builds. You just run it smaller.

   **How to start solo today:**

   1. **Pick a tool you can use today, free.** GitHub Copilot, Claude Desktop, or ChatGPT all let you start building "agent-like" workflows without writing any API code. Use what you already have.
   2. **Pick one small problem.** Something annoying you do every week — sorting receipts, drafting weekly updates, renaming files. One agent, one job.
   3. **Get it working end-to-end before adding anything.** Even if it's ugly. "It runs once and does the thing" is a milestone. Most people quit before this.
   4. **Only add a second agent when the first one clearly can't do the job alone.** If you're adding agents because it sounds cool, stop. Complexity will eat you.
   5. **Worry about API keys, costs, and model providers *later*.** That's the next chapter, not this one. You don't need to spend money to learn the patterns.

   **The bottleneck is almost never access.** It's focus and iteration speed.

1. What are the most common architectural mistakes people make when building AI agents?

   **A (Jay):**

   **The biggest mistake: not understanding the parts.**

   An agent isn't one thing. It's a system made of components:

   - **Agent** — the persona, the orchestrator. Decides what to do next.
   - **Skills** — reusable capabilities the agent can invoke.
   - **Tools** — concrete actions (call an API, read a file, run a script).
   - **Instructions** — durable rules the agent follows across sessions.
   - **Prompts** — what gets sent to the model in the moment.

   Devs who don't understand which is which try to cram everything into one piece. They write a 3,000-line system prompt. Or they build "the one skill that does everything." Or they treat every tool call as a prompt and wonder why the agent drifts.

   **The second mistake: building workflows instead of systems.**

   A workflow is a script with extra steps. You write it once, it runs the same way every time. That's not what an agent is.

   An agent is a system — the parts have to *compose*. The way a skill calls a tool, the way an instruction shapes a prompt, the way one agent hands off to another — that's the design work. People skip it and end up with a brittle chain that breaks the moment reality looks slightly different from the demo.

   **The trap that feeds both mistakes: chasing the "ultimate skill."**

   I see devs spend a week tuning one skill to handle every edge case, when the right move was three smaller skills that compose cleanly. Don't optimize a single part. Optimize how the parts fit together.

   **Rule of thumb:** if you can't draw your agent on a napkin and explain how the pieces talk to each other, you're not designing — you're stacking.

1. How do you decide when a task should be handled by a single agent versus multiple specialized agents? (Also: when should I use multiple agents instead of one LLM?)

   **A (Jay):**

   **Default to one.** Start with a single agent and one model call. Most problems don't need more than that, and most people skip this step because multi-agent sounds cooler.

   **The industry has flip-flopped on this.** Two years ago everyone was hyped on multi-agent systems. Then we found out the complexity often makes things *worse* — slower, more expensive, harder to debug, easier to break. There's no right answer. I lean toward elegant and simple designs because they're easier to build and the output is better.

   **Signals you might need more than one:**

   - One agent's prompt is getting unmanageable (thousands of lines, contradictory rules).
   - The work has truly different *modes* — planning vs. doing vs. reviewing — that benefit from different system prompts, tools, or even different models.
   - You need parallelism (10 things happening at once on independent work).
   - The work crosses trust boundaries (one agent shouldn't see what the other is doing).

   **Signals you're forcing it:**

   - "Multi-agent" because it sounds impressive in a demo.
   - You can't explain what the second agent *uniquely* does.
   - The agents spend more time talking to each other than doing work.
   - You added an "orchestrator agent" to fix problems your first agent was already supposed to solve.

   **Rule of thumb:** one agent until it visibly breaks. Then split along the seam that's actually breaking — not the one a tutorial told you to split on.

1. Advice on prompt engineering?

   **A (Jay):**

   **Real talk — learn instructions, not prompts.** Prompts are what *users* type in. As a builder, your job is the system around the prompt. The component that survives across sessions and shapes every output is the instruction file. Learn what goes in one, learn how it loads, learn how the agent picks it up. That's the leverage.

   **Two things I wish I'd known sooner:**

   1. **There's a huge knowledge gap, and it's wider than you think.** I spent months heads-down learning. I assumed everyone around me was doing the same. They weren't. I'd ask teammates for input on agent design and realize they hadn't even started learning how to *use* Copilot or Claude as a tool. So I ended up making all the decisions. That gap won't last forever — people are catching up — but right now, going deep separates you from the pack. The single weirdest pattern: lots of smart people *still* can't shake the chatbot framing. They treat the LLM like a person to chat with instead of a tool to wield.
   2. **The pace is brutal.** This space changes weekly. Every time I think I've got it figured out, something new drops. You don't beat that by reading more — you beat it by building. Your system gets a small upgrade each week and you stay in motion.

   **Habits worth building:**
   - Learn to vibe code. It's not lazy — it's a different way of writing software.
   - Write specs and design docs in plain English. That *is* prompt engineering.
   - Learn markdown. It's the lingua franca for talking to LLMs.

   **What I stopped doing:**
   Over-planning. My early plans were so detailed that the plan itself drifted from reality the moment I started building. Now I plan light, implement fast, and iterate on the *code* — not the planning doc. Iterating on a doc is fake progress.

   **My tooling:**
   I don't keep a prompt library. I keep an **instruction library**. I have a custom agent that rewrites my prompts before they hit the LLM so I get better output without typing more. That's the leverage move — improve the system, not every individual prompt.

   **The contrarian advice:**
   Think about your **system**, not the new shiny thing. Every week some skill, tool, or framework drops and the internet calls it a game-changer. Doesn't matter. If it doesn't fit your system, it won't make your agent better — it'll just add complexity. Good ≠ good *for you*.

1. How are you using agents in your day-to-day activities / job duties?

   **A (Jay):**

   **I have a custom GitHub Copilot agent named Kimberly.** She works alongside me in everything I do — even helping me write the answers to *these* questions. I'm a marine, not a writer, and she knows that. She helps me get my thoughts out.

   **What Kimberly does for me every day:**

   - Creates work items and pull requests
   - Reviews PRs
   - Makes videos
   - Tracks all my active work, the teams I'm part of, and what's on my plate
   - Brainstorms with me when I'm stuck on a design
   - Drafts docs, slides, and Word docs

   **But the best stuff is the meta-stuff:**

   - **She records my learnings.** When I figure something out, she captures it as an instruction file. Next time, she already knows.
   - **She interviews me when there's a misunderstanding.** Instead of guessing, she asks one question at a time until she actually has what she needs.
   - **She slows down and teaches me when I get stuck.** Doesn't dump code — walks me through it.

   **Why it works:** Kimberly isn't a chatbot. She's a system I've shaped over time with instructions, skills, tools, and a knowledge graph. Every mistake I made and corrected lives somewhere in her files, so we don't repeat it. The longer I work with her, the better she gets — because *I* taught her.

   **I can't say enough good things about it.** This isn't "AI helped me with a task." This is a teammate who's been with me through every project for months.

1. How would you architect a multi-agent system?

   **A (Jay):**

   **This question is vague, and that's the trap.** You can't architect a multi-agent system in the abstract. The architecture comes from what you're *actually* building.

   **My approach, every time:**

   1. **Start with an idea.** A specific thing you want the system to do. Not "a multi-agent platform" — something concrete like "summarize my week" or "draft a PR from a bug report."
   2. **Build it with one agent.** One persona, one set of instructions, the tools it needs. That's it. You'll be surprised how far this goes.
   3. **Use it. Push it. Try to break it.** Run it on real work.
   4. **When it actually breaks — split along the seam that broke.** Not where a tutorial said to split. Where *your* design showed you the seam.

   **Why this beats "designing" upfront:**
   The shape of a multi-agent system is determined by what you learn while building. You can't see the seams until you hit them. Architecting in advance produces fragile diagrams that don't survive contact with the work.

   **The real skill isn't drawing the architecture. It's knowing when to stop adding to one agent and start a second.** And that judgment only comes from building.

1. How do agents resolve conflicting recommendations?

   **A (Jay):**

   **Yes — I've hit this and fixed it. Real example:**

   I built an agent called **Sydgate** that auto-reviews pull requests at work. It runs under another system called Agency that adds its own instructions on top of mine. One day Sydgate just went silent on a whole class of PRs. Wasn't broken — it was actively choosing to stay quiet.

   The reason: Agency's instructions said *"do not call reply_to_comment"*. Sydgate's instructions said *"always review the PR."* Two perfectly reasonable rules — completely contradicting each other in this one situation. Sydgate, doing what LLMs do, picked the most recent/specific instruction and shut up.

   **How I fixed it:**

   I added a **precedence table** to Sydgate's instructions. Plain language, ordered top to bottom:

   1. *If this is an Agency-triggered job, force the "review" intent. Always.*
   2. *Never go silent. Acknowledge, even if you can't act.*
   3. *Then everything else.*

   That's it. No clever logic, no "judge" agent voting on what to do. Just an explicit ordering: when rules conflict, this one wins.

   **What I learned from this:**

   - **Conflicts will happen.** The more sources of instruction your agent has (system prompt, instruction files, tool outputs, other agents), the more often two of them will tell it different things.
   - **Don't make the agent figure it out at runtime.** Decide the precedence upfront and write it down. LLMs are bad at picking between two authoritative-sounding rules — they'll flip a coin and you won't know which side landed.
   - **A precedence table beats a "smart" tie-breaker.** I've seen people add an orchestrator agent to "resolve conflicts." That just gives you a new agent that *also* needs a precedence table.
   - **For *multi-agent* conflicts** (two agents recommending different things), same principle: pick the agent whose domain owns the decision, and the other one defers. Don't vote. Voting is how committees produce mediocre outputs.

   **The honest version:** most conflict resolution comes from clearer design, not smarter logic. If two of your agents disagree often, you probably split them along the wrong seam.

1. Should every agent have its own memory?

   **A (Jay):**

   **Yes — every agent should have memory.** Not just because "best practice says so." Memory is what lets you actually *evaluate* an agent.

   **Here's the chain:**

   1. **Memory** → you can see what the agent did, what it learned, what it got wrong.
   2. **Evaluation** → you can grade those records. Pass/fail, good/bad, what broke.
   3. **Feedback loops with real learning** → the agent doesn't just log the mistake, it captures the lesson somewhere durable (an instruction file, a rule, a piece of context).
   4. **Self-healing** → you build a system that processes those captured lessons and writes the fix. The agent gets better without you in the loop for every bug.

   Without memory, you can't do any of that. The agent makes the same mistake every Monday and you're the only one who notices.

   **What "memory" actually is — three layers:**

   - **Session memory** — what we're doing right now. Cleared when the conversation ends.
   - **Project memory** — what we learned working on this codebase. Persists across sessions for this one project.
   - **Long-term memory** — durable rules, preferences, patterns that apply to *everything* the agent does. This is where the real learning lives.

   You want all three. Each one serves a different evaluation question.

   **Should agents share memory?** Sometimes. Most of the time, separate. Sharing creates coupling — when you change one agent's notes, you risk breaking the other. If two agents need the same fact, put it in a shared *file* both of them read, not in one agent's memory the other agent peeks at.

   **The end state I'm building toward:** an agent that finds its own bugs, records the lesson, and ships the fix. That's only possible if memory is a first-class part of the design. Bolting it on later doesn't work.
