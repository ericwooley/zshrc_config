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

# Important Rules

- Never merge a PR unless I explicitly tell you too. You can and should commit frequently, you may push to update a PR or whatever if the context allows, but do NOT MERGE THINGS, unless I explicitly tell you too.
- Do not start a CODEX SECURITY SCAN unless i explicitly ask for a codex security scan. Sometimes i ask you to check for security of something. That means i want you to investigate it manually, not a codex security scan.
- Do not user the gh integration for anything other than pushing or pulling unless explicitly asked to do so. EG do not open PR's or clone another repo, or make pull requests on things I don't ask you to make.
- If I previously asked you to open a PR and you opened it, treat my later feedback
  on that work as authorization to update the same open PR. Follow the plan,
  checkpoint, commit, checkpoint-review, and final group-review processes below,
  then push the changes to the PR's branch without waiting for a separate
  request. Do not open a replacement PR or merge the existing PR unless I
  explicitly ask.
- On comments and interactions in gh, prefix your comment with `AI: <whatever comment you want to make>` so I can tell which comments are from you
- Whenever you are fixing a bug, use red green testing
- You are typically going to be logged into github as a second user that is not my primary account. A secondary account. You should never make changes or configure settings unless I tell you to. And even then, you probably can't. Tell me what settings to change and I'll do it. If I tell you to explicitly you may have access so check first.

# Planning, checkpoints, and reviewing your code

- For every task that changes tracked files, create a working plan before
  editing. Break the work into outcome-oriented checkpoints that can be
  implemented, tested, committed, and reviewed as coherent units. Keep the plan
  current as work progresses. A small task may have one checkpoint; do not
  invent artificial checkpoints or split implementation from its tests and
  required documentation.
- Record the task's starting commit before making changes. At each checkpoint:
  1. finish the checkpoint's implementation, tests, and required documentation;
  2. run the relevant validation and inspect the complete diff and repository
     status;
  3. stage only the intended files and create a scoped checkpoint commit;
  4. launch a dedicated code-review subagent to adversarially review both the
     exact checkpoint commit range and its effect on the cumulative task; and
  5. wait for a `ready` verdict before beginning the next checkpoint.
- Do not include unrelated or pre-existing worktree changes in a checkpoint
  commit. If the requested work cannot be isolated safely, stop and explain the
  overlap instead of committing someone else's changes.
- Do not use Claude or invoke the Codex CLI for code review.
- Tell the review subagent to read and follow
  `.codex/prompts/code-review.md`, or
  `.codex/prompts/bug-fix-review.md` when fixing a bug. The checkpoint reviewer
  must also read `.codex/prompts/reviewers/senior-engineer.md`. Resolve both
  prompt paths from `${ZSHRC_CONFIG_DIR:-$HOME/.zshrc_config}` and pass their
  absolute paths to the subagent so they are available while working in any
  repository.
- Include the exact instructions I gave you in the subagent task under
  `Original user request (verbatim)`. Do not paraphrase them. Include the
  current plan and checkpoint, the task-start commit, the exact checkpoint
  commit range, the cumulative task range, validation performed, and unresolved
  concerns. For bug fixes, also include the exact test command, the failing
  output from before the fix, and the passing output after the fix.
- Give the subagent a review task that is read-only with respect to repository
  source and tracked files, commits, pushes, and production or shared external
  state. It may inspect the repository, run relevant tests, start disposable
  local services, operate a browser against a development environment, write
  temporary files outside the repository, and create and clean up a review VM
  only under the applicable common prompt's safety rules.
- Resolve every actionable finding yourself, rerun the relevant tests, and
  create a new scoped fix commit. Launch a fresh review subagent against the
  original checkpoint base through the new `HEAD`, as well as the cumulative
  task range. Repeat this fix, commit, and re-review loop until the reviewer
  returns a `ready` verdict. Do not ask the review subagent to implement its own
  findings.
- The reusable prompts already require review of all copy as
  customer/consumer-centric language that does not leak business logic or
  technical requirements and does not describe what the product does not do.
  Write copy this way yourself; do not rely on the review to catch it.

# Final specialist group review

- Once all implementation checkpoints are individually `ready` and you believe
  the feature or request is complete, freeze the task range and run a final
  specialist group review before declaring the task done or pushing it.
- Every group-review pass must use one fresh subagent for every specialist role
  below, with the same source-repository and shared-state read-only boundary
  defined above. Run them sequentially, one at a time, and wait for each to
  finish. Choose and record the order by relevance to the actual risk, with the
  most relevant specialist first. The review lead is always last.
  - Senior engineer:
    `.codex/prompts/reviewers/senior-engineer.md`
  - Product/project reviewer:
    `.codex/prompts/reviewers/product-project.md`
  - Test/reliability engineer:
    `.codex/prompts/reviewers/test-reliability.md`
  - Maintainability/integration engineer:
    `.codex/prompts/reviewers/maintainability-integration.md`
  - Security specialist:
    `.codex/prompts/reviewers/security.md`
  - Designer/UX reviewer:
    `.codex/prompts/reviewers/designer-ux.md`
  - Review lead:
    `.codex/prompts/reviewers/review-lead.md`
- Examples of relevance ordering:
  - authentication or authorization: security first;
  - user-interface or interaction work: designer/UX first;
  - test infrastructure or flaky behavior: test/reliability first;
  - dependency, API, migration, or cross-component work:
    maintainability/integration first.
- Every specialist subagent must read the applicable common review prompt and
  its role prompt. Resolve every common and role prompt from
  `${ZSHRC_CONFIG_DIR:-$HOME/.zshrc_config}` and pass the absolute paths to the
  subagent; do not assume the current repository contains `.codex/prompts`.
  Give each the exact original request, plan, task-start commit, frozen task
  range and `HEAD`, validation evidence, relevant run instructions, and
  unresolved concerns. Tell it which numbered position it occupies in the
  chosen review order.
- Keep specialist reviews independent: do not give a specialist the earlier
  specialists' reports, and do not change the code or reviewed `HEAD` between
  specialist reviews. Give the review-lead subagent every specialist report
  verbatim, the chosen ordering and rationale, and the same frozen task
  context.
- Reviewers must use the relevant tools available to them rather than limiting
  themselves to a diff when runtime evidence is practical. This may include
  repository inspection, focused tests, builds, linters, a local application,
  browser or Chrome control, screenshots, and a disposable Multipass VM. The
  role prompts define the expected tool use and VM safety rules. A tool or
  environment limitation must be reported as an explicit verification gap.
- This is a manual specialist review workflow. Do not start a Codex Security
  Scan unless I explicitly ask for one.
- The group passes only when the review lead returns `ready` with no unresolved
  actionable findings. Do not use majority vote. Resolve accepted findings
  yourself, rerun relevant validation, and create a scoped fix checkpoint
  commit. Then freeze the new `HEAD` and repeat the full specialist group with
  a fresh subagent for every role, including the review lead, so every verdict
  covers the same final code without carrying conclusions from the earlier
  pass.
- You may skip the final specialist group only for a clearly trivial fix or
  minor request. Record the concrete low-risk reason and validation evidence in
  the plan and final response. Treat changes involving authentication,
  authorization, security or privacy boundaries, persistent data or migrations,
  dependencies, public APIs, deployment or CI, concurrency, user-facing
  behavior or copy, or UI interactions as presumptively nontrivial. A genuinely
  minor localized correction, such as a typo-only label change with no behavior,
  workflow, state, contract, or accessibility effect, may still use the
  exemption when that reasoning is documented. Material changes in the listed
  categories may not skip the group. When uncertain, run the group.
- Follow-up changes based on my feedback to an open PR use the same plan,
  checkpoint, and group-review process. Once the final group review is `ready`,
  commit and push those changes to the existing PR branch without waiting for a
  separate push request. Do not push any change that has not passed the required
  review process, and do not open a replacement PR or merge unless I explicitly
  ask.

# Designing with Claude

- Use Claude only for design and UI prototype work. Never use Claude for code
  review.
- Use exactly one Claude session for the lifespan of each Codex conversation.
  When the conversation first needs Claude for design work, generate one UUID
  with `uuidgen | tr '[:upper:]' '[:lower:]'` and remember that exact value.
  Use `--session-id <uuid>` for the first successful Claude request. Use
  `--resume <uuid>` for every later Claude design request in the same Codex
  conversation. Do not generate a second UUID or reuse the UUID in another
  Codex conversation.
- A Claude usage or quota failure does not advance this lifecycle. If no Claude
  request has succeeded yet, keep using `--session-id` when Claude becomes
  available. If Claude reports that the UUID is already in use, switch to
  `--resume` with that same UUID instead of generating a new one. If a previous
  request succeeded, keep using `--resume`. The Codex prototype fallback does
  not create or resume the Claude session.

- When you are doing design tasks, use
  `.codex/prompts/ui-prototypes.md` with the write-scoped pattern below. Include
  the exact original request and the same `tmp/prototypes/<idea>` destination in
  the appended context and `prototype_dir`. Review the resulting pure HTML
  options before using any of them. When in doubt, ask me which prototype I
  prefer.

```sh
(
  claude_prompt_file="${ZSHRC_CONFIG_DIR:-$HOME/.zshrc_config}/.codex/prompts/ui-prototypes.md"
  claude_session_id="<same UUID used throughout this Codex conversation>"
  claude_session_flag="<--session-id for the first Claude request; --resume afterward>"
  prototype_dir="tmp/prototypes/<idea>"

  case "$claude_session_flag" in
    --session-id|--resume) ;;
    *)
      printf 'Set claude_session_flag to --session-id or --resume\n' >&2
      exit 1
      ;;
  esac

  if [ ! -r "$claude_prompt_file" ]; then
    printf 'Claude prototype prompt not found: %s\n' "$claude_prompt_file" >&2
    exit 1
  fi

  mkdir -p "$prototype_dir" || exit 1

  {
    cat "$claude_prompt_file"
    cat <<'CLAUDE_PROTOTYPE_CONTEXT_EOF'

## Task-specific context

### Original user request (verbatim)

<exact instructions from the user>

### Prototype directory

<exact tmp/prototypes/<idea> path matching prototype_dir>

### Agent notes

<existing UI context, relevant constraints, and unresolved design choices>
CLAUDE_PROTOTYPE_CONTEXT_EOF
  } | claude -p --model claude-sonnet-5 \
    "$claude_session_flag" "$claude_session_id" \
    --permission-mode auto \
    --allowedTools \
      'Read' \
      'Grep' \
      'Glob' \
      "Edit(./${prototype_dir}/**)"
)
```

For a Claude usage or quota failure during prototype generation, keep the
prototype prompt content unchanged except for converting the `Prototype
directory` field and any repository paths in the agent notes to absolute paths.
Replace the complete `claude ...` pipeline command with the command below.
`-C "$prototype_dir"` makes the prototype directory the fallback workspace;
keep all requested writes there.

```sh
codex -a never exec --ephemeral -C "$prototype_dir" -m gpt-5.5 -s workspace-write -
```
