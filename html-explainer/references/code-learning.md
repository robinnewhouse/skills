# Code learning templates

Use this reference when explaining a function, unfamiliar subsystem, code change, or runtime behavior. These are adaptable design blueprints synthesized from research and first-party exemplars, not a validated universal curriculum. Choose the smallest combination that answers the reader's question.

## Choose the learning task

| Reader's question | Primary template | Useful companion |
|---|---|---|
| What does this function do, and why? | Annotated worked example | One changed-input prediction |
| What happens on each iteration or call? | Execution and state | Boundary case |
| Why does this version behave differently? | Counterfactual comparison | First divergent event |
| Where did this value come from? | Data provenance | Source-linked transformation |
| What happens with retries, cancellation, or concurrency? | Lifecycle and schedule | Duplicate or reordered event |
| Where does this feature live across files? | Guided codebase journey | One concrete execution |
| Why do we need this abstraction? | Build toward the abstraction | Failing simpler alternative |
| Can I apply the idea unaided? | Faded practice | New input or small modification |

## Default lesson shape

State one observable goal, the prerequisites that matter, and the source revision. Start with a concrete input and expected behavior. Explain one worked path through meaningful subgoals; offer a prediction before revealing a consequential transition. Let the reader change one cause and inspect its effect. Finish with a different case and a route back into the real source.

For a developer familiar with the language, collapse syntax help and foreground invariants, side effects, ownership, failure paths, and change impact. Keep an immediately readable explanation and optional deeper exploration. Prediction exercises are skippable; the page remains useful as a reference.

## 1. Annotated worked example

**Use:** one function or a compact chain of calls. **Layout:** source beside a short explanation and concrete values. Group lines by purpose, such as validate input, choose route, update state, or emit result. Selecting a subgoal highlights its lines and associated data. Explain why it is needed, not merely what syntax says.

**Prompt:** “Which input takes the early return, and what work does that avoid?” **Check:** a new case that reaches a different branch. **Avoid:** a comment for every line, unrelated implementation detail, or assuming language fluency implies domain knowledge.

## 2. Execution and state

**Use:** loops, recursion, references, mutation, parsing, or event handling. **Layout:** source, current state, and output synchronized by a single selected event. Show the values that changed and why, with previous/next/reset and a compact history. Name the selected line as about to execute or just executed.

Show object identity and aliases when mutation matters. Offer subgoal-sized steps before exposing every instruction. **Prompt:** “What changes on the next step, and what stays the same?” **Check:** predict the outcome for a fresh input. **Avoid:** autoplay as the only control or a huge unfiltered heap dump.

## 3. Counterfactual comparison

**Use:** bug/fix, API alternatives, data structure tradeoffs, or a misleading mental model. **Layout:** two runs sharing an input and aligned at meaningful events. Highlight the smallest code or parameter difference and the first behavioral divergence. Explain the causal chain from that difference to the outcome.

**Prompt:** “Find an input where these versions disagree.” **Check:** a counterexample plus the condition under which the versions agree. **Avoid:** changing several causes at once or claiming equivalence from a few examples. Compare operation counts or measured timings only when defined and actually obtained.

## 4. Data provenance

**Use:** request handling, transformations, schemas, SQL, or connector boundaries. **Layout:** follow one named value through input, validation, transformation, storage, and output as applicable. Selecting a field reveals its source, transformation, and destination, with exact snippets and sample values.

**Prompt:** “Which stage introduced this value or dropped this field?” **Check:** trace a second value or invalid input. **Avoid:** equating a static dependency arrow with an observed runtime transfer; mark unobserved steps and schema conversions explicitly.

## 5. Lifecycle and schedule

**Use:** asynchronous code, resources, transactions, retries, and cancellation. **Layout:** named actors or resources, explicit states, and a logical event timeline. Select a supported schedule to reveal happens-before constraints, ownership transfers, cleanup, and terminal states. Distinguish possible interleavings from recorded ones.

**Prompt:** “If cancellation arrives here, who owns cleanup?” **Check:** a duplicate, delayed, failed, or reordered event that matters to the actual code. **Avoid:** implying a single animation covers all legal schedules, or using playback time as a claim about runtime duration.

## 6. Guided codebase journey

**Use:** a feature spanning files or services. **Layout:** a small context map plus a scenario-led path from entry point to visible outcome. Each stop links to a symbol and explains its contract, caller, relevant state, and next handoff. Offer expansion into adjacent code without losing the selected scenario.

**Prompt:** “Where would you change this behavior, and which caller would notice?” **Check:** locate the modification point and an affected test or consumer. **Avoid:** an exhaustive dependency graph as the first screen. A map explains structure; a trace explains one execution.

## 7. Build toward the abstraction

**Use:** an algorithm, interface, or optimization whose purpose is unclear. **Layout:** concrete example, simplest viable implementation, revealing limitation, minimal extension, then production implementation. Show each addition beside the problem it solves and map simplified names back to real symbols.

**Prompt:** “What breaks if this layer is removed?” **Check:** recognize when the simpler version is sufficient. **Avoid:** silently replacing real behavior with a toy, or presenting an abstraction as inevitable when it is a tradeoff.

## 8. Faded practice

**Use:** optional consolidation after a worked example. Reveal less help across tasks: explained solution, missing condition or step, then a small new task. Use output prediction, a one-line change, or ordering a few meaningful code blocks. Provide hints and causal feedback; retain a show-answer option.

**Prompt:** “Explain why this condition belongs before that mutation.” **Check:** correct behavior on an unseen case and a defensible explanation. **Avoid:** grades, compulsory quizzes, click-based mastery scores, or requiring exact wording for a correct explanation. Use code-ordering exercises mainly when constructing code is itself the goal.

## Technical contract

For a small explainer, prefer plain HTML/CSS, SVG, and minimal JavaScript. Reuse the atlas starter's visual tokens and applicable components; reshape its navigation around the lesson instead of filling its sample tabs.

Represent a scenario with a source revision, input, provenance, and ordered events. An event can carry a source location, subgoal, relevant state before/after, output change, and causal explanation. All code highlighting, values, and diagrams derive from that selected event. Derived displays should not maintain competing copies of execution state.

Use recorded traces from a safely executed minimal example when feasible. Otherwise label a curated trace or simulation and its omissions. If the browser model reimplements a different language or framework, verify relevant semantics against the original runtime or explicitly narrow the claim. When input changes, recompute the trace or constrain the control to supported recorded cases.

Include ordinary and revealing boundary/failure cases. Check their final outputs and key transitions against the source; validate that reset and reverse navigation restore the same state. Seed randomness and control logical time where reproducibility matters. A source hash or commit, symbol, and verified line link make the explanation auditable.

A parameter control should expose a meaningful cause. Give it a label, bounds, reset, and visible consequence. Every important interaction must have a keyboard equivalent. Keep supplementary detail in accessible disclosure elements. Provide text/state tables for essential graphical information, reduced motion, and a readable print/static explanation. Extend tab keyboard behavior only when actually using tabs.

## Acceptance

The reader should be able to predict a different input, explain the causal step, and locate the relevant real code. For change-oriented explanations, add a concrete modification and its expected impact. These are evaluation tasks, not claims that a screenshot or model review proves learning.

Inspect each distinct view and consequential interaction state on desktop. Separately audit source fidelity and try the transfer questions without consulting the displayed answer. Record any missing runtime or browser verification. Do not label engagement, completion, or visual polish as comprehension.

For the primary studies, exemplar links, and evidence limits behind these choices, consult [Research synthesis](research.md).
