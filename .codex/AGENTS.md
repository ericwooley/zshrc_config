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
- Before making changes, record the task's starting commit and a
  content-sensitive snapshot of the index and worktree, including untracked
  files. The snapshot must detect content and file-type changes, not only paths
  and status codes; for example, hash staged and unstaged binary diffs plus
  untracked path, type, and content evidence. Use that baseline to distinguish
  and preserve unrelated pre-existing changes. Use the task-start commit as the
  review base for the first checkpoint. After a checkpoint receives a `ready`
  verdict, advance the review base to that checkpoint's reviewed `HEAD`. At
  each checkpoint:
  1. finish the checkpoint's implementation, tests, and required documentation;
  2. run the relevant validation and inspect the complete diff and repository
     status;
  3. stage only the intended files and create a scoped checkpoint commit;
  4. launch a dedicated code-review subagent to adversarially review only the
     exact previous-checkpoint-to-current-checkpoint commit range; and
  5. wait for a `ready` verdict before beginning the next checkpoint.
- A checkpoint reviewer may inspect current surrounding code, tests, contracts,
  and consumers when needed to understand or validate the checkpoint delta, but
  must not re-review earlier checkpoint diffs or the cumulative task history.
  The initial final specialist group is the single full review of all
  task/session changes; later final follow-ups review only the requested
  correction or intentional-drift delta since the recorded final-review
  baseline.
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
- Before handing context to any review subagent, check the original request and
  supporting evidence for credentials, tokens, private keys, customer data, or
  other sensitive literals. If the original request contains any, stop and ask
  me for a redacted request; do not replicate the sensitive request to
  subagents. Sanitize all supporting evidence before every handoff, replacing
  sensitive values with stable redaction markers while retaining the relevant
  path, key name, detector, and impact. This includes validation evidence, run
  instructions, unresolved concerns, and, for bug fixes, the exact test command
  plus failing and passing output. Otherwise, include the exact instructions I
  gave you in the subagent task under `Original user request (verbatim)`. Do
  not paraphrase them. Include the current plan and checkpoint, the previous
  `ready` checkpoint commit (or task-start commit for the first checkpoint),
  `Review mode: checkpoint delta`, the exact
  previous-checkpoint-to-current-`HEAD` review range, sanitized validation
  evidence, and sanitized unresolved concerns. Do not give a checkpoint
  reviewer the cumulative task range. For bug fixes, also include the sanitized
  exact test command, failing output, and passing output.
- Give the subagent a review task that is read-only with respect to repository
  source and tracked files, commits, pushes, and production or shared external
  state. It may inspect the repository, run relevant tests, start disposable
  local services, operate a browser against a development environment, write
  temporary files outside the repository, and create and clean up a review VM
  only under the applicable common prompt's safety rules.
- Resolve every actionable finding yourself, rerun the relevant tests, and
  create a new scoped fix commit. Launch a fresh review subagent against the
  same previous-checkpoint base through the new `HEAD`. The checkpoint review
  base does not advance until the checkpoint is `ready`. Repeat this fix,
  commit, and re-review loop until the reviewer returns a `ready` verdict. Do
  not ask the review subagent to implement its own findings.
- The reusable prompts already require review of all copy as
  customer/consumer-centric language that does not leak business logic or
  technical requirements and does not describe what the product does not do.
  Write copy this way yourself; do not rely on the review to catch it.

# Final top-three specialist group review

- Once all implementation checkpoints are individually `ready` and you believe
  the feature or request is complete, commit every intended task change and
  require no remaining uncommitted task changes or untracked task artifacts.
  Record the exact full `HEAD` and a new content-sensitive repository snapshot.
  Freeze the full task/session range from the task-start commit through that
  final `HEAD`; do not use the most recent checkpoint as the final-review base.
  A task that started clean must be clean; unrelated pre-existing changes may
  remain only when their content-sensitive state still matches the task-start
  baseline and is isolated from the task. Run one final specialist group review
  over all changes in that frozen task/session range before declaring the task
  done or pushing it. This initial pass uses `Review mode: final full task`.
- Every group-review pass must select exactly the three most relevant
  specialist roles from the candidate list below and use one fresh subagent for
  each selected role. Apply the same source-repository and shared-state
  read-only boundary defined above to all three selected specialists and the
  separate review lead. The review lead does not count toward the three. Run
  the selected specialists sequentially, one at a time, and wait for each to
  finish, then run the review lead last. Choose and record the order by
  relevance to the actual risk, with the most relevant specialist first.
  Record why each role was selected and why each of the other three roles was
  omitted. Do not default to the same trio for every task.
  Candidate specialist roles:

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

  The review lead always uses:
  `.codex/prompts/reviewers/review-lead.md`
- Examples of relevance ordering:
  - authentication or authorization: security first;
  - user-interface or interaction work: designer/UX first;
  - test infrastructure or flaky behavior: test/reliability first;
  - dependency, API, migration, or cross-component work:
    maintainability/integration first.
- Every selected specialist subagent must read the applicable common review
  prompt and its role prompt. The separate review-lead subagent must read the
  same common prompt and the review-lead role prompt. Resolve every common and
  role prompt from `${ZSHRC_CONFIG_DIR:-$HOME/.zshrc_config}` and pass the
  applicable absolute paths to each subagent; do not assume the current
  repository contains `.codex/prompts`. For the initial final pass, give each
  the exact original request, plan, task-start commit,
  `Review mode: final full task`,
  `Review focus: complete assigned range`, frozen full task/session range and
  `HEAD`, sanitized validation evidence, sanitized relevant run instructions,
  and sanitized unresolved concerns. For a standard correction or drift pass,
  give each the exact original request, plan, the recorded final-review baseline
  `HEAD` and its provenance, `Review mode: final follow-up`,
  `Review focus: complete assigned range`, exact range from that recorded
  baseline through the current frozen `HEAD`, sanitized validation evidence,
  sanitized relevant run instructions, and sanitized unresolved concerns. Also
  identify one `Follow-up purpose`. For `requested corrections`, include every
  unresolved accepted item from the baseline-establishing pass, including
  repository corrections and contemporaneous evidence or handoff requests,
  plus any later evidence-only requests. For
  `intentional drift changes`, include a sanitized description and acceptance
  criteria for the intentional task changes made after a `ready` verdict. For a
  coverage-valid evidence-only rerun, retain the prior mode, purpose, baseline,
  exact range, and frozen `HEAD`; give each
  `Review focus: outstanding evidence only` and the exact outstanding evidence
  or corrected-handoff requests. State that the preceding code review is
  reviewed context and must not be repeated. Do not give a standard final
  follow-up reviewer the full task/session range. Tell each selected specialist
  which numbered position it occupies in the selected three-role review order.
- Keep specialist reviews independent: do not give a specialist the earlier
  specialists' reports, and do not change the code or reviewed `HEAD` between
  specialist reviews. Sanitize every report before handing it to the review
  lead: replace sensitive values from logs, scanner output, or findings with
  stable redaction markers while retaining the relevant path, key name,
  detector, and impact. Give the review-lead subagent all three sanitized
  specialist reports verbatim, the selection, ordering, and omission rationale,
  and the same frozen task context.
- Reviewers must use the relevant tools available to them rather than limiting
  themselves to a diff when runtime evidence is practical. This may include
  repository inspection, focused tests, builds, linters, a local application,
  browser or Chrome control, screenshots, and a disposable Multipass VM. The
  common prompt's trust and containment gate applies before any runtime tool
  use; host credentials, shared state, and personal browser sessions must not
  be traded for additional evidence. The role prompts define the expected tool
  use and VM safety rules. A tool or environment limitation must be reported as
  an explicit verification gap.
- This is a manual specialist review workflow. Do not start a Codex Security
  Scan unless I explicitly ask for one.
- The review lead must report `Coverage validity: valid` or
  `Coverage validity: invalid`. Coverage is valid only when the mode, review
  focus, range, frozen `HEAD`, exactly three specialist reports, role selection,
  and verification evidence are sufficient to perform the required review. A
  procedurally invalid pass does not establish or advance the recorded
  final-review baseline. Correct its handoff or evidence and rerun the same
  review mode from the same recorded baseline; if repository corrections change
  the range end, keep the original range start. The initial full-task pass must
  be coverage-valid before any correction-only follow-up may record its
  reviewed `HEAD` as a baseline.
- The group passes only when coverage is valid and the review lead returns
  `ready` with no unresolved actionable findings. Do not use majority vote. A
  coverage-valid `ready` verdict terminates the review loop; do not schedule an
  empty or precautionary follow-up. Proceed directly to the required frozen
  revision and repository-snapshot verification.
- When a coverage-valid lead returns `not ready` with accepted findings that
  require repository corrections, record that pass's frozen reviewed `HEAD` as
  the next final-review baseline. Record that the provenance is a
  coverage-valid pass whose accepted findings required repository changes.
  A pass with both repository findings and evidence or handoff requests follows
  this correction transition while retaining every unresolved evidence and
  handoff obligation.
  Resolve the findings yourself, rerun relevant validation, and create a scoped
  fix checkpoint commit. Freeze the new correction `HEAD`, reselect the three
  most relevant roles for the requested corrections, and run
  `Review mode: final follow-up` with
  `Follow-up purpose: requested corrections` over only the
  baseline-to-correction range. Use a fresh subagent for each selected role and
  a fresh review lead, give them every unresolved accepted repository,
  evidence, and handoff item from the baseline-establishing pass plus any later
  evidence-only request, and do not give specialists one another's conclusions.
  If a coverage-valid follow-up requests more repository changes, its reviewed
  `HEAD` becomes the next recorded final-review baseline and only the next
  correction delta is reviewed.
- When a coverage-valid `not ready` verdict requires only missing evidence or a
  corrected handoff and no repository change, do not advance the recorded
  final-review baseline or create an empty delta. Obtain the evidence or repair
  the handoff, reselect the three roles most relevant to the outstanding
  evidence, and rerun the same review mode, exact range, frozen `HEAD`, and
  follow-up purpose from the retained baseline with
  `Review focus: outstanding evidence only`. Explicitly tell the reviewers and
  lead to assess only the supplied evidence or handoff requests, treat the prior
  coverage-valid implementation assessment as reviewed context, and not repeat
  the feature or correction review. The intervening coverage-valid result does
  not advance the baseline.
- Once the initial full pass is coverage-valid, do not re-review the full
  task/session range for follow-up corrections. A follow-up verifies its stated
  correction or intentional-drift purpose and regressions in that delta, using
  earlier coverage-valid final-review results as reviewed context.
- Immediately after a `ready` lead verdict and before declaring completion or
  pushing, verify that the current full `HEAD` still equals the frozen reviewed
  `HEAD` and that a new content-sensitive index/worktree snapshot exactly
  matches the frozen snapshot. A clean-start task must still be clean, and
  pre-existing dirty content must still match the task-start baseline. Push
  only the commits covered by that reviewed revision. If repository state
  drifted while `HEAD` stayed frozen, compare it content-sensitively with the
  task-start and frozen snapshots and classify ownership before acting. Never
  overwrite, delete, clean, reset, or otherwise restore unknown, unrelated, or
  overlapping content. Automatically remove only disposable artifacts proven
  to be task-owned, using a recoverable operation when practical, then repeat
  snapshot verification. Preserve and report unrelated or unknown drift; when
  it is isolated from the task, verify the reviewed commit in an isolated clean
  worktree, otherwise stop and report the overlap. If intentional task changes
  after `ready` require a new commit, record the ready pass's reviewed `HEAD` as
  the final-review baseline with `ready intentional-drift` provenance, freeze
  the new revision and snapshot, then run
  `Review mode: final follow-up` with
  `Follow-up purpose: intentional drift changes` from that baseline through the
  new frozen `HEAD`. Give reviewers a sanitized description and acceptance
  criteria for that delta, and do not restart the full task/session review.
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
  verify the reviewed `HEAD` and unchanged frozen content-sensitive repository
  snapshot as described above, then push only those already-reviewed commits to
  the existing PR branch without waiting for a separate push request. Do not
  push any change that has not passed the required review process, and do not
  open a replacement PR or merge unless I explicitly ask.

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
