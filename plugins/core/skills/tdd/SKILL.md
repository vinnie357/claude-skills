---
name: tdd
description: Test-Driven Development methodology and discipline. Use when writing code test-first, practicing Red-Green-Refactor, building walking skeletons, applying outside-in development, or sequencing tests for incremental design.
license: MIT
---

# Test-Driven Development

A discipline for growing software guided by tests, one small step at a time.

## When to Activate

Use this skill when:
- Writing code test-first for a new feature or module
- Starting a greenfield project and need a walking skeleton
- Applying outside-in development from acceptance tests to unit tests
- Sequencing tests to drive incremental design
- Creating a test list to plan implementation
- Reviewing whether tests are giving good design feedback
- Deciding between Fake It, Obvious Implementation, or Triangulation

## The TDD Cycle

### Five Steps

1. **Write a test list** — brainstorm the tests you think you'll need
2. **Write one failing test** — pick the next test from the list
3. **Make it pass** — write the simplest code that makes the test green
4. **Refactor** — remove duplication and improve design, keeping tests green
5. **Repeat** — pick the next test, update the list as you learn

### Red-Green-Refactor

The micro-cycle is a three-state machine:

```
    ┌──────────────────────────────────────┐
    │                                      │
    ▼                                      │
  [RED] ──── write minimal code ────► [GREEN] ──── refactor ────► [GREEN]
    ▲                                                                │
    │                                                                │
    └──────────── write next failing test ◄──────────────────────────┘
```

**RED**: Write a test that fails. Confirm it fails for the *right reason* — the missing behavior, not a syntax error or wrong import.

**GREEN**: Make the test pass with the simplest change possible. "Sinful" code is fine — hardcoded values, copy-paste, whatever gets green fastest.

**REFACTOR**: Clean up while all tests stay green. Remove duplication between test and production code. Improve names. Extract methods. This is where design emerges.

Rules:
- Never write production code without a failing test
- Never write more test code than needed to fail
- Never write more production code than needed to pass

### The Three Laws

Uncle Bob's formalization of Beck's constraints:

1. You shall not write production code unless you have a failing test
2. You shall not write more of a test than is sufficient to fail (including compile failures)
3. You shall not write more production code than is sufficient to pass the currently failing test

These laws enforce the micro-cycle. They keep steps small and feedback immediate.

## Test List

A test list is a brainstorm of all the tests you think you'll need, written *before* you start coding. It is your roadmap.

### How to Create One

1. Think about the behavior you need to implement
2. List the specific cases: happy path, edge cases, error cases
3. Order them from simplest to most complex
4. Start with a degenerate case if possible

### Example: Stack

```
Test List:
- [ ] new stack is empty
- [ ] push one item, stack is not empty
- [ ] push one item then pop, returns that item
- [ ] push two items then pop, returns second item
- [ ] pop empty stack raises error
- [ ] push and pop multiple items (LIFO order)
- [ ] peek returns top without removing
```

### When to Update

The test list is alive. As you work:
- Cross off completed tests
- Add new tests you discover along the way
- Remove tests that turn out to be redundant
- Reorder if a different sequence makes more sense

A test list can seed beads tasks — create one task per test with `skill:tdd` labels for tracking.

## Strategies for Getting to Green

Three strategies for making a failing test pass, in order of safety:

### Fake It

Return a hardcoded value that makes the test pass. Then write the next test to force generalization.

```
# Test: add(1, 2) returns 3
# Fake It:
def add(a, b):
    return 3

# Next test forces real implementation:
# Test: add(3, 4) returns 7
```

**When to use**: When you're unsure how to implement the real thing. When the step to real code feels too big. When you want maximum safety.

### Obvious Implementation

Type the real implementation directly, because it's clear what the code should be.

```
# Test: add(1, 2) returns 3
# Obvious Implementation:
def add(a, b):
    return a + b
```

**When to use**: When the implementation is trivially obvious. When you're confident. If you get an unexpected failure, *fall back to Fake It*.

### Triangulation

Use two or more test cases to force removal of hardcoded values and drive toward the general solution.

```
# Test 1: add(1, 2) returns 3
def add(a, b):
    return 3           # fake it

# Test 2: add(3, 4) returns 7
def add(a, b):
    return a + b       # now forced to generalize
```

**When to use**: When you're uncertain about the abstraction. When two examples make the pattern clearer than one. When you need confidence before generalizing.

## Test Sequencing

> "As tests get more specific, code gets more generic." — Robert C. Martin

Start with degenerate cases and progress toward forcing generalization:

1. **Degenerate/boundary cases** — null, empty, zero, one element
2. **Simple happy path** — the most basic successful case
3. **Variations** — different inputs that exercise the same path
4. **Edge cases** — boundaries, maximums, special values
5. **Error cases** — invalid input, missing data, failure conditions

Each new test should require a small, incremental change to the production code. If a test requires a large change, you skipped a step — find a simpler test to write first.

### Sequencing Example: FizzBuzz

```
Test List (ordered):
1. returns "1" for 1          → hardcode "1"
2. returns "2" for 2          → return string of number
3. returns "Fizz" for 3       → add modulo-3 check
4. returns "Fizz" for 6       → confirms generalization
5. returns "Buzz" for 5       → add modulo-5 check
6. returns "Buzz" for 10      → confirms generalization
7. returns "FizzBuzz" for 15  → add modulo-15 check
8. returns "FizzBuzz" for 30  → confirms generalization
```

## Double-Loop TDD

Freeman & Pryce's model from *Growing Object-Oriented Software, Guided by Tests*:

```
  Outer Loop (Acceptance Test)
  ┌──────────────────────────────────────────────────┐
  │                                                  │
  │  Write failing          Acceptance test passes   │
  │  acceptance test ──────────────────► Done         │
  │       │                      ▲                   │
  │       ▼                      │                   │
  │   Inner Loop (Unit Tests)    │                   │
  │   ┌────────────────────┐     │                   │
  │   │ RED → GREEN →      │     │                   │
  │   │ REFACTOR → repeat  │─────┘                   │
  │   └────────────────────┘                         │
  │                                                  │
  └──────────────────────────────────────────────────┘
```

**Outer loop**: Write a failing end-to-end acceptance test that describes the feature from the user's perspective. This test stays red while you build the internals.

**Inner loop**: Use the standard Red-Green-Refactor cycle to implement the components needed to make the acceptance test pass.

### Walking Skeleton

Start with the thinnest possible slice that exercises the full architecture:

1. Write a failing acceptance test for the simplest end-to-end scenario
2. Build just enough of each layer to make it pass — UI, service, persistence
3. Deploy the skeleton to a production-like environment
4. Every subsequent feature builds on this proven foundation

The walking skeleton proves your architecture works before you invest in features. It's the first acceptance test in the outer loop.

## Outside-In Development

Start at the system boundary and work inward, discovering collaborators through tests.

### The Process

1. **Start at the boundary** — write a test for the entry point (HTTP handler, CLI command, message consumer)
2. **Discover collaborators** — when the boundary object needs help, define an interface for the collaborator
3. **Test the collaborator** — drop down one level and TDD the collaborator
4. **Repeat inward** — each layer discovers the next through its tests
5. **Integrate** — wire real implementations together; the acceptance test goes green

### Tell, Don't Ask

Prefer commands over queries. Tell objects what to do rather than asking for data and acting on it:

```
# Ask (fragile — coupled to internal structure):
if order.status == "paid" and order.items_in_stock():
    warehouse.ship(order.items)

# Tell (robust — delegates to the object that knows):
order.fulfill(warehouse)
```

### Ports and Adapters

Separate domain logic from infrastructure for testability:

```
          ┌─────────────────────────┐
 HTTP ───►│ Adapter                 │
          │   └► Port (interface)   │
          │        └► Domain Logic  │
          │   ┌► Port (interface)   │
          │ Adapter                 │◄─── Database
          └─────────────────────────┘
```

- **Ports**: Interfaces defined by the domain (what it needs)
- **Adapters**: Implementations that connect to infrastructure (how it's provided)
- Tests can substitute adapters with test doubles, keeping tests fast and isolated

## Listen to the Tests

When tests are hard to write, they're telling you something about your design. Difficulty in testing is a symptom of a design problem.

| Difficulty Signal | Probable Design Issue | Suggested Refactoring |
|---|---|---|
| Test needs many objects to set up | Class has too many dependencies | Extract class, introduce facade |
| Test setup is deeply nested | Object graph is too complex | Flatten hierarchy, use composition |
| Hard to name the test | Method does too many things | Extract method, single responsibility |
| Test needs to access private state | Public interface is insufficient | Improve public API, add query method |
| Many tests break for one change | High coupling between classes | Introduce interface, dependency inversion |
| Slow tests (not integration) | Hidden I/O or expensive operations | Extract port/adapter, inject dependency |
| Test requires complex mocking | Violation of Law of Demeter | Wrap and delegate, tell don't ask |
| Test duplicates production logic | Missing abstraction | Extract shared concept |
| Can't test in isolation | Static calls, global state, `new` | Inject dependencies, use factory |

## Craftsmanship Principles

From the Software Craftsmanship Manifesto, applied to TDD:

- **Well-crafted software** — TDD produces code that works, is clean, and communicates intent
- **Steadily adding value** — each green test is a verified increment of working software
- **A community of professionals** — TDD is a shared discipline, not a personal preference
- **Productive partnerships** — tests document behavior for the team; they're a communication tool

TDD is a professional practice. Not every line of code requires it, but when you practice it, practice it with discipline. Half-hearted TDD (writing tests but skipping refactoring, or testing after the fact) delivers little of the benefit.

## Language Testing Skills

TDD teaches *when* and *why* to write tests. Language-specific skills teach *how* to use the testing framework. Load both when practicing TDD in a specific language.

| TDD Concept | Elixir (`elixir-testing`) | Rust (`rust`) | Zig (`zig`) |
|---|---|---|---|
| Write a failing test | `test "name" do ... end` | `#[test] fn name()` | `test "name" = \|\| { ... }` |
| Assertions | `assert`, `assert_receive` | `assert!`, `assert_eq!` | `try expect(...)` |
| Test isolation | `async: true`, sandbox | Module-level isolation | Test allocator |
| Test doubles | Mox for behaviours | Trait-based injection | Comptime interfaces |
| Property tests | StreamData | proptest, quickcheck | N/A |
| Test organization | `describe` blocks, tags | Module hierarchy, `#[cfg(test)]` | Nested test blocks |

## Anti-Patterns

### Test-After Development

Writing code first, tests second. You lose the design feedback loop — tests conform to the code rather than driving it. Tests become verification scripts, not design tools.

### Writing Too Many Tests Before Going Green

Writing five tests at once, then trying to make them all pass. You lose the tight feedback cycle and can't triangulate. Write one test, make it pass, then write the next.

### Skipping the Refactor Step

Going from green straight to the next test. Duplication accumulates. Design degrades. The codebase becomes harder to change, and TDD feels slower than it should. Refactoring is where TDD pays for itself.

### Testing Implementation Details

Testing *how* code works rather than *what* it does. Brittle tests that break when you refactor internals. Test behavior through the public interface.

### Gold-Plating (YAGNI)

Adding behavior not driven by a test. Adding tests for scenarios nobody asked for. If it's not on the test list and not an edge case you discovered, you ain't gonna need it.

### Ice Cream Cone

Many end-to-end tests, few unit tests. Invert the pyramid — most tests should be fast unit tests. End-to-end tests verify integration, not logic.

## References

For deeper theory and worked examples:
- `references/beck-tdd.md` — Kent Beck's canonical TDD: Fake It, Triangulation, test isolation
- `references/goos-outside-in.md` — Freeman & Pryce's GOOS: double-loop TDD, walking skeleton, outside-in design

## Key Principles

- Write the test first — always
- Keep steps small — if it feels like a leap, find a smaller step
- Red-Green-Refactor is a discipline, not a suggestion — never skip refactor
- The test list is your roadmap — update it as you learn
- Listen to the tests — difficulty testing signals design problems
- Fake It when unsure, Obvious Implementation when confident
- As tests get more specific, code gets more generic
- Walking skeleton first — prove the architecture before building features
- Outside-in discovers interfaces — let tests drive the design inward
- TDD is about design, not just verification
