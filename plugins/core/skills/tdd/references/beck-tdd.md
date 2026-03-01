# Beck's Canonical TDD

Deep-dive into Kent Beck's *Test-Driven Development by Example* — the foundational text on TDD practice.

## The Test List in Depth

The test list is the bridge between requirements and code. Before writing any code, brainstorm all the tests you can think of for the behavior you're about to implement.

### From User Stories to Tests

A user story describes *what* the user wants. The test list describes *how* you'll verify it:

```
User Story: "As a user, I can transfer money between accounts"

Test List:
- [ ] transfer $100 from account with $500, sender has $400
- [ ] transfer $100 from account with $500, receiver gets $100 more
- [ ] transfer full balance leaves sender at $0
- [ ] transfer more than balance is rejected
- [ ] transfer $0 is rejected
- [ ] transfer negative amount is rejected
- [ ] transfer between same account is rejected
- [ ] transfer updates both accounts atomically
```

### Test List Heuristics

- **Start with the simplest happy path** — the one that requires the least code
- **Add boundary cases** — zero, one, empty, maximum
- **Add error cases** — what should be rejected or fail
- **Group related tests** — they often share setup
- **Don't aim for completeness** — you'll discover more tests as you go

## Fake It Till You Make It

Fake It is the safest strategy for getting to green. Return a constant, then let the next test force generalization.

### Worked Example: Currency Multiplication

```
# Test 1: 5 CHF * 2 = 10 CHF
def test_multiplication():
    five = Money(5, "CHF")
    result = five.times(2)
    assert result.amount == 10

# Fake It:
class Money:
    def __init__(self, amount, currency):
        self.amount = amount
        self.currency = currency

    def times(self, multiplier):
        return Money(10, self.currency)    # hardcoded!
```

```
# Test 2: 5 CHF * 3 = 15 CHF
def test_multiplication_by_three():
    five = Money(5, "CHF")
    result = five.times(3)
    assert result.amount == 15

# Now we're forced to generalize:
class Money:
    def times(self, multiplier):
        return Money(self.amount * multiplier, self.currency)
```

```
# Test 3: 7 CHF * 3 = 21 CHF
def test_different_amount():
    seven = Money(7, "CHF")
    result = seven.times(3)
    assert result.amount == 21

# Passes immediately — our generalization works
# Cross off the test and move on
```

### Why Fake It Works

1. **Guaranteed green** — you know the test will pass because you hardcoded the answer
2. **Small steps** — each change is tiny and verifiable
3. **Forces the next test** — you must write another test to remove the fake
4. **Builds confidence** — each passing test is proof of progress

## Triangulation in Practice

Triangulation means writing two or more test cases before generalizing. When you have multiple specific examples, the general pattern becomes clear.

### When to Use Triangulation

- When you're unsure what the abstraction should be
- When the generalization isn't obvious from one example
- When you want extra confidence before generalizing

### Example: Equality

```
# Test 1: same amount and currency are equal
def test_equality():
    assert Money(5, "CHF") == Money(5, "CHF")

# Fake It:
class Money:
    def __eq__(self, other):
        return True    # faked!
```

```
# Test 2: different amounts are not equal
def test_inequality_amount():
    assert Money(5, "CHF") != Money(6, "CHF")

# First triangulation point — need to check amount:
class Money:
    def __eq__(self, other):
        return self.amount == other.amount    # partially generalized
```

```
# Test 3: different currencies are not equal
def test_inequality_currency():
    assert Money(5, "CHF") != Money(5, "USD")

# Second triangulation point — need to check currency too:
class Money:
    def __eq__(self, other):
        return (self.amount == other.amount and
                self.currency == other.currency)    # fully generalized
```

Each test forced a refinement. No single test was enough to drive the full implementation — that's the value of triangulation.

## Obvious Implementation

When the code is trivially clear, skip the fake and write the real implementation directly.

```
# Test: adding two positive numbers
def test_add():
    assert add(2, 3) == 5

# Obvious Implementation (no need to fake this):
def add(a, b):
    return a + b
```

### Risk Assessment

Obvious Implementation is faster but riskier:
- **Use it when**: The code is trivial, you've written similar code many times, you're confident
- **Fall back when**: You get an unexpected red, the implementation is longer than a few lines, or you're in unfamiliar territory
- **The rule**: If Obvious Implementation gives you a red you didn't expect, *fall back to Fake It immediately*

## The Milli-Cycle

> "As tests get more specific, code gets more generic."

This is Beck's key insight about the relationship between tests and production code. Each specific test case drives the code toward a more general solution:

```
Test: "1" → returns 1       Code: return 1
Test: "2" → returns 2       Code: return int(input)
Test: "1,2" → returns 3     Code: return sum(int(x) for x in input.split(","))
Test: "" → returns 0        Code: if not input: return 0; ...
Test: "1\n2,3" → returns 6  Code: return sum(int(x) for x in re.split("[,\n]", input))
```

Each test adds a specific constraint. The code responds by becoming more general.

## The Three Laws — Detailed Rationale

### Law 1: No production code without a failing test

**Why**: Every line of production code exists because a test demanded it. No code exists "just in case" or "for completeness." This prevents gold-plating and YAGNI violations.

### Law 2: No more test code than needed to fail

**Why**: Keep the test small so the failure message is precise. A test that checks five things at once gives unclear feedback. A test that checks one thing tells you exactly what's broken.

### Law 3: No more production code than needed to pass

**Why**: Resist the urge to write the "full" implementation. Write only what the current test demands. The next test will demand more. This keeps you in the tight feedback loop.

## Test Isolation and Independence

Each test must:
- **Set up its own state** — no reliance on other tests having run first
- **Clean up after itself** — no side effects that affect other tests
- **Be runnable in any order** — shuffling test order shouldn't break anything
- **Be runnable alone** — extracting a single test to run should work

### Shared Setup vs. Independence

Shared setup (before-each, fixtures) is fine for reducing duplication, but every test must be understandable in isolation. If you need to read three other tests to understand what one test does, extract the setup into a descriptively-named helper.

## When TDD Feels Wrong

Sometimes TDD feels slow, painful, or forced. This is signal, not noise:

| What Feels Wrong | What It Might Mean |
|---|---|
| "I can't figure out what test to write first" | The requirements are unclear — clarify before coding |
| "Setting up the test is harder than writing the code" | Too many dependencies — simplify the design |
| "I need to test a private method" | The class is doing too much — extract a collaborator |
| "My tests break every time I refactor" | Tests are coupled to implementation — test behavior, not structure |
| "TDD feels slow for this" | Maybe it's simple enough for Obvious Implementation — or maybe you're fighting the design |
| "I wrote the code first and now I can't test it" | The code wasn't designed for testability — use outside-in next time |
| "I need a database / network for every test" | Missing ports and adapters — inject dependencies |

When TDD feels wrong, the answer is almost never "skip TDD." The answer is usually "change the design."
