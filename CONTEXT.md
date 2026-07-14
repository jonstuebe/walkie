# Walkie — domain glossary

Walkie is a step-driven virtual-pet app: a koala whose health rises and falls with the wearer's daily steps.

## Ubiquitous language

Use these terms in code identifiers, issue titles, tests, and UI copy. Don't drift to synonyms.

### Pet
The living koala. Exactly one exists at a time. **Aliveness = a `Pet` row exists** — when the pet dies its `Pet` row is deleted and a `GraveyardPet` is written. There is no `isAlive` flag; row existence is the single source of truth.

### GraveyardPet
An immutable memorial record of a pet that has died. Carries the dead pet's stable `id` (`petID`) so a grave can be traced back to its pet. Duplicate graves are prevented by the single-writer `PetLifecycle`, not a store constraint — a `#Unique` attribute can't be added via SwiftData lightweight migration without crashing existing installs (see [ADR-0001](docs/adr/0001-single-pet-lifecycle-owner.md)).

### Leaves
The feeding currency. The koala eats **leaves** (eucalyptus — koalas don't eat bamboo; that was the old "bamboo" naming, now retired). Leaves are *earned* from steps (1 leaf per 10% of the daily step goal) and *spent* on `feed` to restore health. Unspent leaves reset at midnight. The earning math lives in `LeafLedger`.

- **leaves earned** — total leaves today's steps have unlocked.
- **leaves available** — earned minus spent-today (after the daily rollover).

> The forest **backdrop** art (`BambooStalk`, `ForestBackdrop`) is scenery, not the leaves currency, and is intentionally left under its old name. It's a separate visual concern.

### Health tax
The daily drain. Health is debited at 10 evenly-spaced **checkpoints** between the user's wake and sleep times. Missing steps means the debits aren't offset by feeding, and health falls. The checkpoint schedule is pure math in `TaxSchedule`. When health reaches zero the pet dies.

### PetLifecycle
The single module (a shared `@ModelActor`) that owns every write to a pet's life: `hatch`, `feed`, and `applyElapsed` (the tax sweep, which may kill). All lifecycle mutations — foreground and the background HealthKit observer — route through this one actor, so a death is recorded exactly once. See [ADR-0001](docs/adr/0001-single-pet-lifecycle-owner.md).

### PetSnapshot
A `Codable` value shared with the widget via the app group. A denormalized view of the current pet for the widget to render without SwiftData access. Written by `PetLifecycle` on every transition.
