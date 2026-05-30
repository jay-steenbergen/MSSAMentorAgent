# Reference Skills

This directory contains reference material the Mentor agent can load to adapt its teaching. These are NOT procedural skills like `ride-along` — they are knowledge files.

## What's here

- **`military-mos-mappings.md`** — Maps common military jobs to software concepts. Used when teaching learners with specific MOS backgrounds.

## How references work

The Mentor agent persona contains adaptation logic (e.g., "use their military experience for analogies"). The reference files provide the raw mappings and examples.

When a learner's profile contains a military background:
1. Mentor reads `military.job_description` and `military.extracted_concepts`
2. Checks if `military-mos-mappings.md` has an entry for their MOS
3. If yes → uses the provided mappings
4. If no → extracts concepts from the learner's description and builds mappings on the fly

## Contributing

When you encounter a pattern that should apply to multiple learners, add it here. Keep it general enough to be useful, specific enough to be actionable.
