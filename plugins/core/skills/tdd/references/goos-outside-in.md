# Growing Object-Oriented Software, Guided by Tests

Deep-dive into Freeman & Pryce's approach to TDD — outside-in development, walking skeletons, and using tests as a design tool.

## Double-Loop TDD — Detailed

The double loop separates *what* the system should do (outer) from *how* it does it (inner).

```
  Feature Request
       │
       ▼
  ┌─────────────────────────────────────────────────────┐
  │  OUTER LOOP: Acceptance Test                        │
  │                                                     │
  │  Write failing acceptance test                      │
  │       │                                             │
  │       ▼                                             │
  │  ┌─────────────────────────────────────────────┐    │
  │  │  INNER LOOP: Unit Tests                     │    │
  │  │                                             │    │
  │  │  ┌───► RED (write failing unit test)        │    │
  │  │  │          │                               │    │
  │  │  │          ▼                               │    │
  │  │  │     GREEN (make it pass)                 │    │
  │  │  │          │                               │    │
  │  │  │          ▼                               │    │
  │  │  │     REFACTOR (clean up)                  │    │
  │  │  │          │                               │    │
  │  │  │          ▼                               │    │
  │  │  └──── more unit tests needed? ─── yes ─┘  │    │
  │  │              │ no                           │    │
  │  └──────────────┼──────────────────────────────┘    │
  │                 ▼                                    │
  │         Acceptance test passes?                     │
  │              │ no ──► back to inner loop             │
  │              │ yes                                   │
  │              ▼                                       │
  │         Feature complete                             │
  └─────────────────────────────────────────────────────┘
```

### Outer Loop: Acceptance Tests

- Written from the **user's perspective** — they describe behavior, not implementation
- Exercise the **full system** — from entry point through to output
- Stay **red** while you build — they're the goal, not the guide
- Provide a **definition of done** — when the acceptance test goes green, the feature is complete

### Inner Loop: Unit Tests

- Written from the **developer's perspective** — they describe object responsibilities
- Exercise **individual components** — fast, isolated, focused
- Follow **Red-Green-Refactor** — the standard TDD micro-cycle
- **Discover collaborators** — when a unit needs help, define an interface

### Worked Example: Notification Service

Outer loop (acceptance test):
```
test "user receives email when order ships":
    place_order(user, item)
    ship_order(order_id)
    assert_email_received(user.email, subject: "Your order has shipped")
```

Inner loop iteration 1 — shipping service:
```
test "ship_order marks order as shipped":
    order = create_order(status: "paid")
    shipping_service.ship(order)
    assert order.status == "shipped"
```

Inner loop iteration 2 — notification:
```
test "ship_order triggers notification":
    notifier = mock(Notifier)
    shipping_service = ShippingService(notifier)
    shipping_service.ship(order)
    assert notifier.received(:send_shipment_notification, order)
```

Inner loop iteration 3 — email notifier:
```
test "email notifier sends shipment email":
    mailer = mock(Mailer)
    notifier = EmailNotifier(mailer)
    notifier.send_shipment_notification(order)
    assert mailer.received(:send, to: order.email, subject: "Your order has shipped")
```

Wire it together → acceptance test goes green.

## Walking Skeleton

A walking skeleton is the thinnest possible end-to-end slice that exercises your full architecture.

### Why It Matters

- **Proves the architecture** — before investing in features, verify all layers connect
- **Reduces integration risk** — find deployment and wiring issues on day one
- **Provides a deployment pipeline** — the skeleton needs to build, test, and deploy
- **Creates a foundation** — every subsequent feature adds flesh to the skeleton

### Steps to Create One

1. **Pick the simplest end-to-end scenario** — "user can see empty list" rather than "user can search and filter with pagination"
2. **Write a failing acceptance test** for that scenario
3. **Implement the thinnest slice through every layer**:
   - Entry point (HTTP route, CLI command)
   - Application logic (even if it just returns empty)
   - Persistence (even if it's in-memory)
   - Output (even if it's minimal JSON)
4. **Deploy to a production-like environment**
5. **Verify the acceptance test passes end-to-end**

### Skeleton Test as First Acceptance Test

```
test "GET /todos returns empty list":
    response = http_get("/todos")
    assert response.status == 200
    assert response.body == []
```

This simple test forces you to:
- Set up an HTTP server
- Define a route
- Connect to a data store
- Return a response
- Have a working test harness

That's a full architectural spike disguised as a trivial test.

## Outside-In Design

### Start at the Boundary

The boundary is where the system meets the outside world. Start your tests there and work inward:

```
Boundary (test starts here)
  │
  ├── HTTP Handler
  │     └── Application Service
  │           ├── Domain Object
  │           └── Repository (interface)
  │                 └── Database Adapter (test double in tests)
  │
  └── Output
```

### Discover Interfaces Through Collaborator Questions

When testing an object, ask: "What does this object need to do its job?"

The answer defines an interface for a collaborator:

```
# Testing the OrderController — what does it need?
# Answer: Something that can process orders → OrderService interface

test "POST /orders creates an order":
    order_service = mock(OrderService)
    controller = OrderController(order_service)

    controller.handle_post(item: "widget", qty: 3)

    assert order_service.received(:create_order, item: "widget", qty: 3)
```

Now drop down and TDD the OrderService:

```
# Testing OrderService — what does it need?
# Answer: Something that can save orders → OrderRepository interface

test "create_order saves order to repository":
    repo = mock(OrderRepository)
    service = OrderService(repo)

    service.create_order(item: "widget", qty: 3)

    assert repo.received(:save, order_with(item: "widget", qty: 3))
```

Each layer discovers the next through its tests.

## Ports and Adapters for Testability

### Separating Domain from Infrastructure

The domain defines **ports** — interfaces that describe what it needs. Infrastructure provides **adapters** — implementations that connect to real systems.

```
┌──────────────────────────────────────────────┐
│                  Domain                       │
│                                              │
│  OrderService                                │
│    needs: OrderRepository (port)             │
│    needs: PaymentGateway (port)              │
│    needs: Notifier (port)                    │
│                                              │
├──────────────────────────────────────────────┤
│               Adapters                        │
│                                              │
│  PostgresOrderRepository (implements port)    │
│  StripePaymentGateway (implements port)       │
│  EmailNotifier (implements port)              │
│                                              │
├──────────────────────────────────────────────┤
│             Test Doubles                      │
│                                              │
│  InMemoryOrderRepository (implements port)    │
│  FakePaymentGateway (implements port)         │
│  MockNotifier (implements port)               │
│                                              │
└──────────────────────────────────────────────┘
```

### Test Through Ports

- Unit tests inject test doubles through the same ports as production adapters
- The domain never knows whether it's talking to Postgres or an in-memory store
- Swapping adapters requires zero changes to domain code or tests

## Tell, Don't Ask

Prefer telling objects what to do over querying their state and acting on it.

### Ask (Fragile)

```
# Controller queries order, makes decisions, calls warehouse
order = repo.find(order_id)
if order.status == "paid":
    items = order.line_items()
    for item in items:
        if warehouse.in_stock(item.sku, item.qty):
            warehouse.reserve(item.sku, item.qty)
        else:
            raise OutOfStock(item.sku)
    order.set_status("fulfilled")
    repo.save(order)
```

Problems: controller knows too much about order internals, warehouse mechanics, and the fulfillment process.

### Tell (Robust)

```
# Controller tells order to fulfill itself with the warehouse
order = repo.find(order_id)
order.fulfill(warehouse)
repo.save(order)
```

Benefits: order encapsulates its own fulfillment logic, controller is thin, easy to test each piece independently.

### Why This Matters for TDD

Tell Don't Ask produces objects with clear responsibilities that are easy to test in isolation. Ask-style code produces tests that set up complex state, assert on internal details, and break when internals change.

## Role-Based Interfaces

Name interfaces by the *role* they play, not the implementation they use:

```
# By implementation (fragile):
PostgresDatabase
SmtpEmailSender
StripeCharger

# By role (stable):
OrderRepository
Notifier
PaymentGateway
```

Role-based names:
- Make tests read like specifications
- Survive implementation changes
- Encourage substitutability
- Focus on behavior, not technology

## Test Doubles and Their Roles

| Double | Purpose | When to Use |
|---|---|---|
| **Stub** | Returns predetermined data | When you need to control indirect inputs |
| **Mock** | Verifies expected interactions | When you need to verify an object sends the right messages |
| **Fake** | Working implementation (simplified) | When you need realistic behavior without infrastructure (e.g., in-memory database) |
| **Spy** | Records calls for later verification | When you want to verify after the fact without setting expectations upfront |

### Choosing the Right Double

- **Default to stubs** for most collaborators — control inputs, don't assert on them
- **Use mocks sparingly** — only for interactions that are the *purpose* of the object under test
- **Use fakes for integration** — when you need realistic behavior in integration tests
- **Avoid mocking types you don't own** — wrap third-party code behind your own interface, then mock the wrapper

## Listening to the Tests: Design Feedback Catalog

Tests are a design tool. When they're hard to write, they're showing you a design problem.

### Setup Difficulty

| Symptom | Design Issue | Refactoring |
|---|---|---|
| Too many constructor parameters | Class has too many responsibilities | Extract class, apply SRP |
| Deep object graph to construct | Tight coupling, missing abstractions | Introduce factory, builder, or facade |
| Need to set many fields before acting | Object has too much state | Break into smaller objects with less state |
| Complex test fixtures | Missing domain concepts | Extract value objects, introduce aggregates |

### Assertion Difficulty

| Symptom | Design Issue | Refactoring |
|---|---|---|
| Asserting on internal state | Insufficient public interface | Add query methods, improve API |
| Asserting on many values at once | Method returns too much / does too much | Split method, return value objects |
| Expected values are hard to compute | Logic is complex or unclear | Extract named calculations, simplify |
| Need test-only accessors | Design doesn't expose needed information | Reconsider the public contract |

### Structural Difficulty

| Symptom | Design Issue | Refactoring |
|---|---|---|
| Can't test without a database | Domain coupled to infrastructure | Introduce port/adapter, inject dependency |
| Static method calls block testing | Hidden dependencies | Convert to instance methods with injection |
| Global state causes test interference | Shared mutable state | Make state explicit, pass through constructor |
| Circular dependencies in test setup | Circular coupling in production code | Break cycle with interface or events |

### Maintenance Difficulty

| Symptom | Design Issue | Refactoring |
|---|---|---|
| Many tests break for one change | Feature envy, high coupling | Move behavior closer to data, add interfaces |
| Tests duplicate production logic | Missing abstraction | Extract shared concept into named method |
| Tests are hard to read | Poor naming, missing helpers | Extract test helpers, improve names |
| Tests are slow | Hidden I/O, missing boundaries | Introduce seams, separate fast and slow tests |
