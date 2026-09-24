# Better explainers for understanding code

Research synthesis, 9 September 2026.

**Recommendation:** use a guided, source-linked example with visible execution state, then let the reader change a cause and test a prediction. Choose the visual form according to the question: tracing a function, understanding an asynchronous lifecycle, comparing implementations, or navigating a subsystem.

There is no established universal best explainer. This is a targeted review of first-party exemplars, programming-education research, and program-comprehension studies, not an exhaustive systematic review or head-to-head benchmark. Most education evidence concerns novices; adapting it to an experienced developer learning unfamiliar production code requires judgment. The public pages were read, but their interactive controls were not browser-tested during this review.

## The exemplars I would borrow from

These are selected for complementary teaching mechanics, not ranked by popularity or proven learning gains.

| Exemplar | What to borrow | Best use and limitation |
|---|---|---|
| [Python Tutor](https://pythontutor.com/visualize.html) | Synchronized source, stack, heap, references, and output, with reversible execution steps. | Function mechanics, recursion, aliasing, and mutation. Extract a small relevant program; its representation is not a whole-service architecture model. |
| [Jake Archibald: Tasks, microtasks, queues and schedules](https://jakearchibald.com/2015/tasks-microtasks-queues-and-schedules/) | Output prediction followed by a stepped timeline of code, queued work, stack, and logs; harder cases follow. | Async ordering and lifecycle. Its browser comparisons are historical; reproduce the pattern using current semantics and verified traces. |
| [Red Blob Games: Introduction to A*](https://www.redblobgames.com/pathfinding/a-star/introduction.html) | Draggable inputs, visible frontier, small code snippets, and comparisons where a harder map exposes a simpler algorithm's weakness. | Algorithms and tradeoffs. Keep the model's boundary explicit: graph search is only one part of movement behavior. |
| [Josh W. Comeau: Why React Re-Renders](https://www.joshwcomeau.com/react/why-react-re-renders/) | One evolving example, an interactive component-tree model plus a console-instrumented code playground, and successive misconceptions about propagation. | Framework behavior and change impact. Verify current framework/compiler behavior rather than copying historical claims. |
| [React: State as a Snapshot](https://react.dev/learn/state-as-a-snapshot) | A mental model, concrete code, output predictions, substitution of actual values, and a new challenge with a solution reveal. | A particularly practical template for explaining a small piece of application code. Map the lesson back to the actual application's values and lifecycle. |
| [Sam Who: Hashing](https://samwho.dev/hashing/) | Begin with a deliberately weak implementation; compare input distributions, expose its limitation, and build toward a useful data structure. | Explaining why an implementation or abstraction exists. Distinguish properties demonstrated by selected inputs from general guarantees. |
| [Bartosz Ciechanowski: Alpha Compositing](https://ciechanow.ski/alpha-compositing/) | Connect a manipulable visual result to parameters and mathematical representations; contrasting representations exposes artifacts. | Graphics and numerical code. Add exact source locations and data values when adapting the technique to a repository. |
| [Learn Git Branching](https://learngitbranching.js.org/?locale=us), [source repository](https://github.com/pcottle/learnGitBranching) | Explicit target states, commands that transform a graph, undo/reset, and both guided exercises and free exploration. | State machines and operational practice. A simulation must describe its omissions; solving it is not proof of real-system competence. |
| [VisuAlgo: DFS/BFS](https://visualgo.net/en/dfsbfs) | Lecture and exploration modes, editable examples, code/status panels, and controlled playback. | Structured algorithm lessons. Borrow the coordinated representations selectively rather than reproducing an entire teaching platform. |

Two useful companions: [Bret Victor's Learnable Programming](https://worrydream.com/LearnableProgramming/) argues for making vocabulary, flow, and state inspectable. [Julia Evans's Patterns in confusing explanations](https://jvns.ca/blog/confusing-explanations/) is a practical editorial checklist for missing examples, unexplained terms, and inconsistent assumptions about the reader. Both are design guidance, not experimental proof.

## What the learning evidence actually supports

| Finding | Evidence and boundary | Consequence for our templates |
|---|---|---|
| Explain purpose in meaningful chunks. | A 265-student introductory-programming study found better quiz performance with subgoal labels, but no higher average exam performance. Course-section assignment was not randomized. [Margulieux, Morrison & Decker, 2020](https://link.springer.com/article/10.1186/s40594-020-00222-7). | Group source by purpose such as validate, select, persist, and clean up. Explain the reason for each group. |
| Teach a tracing method and externalize state. | A randomized study of 24 CS1 novices found higher tracing scores after a short explicit strategy intervention using an external memory representation. Small, bounded tasks; not a trial of HTML steppers. [Xie, Nelson & Ko, 2018](https://faculty.washington.edu/ajko/papers/Xie2018TracingStrategies.pdf). | Show changing values beside active code, with a causal explanation and replay controls. |
| Reading, prediction, investigation, and modification can form a useful progression. | PRIMM was evaluated with 493 pupils aged 11–14 across 13 schools over 8–12 weeks; the intervention group did better on the post-test. Teacher/peer dialogue and the whole intervention matter; individual steps were not isolated. Institutional abstract inspected. [Sentance, Waite & Kallia, 2019](https://eprints.gla.ac.uk/229013/). | Offer a short prediction, inspect the result, then change one condition. Adapt rather than claim to reproduce the classroom intervention. |
| Animation alone does not reliably improve learning. | A meta-study of 24 algorithm-visualization experiments found mixed results and emphasized learners' activities over display features. This older heterogeneous synthesis is not a modern pooled effect-size estimate. [Hundhausen, Douglas & Stasko, 2002](https://faculty.cc.gatech.edu/~stasko/papers/jvlc02.pdf). | Each interaction should help answer a question, generate an explanation, or test an input. |
| Runtime traces can help with comprehension beyond beginner exercises. | An Eclipse/Extravis experiment on eight comprehension tasks reported 22% less time and 43% greater correctness with trace visualization. These are relative results for that tool, system, and task set; the institutional abstract does not establish a general learning effect. [Cornelissen, Zaidman & van Deursen, 2011](https://repository.tudelft.nl/record/uuid:6d3ac25b-ac24-47e9-adff-595e5da3c5b6). | Anchor a subsystem explanation in one concrete execution, preserving its source and observation boundary. |
| An explicit investigation path can help, but can also constrain. | A formative evaluation with 28 developers found better bounded task performance using explicit strategies, with work experienced as more organized and more constrained. [LaToza et al., 2019](https://arxiv.org/abs/1911.00046). | Provide a recommended route, plus immediate access to source and free exploration. |
| Additional diagrams are not automatically beneficial. | A controlled experiment and replication involving student maintainers found benefits varied with experience; less experienced participants took longer with UML support. Publisher abstract inspected. [Source-code comprehension tasks supported by UML design models, 2015](https://doi.org/10.1016/j.jvlc.2014.12.004). | Use notation the reader can interpret and reveal only the relationships needed for the question. |

The [ICAP framework](https://education.asu.edu/sites/default/files/lcl/chiwylie2014icap_2.pdf) adds a useful distinction: moving controls is not the same as generating an explanation, and its “interactive” category refers to productive dialogue, not clickable UI. It is a cross-domain theoretical synthesis, not a ranking of code-explainer layouts. Our inference is to include optional causal explanation or counterexample prompts, with reasoned feedback.

For actual repository exploration, [Sillito, Murphy & De Volder's studies](https://www.cs.ubc.ca/~murphy/papers/other/asking-answering-fse06.pdf) catalogued 44 kinds of questions developers asked during change tasks. Their observations motivate organizing by questions and relationships rather than file order. [Whyline](https://www.cs.cmu.edu/~NatProg/whyline.html) provides a related research prototype: start from an observed output and trace why it happened, or why an expected event did not. Neither establishes that a generated HTML explanation reproduces those tools' benefits.

## A reusable learning sequence

This is my synthesis, not a published intervention validated as a package:

**Question → concrete case → purpose-labeled code → visible state → changed cause → new-case check → real source.**

For you, default to an experienced programmer who may be unfamiliar with the subsystem. Surface domain terminology, contracts, ownership, side effects, invariants, and failure behavior. Collapse familiar syntax. Let familiarity with the particular concept, not a permanent beginner/expert label, determine the help offered.

Start with the behavior you want to understand. “Why does this request retry after cancellation?” is a better organizing question than “What is in these seven files?” Give the minimum context needed, then follow one case. Expand into architecture when it resolves a real question.

Preserve two reading paths: a coherent explanation that works immediately, and an optional exploration path for hypotheses and edge cases. A prediction should invite thought, not block access. A selected answer should receive a causal explanation, not only a correctness badge.

Use concrete representations together: the same named value in the input, source, runtime state, and output. The reader should be able to point from an effect back to its cause. Introduce abstraction after the example establishes why it is useful.

## Eight templates to choose from

Detailed construction instructions, prompts, failure modes, and verification requirements are in [Code learning templates](code-learning.md).

| Template | Use it to answer | Essential interaction |
|---|---|---|
| Annotated worked example | What does this function accomplish, and why? | Select a meaningful code chunk and see its values and purpose. |
| Execution and state | What happens on each call or iteration? | Reversible steps synchronize code, state, and output. |
| Counterfactual comparison | Why does this version behave differently? | Same input, one changed cause, first divergent event. |
| Data provenance | Where did this value come from? | Follow one field across source-linked transformations. |
| Lifecycle and schedule | What happens under retries, cancellation, or concurrency? | Choose a relevant event ordering and inspect ownership and cleanup. |
| Guided codebase journey | Where does this feature live? | Follow a concrete scenario from entry point to outcome. |
| Build toward the abstraction | Why do we need this layer or algorithm? | Expose a limitation, then add the part that addresses it. |
| Faded practice | Can I use this idea independently? | Move from a worked case to a small new prediction or modification. |

Choose one primary template and a companion where needed. Six tabs, a dependency graph, a quiz, and a playground are not universal requirements. A short code explanation may need only an annotated example and a revealing counterexample.

## Technical approach for dependable HTML

The implementation should make correct exploration cheap. [Amit Patel's Little Design Things](https://www.redblobgames.com/making-of/little-things/) provides particularly useful practitioner guidance: deterministic behavior, useful static content, nearby consequences of controls, valid inputs, and low build complexity. The [Distill article on interactive communication](https://distill.pub/2020/communicating-with-interactive-articles/) connects examples to research while acknowledging authoring cost, accessibility, longevity, and the possibility that interactivity distracts or goes unused. These support a small, maintainable implementation; they do not establish one winning JavaScript stack.

Recommended engineering contract:

- **One source of truth:** source highlighting, state tables, diagrams, and output derive from the same selected event. Avoid separately authored animations that can drift from the code.
- **Honest provenance:** distinguish live execution, a recorded trace, and an illustrative simulation. Preserve the repository revision, symbol, scenario input, and source links. A recorded replay should not pretend to run arbitrary edited code.
- **Meaningful controls:** offer supported cases, bounded parameters, reset, and reversible steps. Use seeded randomness and logical time when reproducibility matters. Keep a control's effect visible nearby.
- **Simple rendering:** semantic HTML, inline CSS, and SVG/DOM widgets by default. Use heavier rendering or an embedded runtime only when the subject requires it. Keep a text/state-table equivalent for essential graphics.
- **Source fidelity:** verify representative outputs and key transitions against the original code. If using a browser reimplementation, check language/framework semantics rather than assuming a plausible animation is accurate.
- **Desktop usability:** inspect all views and consequential states around 1440px width. Check keyboard access, contrast, reduced motion, and readable print/static output. Avoid forcing scroll position to control execution time.

These are implementation recommendations synthesized for our standalone-artifact workflow, not comparative performance findings.

## How to judge whether an explainer worked

A useful acceptance task is a new case: predict its behavior, explain the causal step, and identify the source location responsible. For change-oriented work, ask where to modify the code and what else would be affected. Check the answer against the source or a real execution.

Screenshots establish visual legibility. Trace checks establish selected behavioral correspondence. Neither establishes a learning gain. To evaluate the personal learning experience, use a small unfamiliar case after reading, and occasionally revisit it later without the explanation. Change the template when it fails that task, rather than adding more animation.

## Recommended starting points

For an immediately reusable model, read React's *State as a Snapshot*. For execution visualization, inspect Python Tutor and Archibald. For algorithm comparisons, use Red Blob; for progressive construction, use Sam Who. Read Victor and Patel for design reasoning, and the empirical table above for confidence boundaries.

The global `html-explainer` skill now routes code-understanding requests to these templates while retaining the original atlas layout for broad system reference. The blueprints are design specifications; this research did not implement or browser-test eight new HTML applications.
