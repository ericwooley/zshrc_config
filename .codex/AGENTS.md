# Github interactions

when interacting with github, you may be on a VM with different access permissions. `gh` command should always work. The github connection often won't. Prefer gh cli.

## Pull request provenance

- Add a Codex provenance section to every pull request that the agent opens.
- Resolve the work machine's Tailscale host before the first edit when PR
  delivery is already in scope. Otherwise, resolve it when the user requests
  the PR. If work moves between machines, list each machine that changed the PR.
- Read the Tailscale status with `tailscale status --json`. If `tailscale` is
  absent from `PATH` on macOS, use
  `/Applications/Tailscale.app/Contents/MacOS/Tailscale status --json`.
- Read `.Self.DNSName` and use its first DNS label as the host. Normalize `mbp`
  to `Erics-MacBook-Pro`. Keep other labels, such as `dev` and `bts`, unchanged.
  Do not substitute the local system hostname.
- Read the opening Codex session ID from `CODEX_THREAD_ID` in the session that
  opens the PR. Do not reuse an ID from another session and do not invent one.
- Add this exact block to the PR body before opening the PR. Replace both
  placeholders with literal values. Do not put environment variables in the
  body.

  ````markdown
  ## Codex provenance

  - Tailscale host: `<tailscale-host>`
  - Codex session ID: `<session-id>`
  - Resume command:

    ```sh
    codex exec resume <session-id> "Your follow-up prompt"
    ```
  ````

- If the Tailscale host or `CODEX_THREAD_ID` is unavailable, do not open the PR.
  Report the missing value to the user.
- After the PR opens, run `gh pr view --json body --jq .body`.
- Verify the Tailscale host, session ID, and resume command in the live PR body.
  Correct the body immediately if any value is missing or incorrect.

# jira interactions

If I tell you to interact with jira, use the acli cli tool. Only interact with jira when I tell you, do not make updates to jira unless explicitly asked.


# Testing / Coding Best Practices

These principles apply across languages. The exact syntax and patterns differ between Go, TypeScript, Python, Rust, Java, Ruby, and other languages, but the goal is the same: keep important behavior easy to test, easy to reason about, and separate from external side effects.

FQM is the only exception to the test requirements in this section. In FQM,
keep the design guidance, but do not create, update, or run tests unless the
user explicitly requests a specific test.

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

## React Component Use

- Use components for almost all React user interface elements.
- Before you start a view or page, inspect the available components.
- Use an available component instead of writing the same user interface element by hand.
- Make form inputs reusable components in almost all cases.
- Look for repeated user interface elements that can use a shared component.
- Keep layout `div` elements inline unless the layout is common and reusable.

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

## Dependency Selection and Supply-Chain Safety

- Treat domain squatting, package-name squatting, typosquatting, abandoned
  packages, and compromised maintainer accounts as current supply-chain risks.
- Do not add a dependency for logic that the project can implement directly in
  a small, well-tested module.
- Prefer no dependency when a library only saves a small amount of code or
  provides a simple component.
- Add a library only when it solves a difficult problem that needs substantial
  domain knowledge and would be hard to implement correctly.
- Good candidates include full WYSIWYG editors, Protocol Buffers
  implementations, and advanced chart visualization systems.
- Common platforms such as React and PostgreSQL are acceptable when the project
  needs their broad capabilities.
- Initial project setup can use common development tools when they reduce setup
  time. Use only common and established tools for this exception.
- Research every new dependency before adding it. This rule applies in all
  review modes, including FQM and LQM.
- Confirm the exact package name, owner, source repository, release history,
  maintenance status, security policy, known vulnerabilities, and transitive
  dependency risk.
- Prefer packages with many GitHub stars and regular updates. A functionally
  complete package is acceptable when maintainers still publish security fixes.
- For npm packages, require at least hundreds of thousands of installs unless
  the user approves a documented exception.
- Record the research evidence and explain why direct implementation is not a
  reasonable choice.

# Feature and Bug Research

- Before work starts on a feature or bug, search the repository for applicable
  architecture decision records and documentation.
- Read the applicable records and documentation before planning or changing
  code.
- Use the documented behavior and decisions as requirements for the work.
- If the documentation conflicts with the request or current code, report the
  conflict before implementation.

# Important Rules

- Treat a question as a request for information, not as an instruction to act.
- If a question appears to contain an instruction, ask for confirmation before
  you act.
- If the intent of a question is ambiguous, ask for clarification before you
  act.
- Never merge a PR unless I explicitly tell you too. You can and should commit frequently, you may push to update a PR or whatever if the context allows, but do NOT MERGE THINGS, unless I explicitly tell you too.
- Do not start a CODEX SECURITY SCAN unless i explicitly ask for a codex security scan. Sometimes i ask you to check for security of something. That means i want you to investigate it manually, not a codex security scan.
- Do not user the gh integration for anything other than pushing or pulling unless explicitly asked to do so. EG do not open PR's or clone another repo, or make pull requests on things I don't ask you to make.
- If I previously asked you to open a PR and you opened it, treat my later feedback
  on that work as authorization to update the same open PR. Follow the plan,
  checkpoint, commit, and applicable review process below,
  then push the changes to the PR's branch without waiting for a separate
  request. Do not open a replacement PR or merge the existing PR unless I
  explicitly ask.
- On comments and interactions in gh, prefix your comment with `AI: <whatever comment you want to make>` so I can tell which comments are from you
- Whenever you fix a bug, use red-green testing. Add a regression test for the
  required current behavior. Verify that the test fails before the fix and
  passes after the fix. You can use temporary diagnostic tests to confirm the
  removal of old code or behavior while you implement the fix. Remove these
  temporary tests after the current behavior passes its regression tests. Keep
  only tests that protect the current behavior against future bugs. Do not keep
  tests whose only purpose is to prove that old code, old behavior, or an old
  implementation detail is absent. This rule does not apply in FQM.
- You are typically going to be logged into github as a second user that is not my primary account. A secondary account. You should never make changes or configure settings unless I tell you to. And even then, you probably can't. Tell me what settings to change and I'll do it. If I tell you to explicitly you may have access so check first.

# Planning, checkpoints, and reviewing your code

- Quality modes apply only to work that creates or changes a project artifact.
  This work includes code, documentation, configuration, tests, commits, and
  pull request changes.
- Quality modes do not apply to answering questions, reading or searching code,
  research, diagnosis, or read-only code review.
- Start read-only tasks without asking the user to select a quality mode.
- If a read-only task later requires a project change, ask for a quality mode
  before making that change unless an automatic mode rule applies.
- Review quality is an explicit, conversation-scoped mode with no default. The
  user must explicitly select FQM, LQM, MQM, or HQM for each new conversation.
  If the user has not selected a mode, ask them to choose one before creating
  or changing a project artifact. Do not infer a mode from the task's risk,
  scope, urgency, or wording. Do not reuse a selection from another
  conversation. The only automatic mode transition is for open PR work. When
  the agent opens a PR or begins or resumes work on an existing open PR, switch
  to MQM unless the user explicitly selects FQM, LQM, or HQM for that work.
  Record the transition in the plan and final response.
- Changes limited to development configuration files automatically use FQM.
  Examples include ESLint, TypeScript, formatter, test-runner, and editor
  configuration files. Do not create, update, or run tests for these changes.
  Manually verify that the affected tool reads the configuration and applies
  the intended settings. This exception does not include CI, deployment,
  runtime, security, or production configuration.
- `FQM` (case-insensitive), `use fast quality mode`, `use yolo mode`,
  `debug in production mode`, or an unmistakable equivalent explicitly
  activates fast quality mode immediately for unfinished and later work. Use
  FQM for small scripts, direct experiments, and urgent debug changes. Make the
  smallest direct change that satisfies the request. Do not create a formal
  plan, checkpoints, or a content-sensitive baseline. Do not create, update, or
  run tests. Do not run linters, formatters, builds, or optional validation.
  Run only a check that the user explicitly requests or a higher-priority safety
  rule requires. Do not launch review agents. Stop treating all reviews and
  checks as gates. Interrupt review agents and running checks when control is
  available. Allow only bounded cleanup when interruption could leave a local
  service or temporary artifact. Inspect the relevant files before the edit.
  Inspect the intended diff and repository status after the edit. Create scoped
  commits when the task requires commits. State that normal verification was
  skipped. List each user-requested or required check that ran. FQM does not
  permit unsafe, destructive, unauthorized, or out-of-scope work. Preserve
  unrelated work and secrets. FQM does not authorize a push, deployment,
  release, merge, or external write.
- `MQM` (case-insensitive), `use mid quality mode`, `use medium quality mode`,
  or an unmistakable equivalent explicitly activates mid quality mode
  immediately for unfinished and later work. Before implementation in effective
  MQM, classify the planned work as minor or major using its scope, blast
  radius, cross-component reach, uncertainty, and validation burden. Record the
  classification and its rationale, then plan and record approximately two
  coherent checkpoints for a minor feature or equivalent-sized change and three
  for a major feature or equivalent-sized change. These counts are planning
  targets, not quotas. Do not split coherent work to reach them. Add or remove a
  checkpoint only when natural boundaries, changed scope, or review findings
  require it. Record the reason for a deviation and replan before continuing.
  MQM uses exactly one review subagent for the complete task. Do not launch
  checkpoint reviewers, a specialist group, or a review lead. Launch the single
  reviewer after all planned checkpoints are implemented, validated, inspected,
  and committed. Reuse the same reviewer for correction or evidence follow-ups.
  Do not launch a fresh reviewer during the same MQM task.
- `LQM` (case-insensitive), `use low quality mode`, `skip all reviews`, or an
  unmistakable equivalent explicitly activates low quality mode immediately for
  unfinished and later work. In effective LQM, do not launch an MQM reviewer,
  checkpoint-review subagent, final specialist, or review lead. Stop treating
  any in-flight review as a gate immediately. When control is available,
  interrupt in-flight review subagents and the lead; if interruption could
  strand a local service, disposable VM, or temporary artifact, perform or
  allow only the bounded cleanup required by the review safety rules without
  waiting for a verdict. Ignore any review report that arrives after LQM
  becomes the effective mode when deciding whether the task may proceed.
- `HQM` (case-insensitive), `use high quality mode`, `use full reviews`,
  `resume all reviews`, or an unmistakable equivalent explicitly activates high
  quality mode immediately for unfinished and later work. Effective HQM requires
  both checkpoint reviews and the relevance-sized final review.
- Mode switches do not retroactively review work already completed and
  delivered under another mode. Do not infer a switch merely from requests to
  be quick, cheap, or concise. An explicit FQM, LQM, MQM, or HQM selection
  remains active until the user explicitly selects another mode, the open-PR
  MQM transition applies, or the conversation ends. FQM skips the formal plan,
  content-sensitive baseline, tests, validation, and review workflows. In LQM,
  MQM, and HQM, still create the working plan and content-sensitive baseline,
  preserve unrelated work, implement the requested change, run proportionate
  validation, inspect the complete diff and status, and create scoped commits.
  In FQM, preserve unrelated work, inspect the intended diff and status, and
  create scoped commits. Review mode does not relax safety rules or authorize
  merges, pushes, or external changes that the user did not otherwise request.
  Record the active mode in each required plan and final response.
- Outside FQM, localized static copy or documentation corrections may skip
  the MQM reviewer, checkpoint-review subagents, the final specialist group, and
  the review lead
  when they do not change runtime behavior, dependencies, security policy,
  public contracts, deployment, or accessibility. This exemption is for
  localized corrections, not behavioral workflow or policy changes expressed
  in documentation. Create the normal plan and content-sensitive baseline,
  validate the affected artifacts, inspect the complete diff and repository
  status, and create exactly one scoped commit. Record the concrete exemption
  reason and validation evidence in the plan and final response. When
  applicability is uncertain, do not use the exemption.
- Outside FQM, for every task that changes tracked files, create a working plan
  before editing. Break the work into outcome-oriented checkpoints that can be
  implemented, tested, committed, and reviewed as coherent units. Keep the
  plan current as work progresses. In MQM, reason about dependencies,
  integration order, validation, and natural checkpoint boundaries. Record the
  intended checkpoint sequence before starting implementation. A small task may
  have one checkpoint. Do not invent artificial checkpoints or split
  implementation from its tests and required documentation.
- Outside FQM, before making changes, record the task's starting commit and a
  content-sensitive snapshot of the index and worktree, including untracked
  files. The snapshot must detect content and file-type changes, not only paths
  and status codes; for example, hash staged and unstaged binary diffs plus
  untracked path, type, and content evidence. Use that baseline to distinguish
  and preserve unrelated pre-existing changes. Use the task-start commit as the
  review base for the first HQM checkpoint. After an HQM checkpoint receives a
  `ready` verdict, advance the review base to that checkpoint's reviewed `HEAD`.
  At each checkpoint:
  1. finish the checkpoint's implementation, tests, and required documentation;
  2. run the relevant validation and inspect the complete diff and repository
     status;
  3. stage only the intended files and create a scoped checkpoint commit;
  4. in HQM, when the localized static-copy/documentation exemption does not
     apply, launch a dedicated code-review subagent to adversarially review only
     the exact previous-checkpoint-to-current-checkpoint commit range; and
  5. when a reviewer was launched and the effective mode still requires that
     gate, wait for a `ready` verdict before beginning the next checkpoint.
- A checkpoint reviewer may inspect current surrounding code, tests, contracts,
  and consumers when needed to understand or validate the checkpoint delta, but
  must not re-review earlier checkpoint diffs or the cumulative task history.
  In MQM, the single reviewer reviews all task changes after the last checkpoint.
  In HQM, the initial final specialist group reviews all task changes. Later HQM
  final follow-ups review only the requested correction or intentional-drift
  delta since the recorded final-review baseline.
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
  not paraphrase them. For a checkpoint review, include the current plan and
  checkpoint, the previous `ready` checkpoint commit, or the task-start commit
  for the first checkpoint. Include `Review mode: checkpoint delta`, the exact
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
- For an HQM checkpoint review, resolve every actionable finding yourself.
  Rerun the relevant tests and create a new scoped fix commit. Launch a fresh
  review subagent against the same previous-checkpoint base through the new
  `HEAD`. The checkpoint review base does not advance until the checkpoint is
  `ready`. Repeat this fix, commit, and review loop until the reviewer returns a
  `ready` verdict. Do not ask the review subagent to implement its own findings.
- The reusable prompts already require review of all copy as
  customer/consumer-centric language that does not leak business logic or
  technical requirements and does not describe what the product does not do.
  Write copy this way yourself; do not rely on the review to catch it.

# MQM single-agent review and HQM specialist group review

- In MQM, launch exactly one review subagent after all planned checkpoints are
  implemented, validated, inspected, and committed. Freeze the full task range
  and the repository snapshot before the review. Select the one most relevant
  specialist role from the candidate list below. Record why that role covers the
  task's material risks. The reviewer must read the applicable common review
  prompt and the selected role prompt.
- Give the MQM reviewer the exact original request, plan, task-start commit,
  `Review mode: MQM final single-agent`, frozen full task range and `HEAD`,
  sanitized validation evidence, sanitized run instructions, and sanitized
  unresolved concerns. Apply the same read-only, containment, and sensitive-data
  rules that apply to HQM reviewers.
- The MQM reviewer must report `Coverage validity: valid` or
  `Coverage validity: invalid` and `ready` or `not ready`. MQM passes only when
  coverage is valid and the reviewer returns `ready` with no unresolved
  actionable findings.
- If the MQM reviewer finds an actionable issue, resolve it yourself. Rerun the
  relevant validation and create a scoped correction commit. Send a follow-up
  task to the same reviewer. Give the reviewer only the correction range and all
  unresolved findings or evidence requests. Repeat with the same reviewer until
  it returns a coverage-valid `ready` verdict. Do not launch another reviewer.
- Do not run the specialist group or review lead in MQM. Run the remaining
  specialist group workflow only in HQM.

- Run this section's specialist group and review lead when the effective mode is
  HQM. Do not run them when the effective mode is FQM, LQM, or MQM, or when the
  localized static-copy/documentation exemption applies. The trivial/minor
  final-only exemption is defined below.
- Once all implementation checkpoints have completed the effective mode's
  requirements and you believe the feature or request is complete, commit every
  intended task change and require no remaining uncommitted task changes or
  untracked task artifacts. In effective HQM, every checkpoint must have a
  `ready` verdict.
  Record the exact full `HEAD` and a new content-sensitive repository snapshot.
  Freeze the full task/session range from the task-start commit through that
  final `HEAD`; do not use the most recent checkpoint as the final-review base.
  A task that started clean must be clean; unrelated pre-existing changes may
  remain only when their content-sensitive state still matches the task-start
  baseline and is isolated from the task. Run one final specialist group review
  over all changes in that frozen task/session range before declaring the task
  done or pushing it. This initial pass uses `Review mode: final full task`.
- Every group-review pass must select the one to three most relevant specialist
  roles from the candidate list below and use one fresh subagent for each
  selected role. Use only the number needed to cover the material risks; do not
  add roles merely to reach three. Apply the same source-repository and
  shared-state read-only boundary defined above to every selected specialist
  and the separate review lead. The review lead does not count toward the
  one-to-three limit. Run the selected specialists sequentially, one at a time,
  and wait for each to finish, then run the review lead last. Choose and record
  the order by relevance to the actual risk, with the most relevant specialist
  first. Record why each role was selected, why that count is sufficient, and
  why every omitted candidate role is unnecessary or covered. Do not default to
  the same roles or count for every task.
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
  which numbered position it occupies in the selected review order and how many
  specialists were selected for that pass.
- Keep specialist reviews independent: do not give a specialist the earlier
  specialists' reports, and do not change the code or reviewed `HEAD` between
  specialist reviews. Sanitize every report before handing it to the review
  lead: replace sensitive values from logs, scanner output, or findings with
  stable redaction markers while retaining the relevant path, key name,
  detector, and impact. Give the review-lead subagent every selected
  specialist's sanitized report verbatim, the selection, count, ordering, and
  omission rationale, and the same frozen task context.
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
  focus, range, frozen `HEAD`, one to three specialist reports, role selection,
  selected count, and verification evidence are sufficient to perform the
  required review. A
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
  fix checkpoint commit. Freeze the new correction `HEAD`, reselect the one to
  three most relevant roles for the requested corrections, and run
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
  the handoff, reselect the one to three roles most relevant to the outstanding
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
- Immediately after the required `ready` verdict and before declaring completion or
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
- In effective FQM or LQM, skip all review agents. In effective MQM, use only
  the single MQM reviewer. Outside these modes, skip the HQM checkpoint
  reviewers, final specialist group, and review lead together only under the
  localized static-copy or documentation exemption above. Other clearly trivial
  or minor HQM requests may skip the final specialist group and review lead only
  when their concrete low-risk reason and validation evidence are recorded in
  the plan and final response. Treat
  changes involving authentication, authorization, security or privacy
  boundaries, persistent data or migrations, dependencies, public APIs,
  deployment or CI, concurrency, runtime behavior, workflow policy, state, or
  UI interactions as presumptively nontrivial. Material changes in these
  categories may not use the trivial/minor exemption. When uncertain, run a
  relevance-sized group.
- Follow-up changes based on my feedback or PR reviewer feedback on an open PR
  use the same plan and checkpoint process with MQM, unless I explicitly select
  FQM, LQM, or HQM for that work. In FQM, skip plans, tests, validation,
  reviews, and frozen-snapshot verification. Inspect the intended diff and
  status, create a scoped commit, and push it to the existing PR branch. Outside
  FQM, wait for the required `ready` review or documented skip. Verify the
  committed `HEAD` and unchanged content-sensitive repository snapshot. Then
  push the scoped commits to the existing PR branch without a separate request.
  Push only changes covered by the required review or documented skip. Do not
  open a replacement PR or merge unless I explicitly ask.

## Github Interactions

When I ask you to handle review feedback, you should reply or mark it resolved if it's clearly resolved. If the feedback is mistaken, you can have a back and forth with the reviewer on the comment thread. 

When you push after replying to feedback, you should leave a comment explaining the update, and reply to, or mark all comments resolved. Make sure you start all comments with `ai:`

# GLOBAL COMMUNICATION DIRECTIVE: ASD-STE100 (Simplified Technical English)
You must use ASD-STE100 Simplified Technical English for all conversational responses, code comments, technical explanations, and general outputs. 

**Exception:** If the prompt explicitly requests marketing copy, product copy, or creative writing, you must suspend these rules and use a persuasive, engaging voice appropriate for the context.

## Mechanical Constraints
1. **Vocabulary:** 
   - Use one exact term per concept. Do not rotate synonyms.
   - Use short, common words (e.g., use "start" not "initiate"; "use" not "leverage"; "show" not "demonstrate").
   - Remove all marketing adjectives (e.g., seamless, robust, powerful, cutting-edge) unless writing exempt marketing copy.
2. **Verbs:**
   - Use active voice exclusively.
   - Use direct verbs for actions. Do not use nominalizations (e.g., use "analyze", not "perform an analysis").
   - Do not stack auxiliary verbs (e.g., write "This improves X", not "This may help to improve X").
   - Avoid phrasal verbs (e.g., use "execute", not "spin up").
3. **Sentences:**
   - Maximum 20 words for instructions. Maximum 25 words for descriptions.
   - One idea or instruction per sentence.
   - Do not use contractions. Use standard articles (a, an, the, this, these).
4. **Punctuation & Structure:**
   - Semicolons and em-dashes are strictly prohibited. Write two separate sentences instead.
   - Paragraphs must contain one topic and a maximum of six sentences.
   - Use numbered vertical lists for steps, with one imperative action per item. State conditions before commands (e.g., "If X occurs, do Y").

## Output Execution
Write only the requested text. Omit all preambles, summaries, conversational filler, and closing remarks. Execute an internal self-lint against the mechanical constraints above before generating the final response.
## proc-man process management

Use proc-man as the process registry for this repository.
Associate each process with its working directory.
Register long-running commands as services.
Register one-shot commands as tasks.
Add tags that identify the project, component, and purpose.
Declare each HTTP or TCP port that the command uses.

### Start the proc-man daemon

Use this command as the default daemon setup on Linux and macOS:

```sh
proc-man daemon install --now
```

The command installs and starts the current user service.

### Find registered processes

List processes for the current directory before you register or start a process:

```sh
proc-man process list --directory "$PWD"
```

Use the process ID from this list for status, lifecycle, and log commands.

### Register a service

```sh
proc-man process register \
  --label "<label>" \
  --kind service \
  --cwd "$PWD" \
  --tag "project:<project>" \
  --tag "component:<component>" \
  --port "http=http://127.0.0.1:<port>/" \
  -- <command> [args...]
```

Omit the port flag when the process has no port.

### Register a task

```sh
proc-man process register \
  --label "<label>" \
  --kind task \
  --cwd "$PWD" \
  --tag "project:<project>" \
  -- <command> [args...]
```

### Manage processes and logs

Use start, stop, and restart for services.
Use run for tasks.

```sh
proc-man process status PROCESS_ID
proc-man process start PROCESS_ID
proc-man process stop PROCESS_ID
proc-man process restart PROCESS_ID
proc-man process run PROCESS_ID
proc-man process logs PROCESS_ID
proc-man run list --process PROCESS_ID
proc-man run logs RUN_ID
```

Use `proc-man open ENDPOINT_ID` to open a declared HTTP endpoint.
Use `proc-man process deregister PROCESS_ID` when the process no longer belongs to this directory.
Retained run logs remain available after deregistration.
