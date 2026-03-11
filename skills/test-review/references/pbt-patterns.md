# Property-Based Testing Patterns

Reference for AI test-reviewer. Read on demand when evaluating test coverage for transformation, parsing, or stateful code. Not a tutorial — jump to the relevant section.

---

## The 7 Core PBT Patterns

### 1. Roundtrip / Inverse
`serialize(deserialize(x)) == x` (and the reverse direction).

**When:** Any encode/decode, serialize/deserialize, compress/decompress pair. Highest ROI, lowest effort — add this first.

```python
# Hypothesis example
@given(st.text())
def test_json_roundtrip(s):
    assert json.loads(json.dumps(s)) == s
```

---

### 2. Oracle / Differential
Run the same input through a fast/optimized implementation AND a slow/naive reference. Outputs must match.

**When:** You have an optimized algorithm and a simpler fallback, or two independent implementations of the same spec.

```python
@given(st.lists(st.integers()))
def test_sort_matches_naive(lst):
    assert fast_sort(lst) == sorted(lst)  # sorted() is the oracle
```

---

### 3. Metamorphic
Transform the input in a predictable way → the output must transform predictably. No oracle required.

**When:** No reference implementation exists. Works well for ML models, search engines, compilers.

```python
# Adding a duplicate element to a set should not change its size
@given(st.sets(st.integers()), st.integers())
def test_set_add_duplicate(s, x):
    s2 = s | {x}
    assert len(s2 | {x}) == len(s2)
```

---

### 4. Invariants
Transformations leave certain properties unchanged (size, sum, type, ordering, membership).

**When:** Any operation that mutates or transforms data while preserving a known property.

```python
@given(st.lists(st.integers()))
def test_sort_preserves_elements(lst):
    result = my_sort(lst)
    assert sorted(result) == sorted(lst)   # same elements
    assert len(result) == len(lst)          # same count
```

---

### 5. Model-based / Stateful
A simplified model (e.g., a dict or list) mirrors the state transitions of the system under test. Drive both in parallel; compare state after each operation.

**When:** Objects with ≥3 mutating methods. Databases, queues, caches, state machines.

```python
# Hypothesis stateful example (RuleBasedStateMachine)
class QueueMachine(RuleBasedStateMachine):
    def __init__(self):
        super().__init__()
        self.model = []
        self.impl = MyQueue()

    @rule(value=st.integers())
    def enqueue(self, value):
        self.model.append(value)
        self.impl.push(value)

    @rule()
    @precondition(lambda self: self.model)
    def dequeue(self):
        assert self.model.pop(0) == self.impl.pop()
```

---

### 6. Commutativity / Associativity
Operation order should not affect the result.

**When:** Merge operations, set operations, mathematical functions, map/reduce pipelines.

```python
@given(st.integers(), st.integers())
def test_add_commutative(a, b):
    assert my_add(a, b) == my_add(b, a)

@given(st.lists(st.integers(), min_size=1))
def test_merge_associative(items):
    # split point should not matter
    mid = len(items) // 2
    assert merge(items[:mid], items[mid:]) == merge_all(items)
```

---

### 7. Easy-to-Verify Outputs
The result is hard to compute but trivial to validate post-hoc.

**When:** Sorting (is output sorted?), factoring (do factors multiply back?), path-finding (does path connect start to end?).

```python
@given(st.lists(st.integers()))
def test_sort_is_sorted(lst):
    result = my_sort(lst)
    assert all(result[i] <= result[i+1] for i in range(len(result) - 1))
```

---

## Trail of Bits Trigger List

Code in **any** of these categories without PBT is a review finding (MEDIUM by default; upgrade to HIGH if the function is security-relevant or handles money):

| Category | Examples |
|---|---|
| Serialization pairs | encode/decode, serialize/deserialize, compress/decompress, marshal/unmarshal |
| Parsers | JSON, XML, CSV, YAML, TOML, custom text formats, protocol buffers, ASN.1 |
| Normalization | Unicode normalization, URL canonicalization, path resolution, whitespace stripping |
| Validators / sanitizers | Email, phone, credit card, IBAN, HTML sanitizer, regex validator |
| Custom data structures | Priority queues, LRU cache, trie, bloom filter, skip list, custom graph |
| Mathematical / algorithmic | Sort, search, hash, crypto primitive wrappers, financial rounding, base conversion |
| Smart contracts / finance | Token math, fee calculation, interest accrual, slippage, order matching |

---

## Signs a Test Suite Needs PBT

- 5+ parametrized tests with structurally similar hand-picked inputs → should be a PBT property
- encode/decode functions with only single concrete value tests
- Parsers with only happy-path tests (no empty input, no max-length, no malformed input)
- No edge cases: empty string, zero, negative, `None`/`null`, max int, Unicode, emoji, RTL text
- Stateful object with ≥3 mutating methods and no model-based or stateful PBT test
- Test file imports no PBT framework but module matches any trigger category above

---

## Framework Reference (2025–2026)

| Language | Library | Status | Notes |
|---|---|---|---|
| Python | `hypothesis` | Active, thriving | Best-in-class; `st.builds()`, `@settings`, shrinking are excellent |
| JS / TS | `fast-check` | Active, good ecosystem | `fc.property()`, `fc.asyncProperty()`; works with Jest/Vitest |
| Rust | `proptest` | Standard choice | Prefer over `quickcheck` for complex domains; good shrinking |
| Java | `jqwik` | Maintenance-only | No new features unless funded; still usable |
| Go | `rapid` | Most active Go PBT | Prefer over `gopter`; good shrinking support |
| Scala | `ScalaCheck` | Stable | Backs Scala's std property tests |
| Haskell | `QuickCheck` | Stable/canonical | Original PBT library; others derive from it |

---

## Impact Data

- Each PBT property finds ~50x as many mutations as the average unit test (mutation testing benchmarks).
- Agentic PBT (Hypothesis + LLM agent) found valid bugs at ~$9.93/bug across 100 Python packages.
- 86% validity rate for top-scored LLM-generated PBT findings.

Use these numbers when justifying severity or estimating effort-to-impact ratio in review findings.

---

## When PBT is Overkill

Do NOT flag missing PBT for:

- Simple CRUD with no transformation logic (test the HTTP layer, not PBT)
- UI rendering / component snapshot tests
- External API wrappers (test the contract / mock, not the wrapper internals)
- One-off scripts or glue code
- Code where the simplest reference model is as complex as the implementation itself

---

## Reviewer Actions (Checklist)

1. Scan source files for Trail of Bits trigger categories.
2. For each match, open the corresponding test file and check for PBT framework imports (`hypothesis`, `fast-check`, `proptest`, `jqwik`, `rapid`, etc.).
3. **No PBT import found** → flag MEDIUM finding; recommend the most applicable pattern from the 7 above; name the specific function(s) affected.
4. **Roundtrip gap** → any encode/decode or serialize/deserialize pair with only example-based tests gets a dedicated roundtrip finding.
5. **Stateful gap** → any class/struct with ≥3 mutating methods and no stateful/model-based PBT gets a model-based finding.
6. **Security or financial code** → upgrade finding to HIGH; note mutation-testing impact data in the finding body.
7. **Already has PBT** → check generator quality: are edge cases covered (`min_size=0`, empty string, boundary values)? Weak generators downgrade coverage.
