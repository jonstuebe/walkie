# ADR-0001 — A single owner for the pet lifecycle

**Status:** Accepted · 2026-07-14

## Context

A user reported a pet dying and showing a **duplicate grave**. The cause was structural, not cosmetic:

- The death transition (`insert GraveyardPet` → `delete Pet`) was implemented in **two places** — `PetManager` (foreground, main `ModelContext`) and `BackgroundPetUpdater` (the HealthKit observer, its own background `ModelContext`).
- Death detection was **not idempotent**: `Pet.applyMissedTaxes()` returned "died" whenever `health <= 0`, not only on the transition.
- `Pet.isAlive` existed but was never read or written — a dead flag, not a gate.

When the observer and the foreground ran the transition around the same time, each context fetched a live pet and each inserted a grave.

We also asked whether a third-party **state-machine package** (SwiftState, a Swift port of Tinder's StateMachine, TCA) would prevent recurrence.

## Decision

Introduce **`PetLifecycle`**, a single shared `@ModelActor`, as the sole owner of every write to a pet's life (`hatch`, `feed`, `applyElapsed`). It is instantiated once in `WalkieApp` and handed to both the SwiftUI environment and the HealthKit observer, so all mutations serialize through one actor and one context.

Supporting decisions:

- **Aliveness = `Pet` row existence.** `Pet.isAlive` deleted.
- **Idempotent death** via the existence gate on the single actor. A `#Unique` constraint on `GraveyardPet.petID` was considered as a defense-in-depth backstop but **dropped**: SwiftData can't add a unique constraint to an existing entity via lightweight migration (it crashes on upgrade), and the single writer already guarantees exactly-once. `petID` is kept as plain identity. The container also self-heals — an unopenable store is recreated rather than crash-looping.
- The module owns the full death/hatch **fan-out** (snapshot, widget reload, notifications), so behavior is defined once.
- Tax math split into pure `TaxSchedule`; the mutation moves into the actor.

## Rejected — a state-machine package

The recurrence was an **ownership / locality** problem, not a transition-**legality** problem. A package gives a legal-transition DSL, but sprinkled across the two kill sites it reproduces the duplicate exactly. For a two-state lifecycle (alive → dead) a hand-rolled `enum` behind one owner is deeper: it passes the deletion test where the dependency does not. Revisit only if the lifecycle grows real intermediate phases (e.g. egg → juvenile → adult → dead).

## Consequences

- `BackgroundPetUpdater` is deleted; `PetManager` becomes a thin view-model that delegates mutations to the actor.
- The lifecycle is testable through one interface (in-memory `ModelContainer` + a `LifecycleEffects` spy).
- New contributors add lifecycle behavior in one place; scattering it again should fail review against this ADR.
