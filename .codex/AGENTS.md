# Github interactions

when interacting with github, you may be on a VM with different access permissions. `gh` command should always work. The github connection often won't. Prefer gh cli.

# jira interactions

If I tell you to interact with jira, use the acli cli tool. Only interact with jira when I tell you, do not make updates to jira unless explicitly asked.


# Testing / Coding Best Practices

These principles apply across languages. The exact syntax and patterns differ between Go, TypeScript, Python, Rust, Java, Ruby, and other languages, but the goal is the same: keep important behavior easy to test, easy to reason about, and separate from external side effects.

## Core Principle

Keep as much logic as possible in pure functions, small classes, or deterministic modules.

Push side effects to the edges of the system. Side effects include:

- Network calls
- Database reads/writes
- Filesystem access
- Environment variables
- Timers and clocks
- Randomness
- Logging
- Process/global state
- Framework-specific APIs

Core business logic should usually accept plain inputs and return plain outputs. Boundary code should handle I/O and call into that core logic.

If a function is hard to test without extensive mocks, that is usually a design smell. Consider extracting pure logic, passing dependencies explicitly, or moving side effects outward.

## Testing Pyramid

Most tests should cover functional logic. Fewer tests should cover integration boundaries. End-to-end tests should be used sparingly for critical user flows.

1. **Pure / functional tests**
   - These should make up most of the test suite.
   - Test edge cases heavily.
   - Cover empty inputs, invalid inputs, boundary values, duplicates, ordering, malformed data, null/undefined/nil cases, and error paths.
   - These tests should be fast, deterministic, and easy to read.

2. **Integration tests**
   - Use these to verify that multiple components work together.
   - Cover database queries, API handlers, persistence, routing, serialization, queues, and boundary adapters.
   - Prefer realistic fakes or test containers over excessive mocks when practical.

3. **End-to-end tests**
   - These should have the least coverage.
   - Use them to ensure critical flows work in concert.
   - Cover high-value paths like login, checkout, publishing, account setup, or key CRUD flows.
   - Do not use E2E tests to exhaustively test business logic.

Code should be structured so tests naturally fall into this pyramid. If too much behavior can only be tested through integration or E2E tests, consider moving more logic into pure functions or deterministic modules.

## Dependency Injection Over Hidden Side Effects

When side effects are needed, inject them explicitly as callbacks, interfaces, function arguments, or constructor parameters.

Avoid mocks wherever possible. Prefer:

- Pure function tests
- Real data structures
- Lightweight fakes
- In-memory implementations
- Small test-specific callbacks

Use mocks only when the alternative would be slow, brittle, nondeterministic, or require an external service.

## TypeScript Example

Prefer this:

```ts
type CartItem = {
  price: number;
  quantity: number;
};

export function calculateTotal(items: CartItem[], taxRate: number): number {
  const subtotal = items.reduce((sum, item) => {
    return sum + item.price * item.quantity;
  }, 0);

  return subtotal * (1 + taxRate);
}

type ChargePayment = (input: {
  customerId: string;
  amount: number;
}) => Promise<{ paymentId: string }>;

export async function checkout(
  cart: {
    customerId: string;
    items: CartItem[];
    taxRate: number;
  },
  chargePayment: ChargePayment,
) {
  const amount = calculateTotal(cart.items, cart.taxRate);

  return chargePayment({
    customerId: cart.customerId,
    amount,
  });
}
```

This lets most tests focus on `calculateTotal`:

```ts
import { calculateTotal } from "./checkout";

test("calculates total with tax", () => {
  expect(
    calculateTotal(
      [
        { price: 10, quantity: 2 },
        { price: 5, quantity: 1 },
      ],
      0.1,
    ),
  ).toBe(27.5);
});

test("returns zero for an empty cart", () => {
  expect(calculateTotal([], 0.1)).toBe(0);
});
```

Then test the side-effect boundary with a simple fake callback:

```ts
import { checkout } from "./checkout";

test("charges the customer for the calculated amount", async () => {
  const calls: unknown[] = [];

  const fakeChargePayment = async (input: {
    customerId: string;
    amount: number;
  }) => {
    calls.push(input);
    return { paymentId: "payment_123" };
  };

  const result = await checkout(
    {
      customerId: "customer_123",
      items: [{ price: 20, quantity: 2 }],
      taxRate: 0.25,
    },
    fakeChargePayment,
  );

  expect(result).toEqual({ paymentId: "payment_123" });
  expect(calls).toEqual([
    {
      customerId: "customer_123",
      amount: 50,
    },
  ]);
});
```

Avoid this:

```ts
async function checkout(cart: Cart) {
  const taxRate = Number(process.env.TAX_RATE);
  const amount =
    cart.items.reduce((sum, item) => {
      return sum + item.price * item.quantity;
    }, 0) *
    (1 + taxRate);

  return paymentProvider.charge(cart.customerId, amount);
}
```

This version mixes business logic, environment access, and payment I/O in one place, making it harder to test without mocks or global setup.

## Go Example

Prefer this:

```go
package checkout

type CartItem struct {
	Price    int
	Quantity int
}

func CalculateTotal(items []CartItem, taxRate float64) float64 {
	subtotal := 0

	for _, item := range items {
		subtotal += item.Price * item.Quantity
	}

	return float64(subtotal) * (1 + taxRate)
}

type ChargePayment func(input PaymentInput) (PaymentResult, error)

type PaymentInput struct {
	CustomerID string
	Amount     float64
}

type PaymentResult struct {
	PaymentID string
}

type Cart struct {
	CustomerID string
	Items      []CartItem
	TaxRate    float64
}

func Checkout(cart Cart, chargePayment ChargePayment) (PaymentResult, error) {
	amount := CalculateTotal(cart.Items, cart.TaxRate)

	return chargePayment(PaymentInput{
		CustomerID: cart.CustomerID,
		Amount:     amount,
	})
}
```

Pure function tests stay simple:

```go
package checkout

import "testing"

func TestCalculateTotal(t *testing.T) {
	tests := []struct {
		name    string
		items   []CartItem
		taxRate float64
		want    float64
	}{
		{
			name: "calculates total with tax",
			items: []CartItem{
				{Price: 10, Quantity: 2},
				{Price: 5, Quantity: 1},
			},
			taxRate: 0.10,
			want:    27.5,
		},
		{
			name:    "empty cart",
			items:   nil,
			taxRate: 0.10,
			want:    0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := CalculateTotal(tt.items, tt.taxRate)
			if got != tt.want {
				t.Fatalf("CalculateTotal() = %v, want %v", got, tt.want)
			}
		})
	}
}
```

Side effects can be injected with a function:

```go
package checkout

import "testing"

func TestCheckoutChargesCalculatedAmount(t *testing.T) {
	var gotInput PaymentInput

	fakeChargePayment := func(input PaymentInput) (PaymentResult, error) {
		gotInput = input
		return PaymentResult{PaymentID: "payment_123"}, nil
	}

	result, err := Checkout(Cart{
		CustomerID: "customer_123",
		Items: []CartItem{
			{Price: 20, Quantity: 2},
		},
		TaxRate: 0.25,
	}, fakeChargePayment)

	if err != nil {
		t.Fatalf("Checkout() returned error: %v", err)
	}

	if result.PaymentID != "payment_123" {
		t.Fatalf("PaymentID = %q, want %q", result.PaymentID, "payment_123")
	}

	if gotInput.CustomerID != "customer_123" {
		t.Fatalf("CustomerID = %q, want %q", gotInput.CustomerID, "customer_123")
	}

	if gotInput.Amount != 50 {
		t.Fatalf("Amount = %v, want %v", gotInput.Amount, 50)
	}
}
```

Avoid this:

```go
func Checkout(cart Cart) (PaymentResult, error) {
	taxRate, _ := strconv.ParseFloat(os.Getenv("TAX_RATE"), 64)

	subtotal := 0
	for _, item := range cart.Items {
		subtotal += item.Price * item.Quantity
	}

	amount := float64(subtotal) * (1 + taxRate)

	client := payment.NewClient(os.Getenv("PAYMENT_API_KEY"))
	return client.Charge(cart.CustomerID, amount)
}
```

This mixes calculation, environment access, client construction, and network I/O. It is harder to test and easier to break.

## General Guidelines

- Keep functions small enough that their behavior can be named and tested clearly.
- Separate decision-making from execution.
- Separate data transformation from I/O.
- Prefer explicit inputs over implicit globals.
- Prefer return values over mutation when practical.
- Make error cases first-class and test them.
- Keep tests readable; the test name and assertions should explain the behavior.
- Avoid testing implementation details unless the implementation itself is the contract.
- Favor deterministic tests. Control time, randomness, concurrency, and external state.
- Add regression tests for bugs before or alongside fixes.
- If test setup becomes complex, consider whether the production code has too many responsibilities.
