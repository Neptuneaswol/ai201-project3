# TakeMeter

A fine-tuned text classifier that scores discourse quality on Hacker News — does a comment engage substantively, dismiss without argument, or hype without substance?

## Community

**Hacker News comment threads.** The original plan was a subreddit, but reddit.com turned out to be completely unreachable from the environment used to build this project, so the community was switched to Hacker News. HN is a strong fit for a discourse-quality classifier: its comment sections genuinely span the full range this project is after — deeply substantive technical/firsthand-experience comments sit right next to drive-by snark and product-hype comments in the same thread. HN's own moderation culture (the site guidelines and moderator "dang"'s public comments) explicitly treats low-effort dismissiveness and unsubstantiated hype as recognized, named failure modes, so the distinction measured here is one the community already cares about, not one invented from outside.

## Label Taxonomy

| Label | Definition | Example 1 | Example 2 |
|---|---|---|---|
| `substantive` | Engages with the specifics of the post/thread using reasoning, evidence, or firsthand experience, even if brief. | "I ran this exact migration at my last job on a 40M row table — the issue isn't the index, it's that the ALTER TABLE takes a write lock for the full duration on MySQL 5.7." | "The benchmark numbers don't control for cold start — Lambda's first invocation after a deploy is always 3-5x slower regardless of runtime." |
| `dismissive` | Low-effort negativity or snark with no supporting argument, evidence, or reasoning — rejects without engaging. | "This again? We've seen this exact post six times this year." | "lol no. This will never work in prod." |
| `hype` | Enthusiastic, boosterish reaction to a product/company/technology with no specific reasoning or evidence beyond excitement. | "This is going to change everything. Incredible work, can't wait to see where this goes!" | "Insanely good. We need this yesterday. Take my money." |

**Hardest edge case**: a comment that's enthusiastic *and* gives a specific reason (e.g. "This is huge — finally a vector DB that doesn't choke past 10M rows, we benchmarked it at 200ms p99 vs. 1.4s"). **Decision rule: specificity beats tone.** A checkable claim (a number, a named mechanism, a firsthand test) makes a comment `substantive` regardless of how enthusiastic or harsh it reads. Full reasoning and four more boundary cases are in [`planning.md`](planning.md).

## Dataset

- **Source**: `hacker-news.firebaseio.com/v0/` — HN's public Firebase API. No auth required; returns exact comment text verbatim (HTML-entity decoded before saving). Collection script: [`scripts/collect_hn_data.ps1`](scripts/collect_hn_data.ps1) (plus a follow-up Show-HN-weighted pass, inline in the project log — see `CLAUDE.md`).
- **Process**: pulled a diverse mix of front-page, Show HN, and Ask HN threads (740 raw candidates total), then hand-labeled every candidate against the definitions above. `hype` turned out to be genuinely rare on HN relative to `substantive`/`dismissive`, so a second collection pass specifically oversampled Show HN threads (where product-hype comments concentrate) to get enough examples of that class. [`scripts/build_dataset.ps1`](scripts/build_dataset.ps1) applies the manual label decisions and samples the substantive majority down to a manageable, balanced size.
- **Final dataset**: [`data/takemeter_dataset.csv`](data/takemeter_dataset.csv) — **255 examples**.

| Label | Count | % |
|---|---|---|
| substantive | 175 | 68.6% |
| hype | 42 | 16.5% |
| dismissive | 38 | 14.9% |

No label exceeds 70% of the dataset.

**Difficult examples** (full list of 5 in `planning.md`):
1. *"Can't run this myself. But I do like Unsloth Studio, quite a lot. It's nicely designed."* — positive tone, no checkable claim. Decided: `hype`.
2. *"...Is it just me or is it weird seeing these clickbaity AI-generated taglines in an otherwise scientific work?"* — reads as snarky, but quotes specific text and makes a checkable observation about it. Decided: `substantive` (specificity over tone).
3. *"Original source (please submit) (42 points, 2 days ago, 4 comments) [link]"* — a meta-moderation comment, not an opinion about the topic at all. Doesn't fit any of the three labels. Decided: **excluded** from the dataset rather than forced.

## Fine-Tuning Approach

- **Base model**: `distilbert-base-uncased` (HuggingFace), fine-tuned with a 3-class classification head.
- **Platform**: Google Colab, free T4 GPU. Notebook: [`notebook/takemeter_finetune.ipynb`](notebook/takemeter_finetune.ipynb).
- **Training setup**: 70/15/15 stratified train/val/test split (178/38/39 examples), 3 epochs, learning rate 2e-5, batch size 16 (the notebook's defaults).
- **Key hyperparameter decision and observation**: the defaults were kept as-is for this run, but in hindsight, given that `dismissive` has only ~27 training examples (the smallest class by a wide margin — see Evaluation below), **more epochs or class weighting would likely have been the more important hyperparameter to tune**, not learning rate or batch size. With only 3 epochs and no class weighting, the model never learned to predict `dismissive` at all (see below) — that's the lesson this run's hyperparameter choice actually teaches.

## Baseline Comparison

- **Model**: Groq's `llama-3.3-70b-versatile`, zero-shot (no task-specific training).
- **Prompt**: the system prompt gives the model the community context, all three label definitions verbatim (matching `planning.md`), one example per label, and the specificity-over-tone decision rule, then instructs it to respond with only the label name. Full prompt is in the notebook's Section 5 cell.
- **Collection**: every one of the 39 locked test-set examples was sent through the same prompt before any fine-tuning happened, so the baseline numbers below could not have been influenced by the fine-tuned model's behavior.

## Evaluation Report

### Overall Accuracy

| Model | Accuracy |
|---|---|
| Zero-shot baseline (Groq `llama-3.3-70b-versatile`) | **0.923** |
| Fine-tuned DistilBERT | **0.744** |

**The fine-tuned model performed *worse* than the zero-shot baseline by 17.9 percentage points.** This is not the result this project is supposed to produce, and the spec is explicit that a regression like this is a signal to investigate, not bury — see the Reflection section below for the diagnosis.

### Per-Class Metrics

**Baseline (Groq, zero-shot):**

| Label | Precision | Recall | F1 | Support |
|---|---|---|---|---|
| substantive | 0.93 | 0.96 | 0.95 | 27 |
| dismissive | 1.00 | 0.80 | 0.89 | 5 |
| hype | 0.86 | 0.86 | 0.86 | 7 |

**Fine-tuned DistilBERT:**

| Label | Precision | Recall | F1 | Support |
|---|---|---|---|---|
| substantive | 0.88 | 0.85 | 0.87 | 27 |
| dismissive | **0.00** | **0.00** | **0.00** | 5 |
| hype | 0.46 | 0.86 | 0.60 | 7 |

### Confusion Matrix (Fine-Tuned Model, Test Set)

| True ↓ / Predicted → | substantive | dismissive | hype |
|---|---|---|---|
| **substantive** | 23 | 0 | 4 |
| **dismissive** | 2 | 0 | 3 |
| **hype** | 1 | 0 | 6 |

The `dismissive` row never lands on the diagonal — **every single `dismissive` test example was misclassified**, 3 as `hype` and 2 as `substantive`. The model never predicted `dismissive` for *any* test example, correct or not (column sum = 0).

### Specific Wrong Predictions Analyzed

1. **"if sam altman didnt exist i could afford to run this"** — True: `dismissive`. Predicted: `hype` (confidence 0.35). *Why it failed*: this is a terse, sarcastic one-liner — exactly the `dismissive` archetype — but it has no negative-sentiment words at all (no "bad," "wrong," "never," etc.). The model appears to be leaning on surface lexical cues for `hype` vs. `dismissive` rather than the actual pragmatic function (snark vs. boosting), and a joke with no explicit negativity markers gets swept toward whichever class the model treats as its default for ambiguous/short text.
2. **"Cyberdecks are nice for photos and build blog posts, but does anyone actually regularly use them?"** — True: `dismissive`. Predicted: `substantive` (confidence 0.35). *Why it failed*: the comment is structured like a real question ("does anyone actually use them?"), which superficially resembles the question-asking pattern common in genuine `substantive` comments elsewhere in the dataset. The model likely picked up on sentence structure (a question with some topic-specific vocabulary) rather than the fact that the question is rhetorical and contains no argument of its own.
3. **"Chevron and Microsoft agree to keep smoking crack and buy it for each other when needed and not tell anyone."** — True: `dismissive`. Predicted: `substantive` (confidence 0.35). *Why it failed*: this is a sarcastic metaphor with no literal claim, but it's long-ish and references specific named entities (Chevron, Microsoft) — surface features the model may associate with `substantive` (which often cites specific companies/products as part of real evidence), without distinguishing "names a company as part of an argument" from "names a company as the target of a joke."

**Is this a labeling problem or a model problem?** It's a model problem, not a labeling inconsistency — all three of the misses above were labeled correctly and consistently against the `planning.md` definitions (terse jokes, rhetorical dismissals, and sarcastic metaphors are squarely "low-effort negativity... no supporting reasoning" under the `dismissive` definition). The issue is that `dismissive` had only ~27 training examples — the smallest class by a wide margin — and the boundary it needs to learn (pragmatic function: snark vs. earnest engagement) is exactly the kind of subtlety that benefits from being spelled out explicitly, which is what the Groq baseline gets for free in its prompt and what DistilBERT has to infer purely from a handful of labeled examples.

**What would fix it?** More `dismissive` training examples (the single biggest lever, given the class has 5x fewer examples than `substantive`), and/or class weighting or oversampling during training to stop the loss from being dominated by the majority class.

### Sample Classifications

Five new (not in the training/test data) comments run through the deployed Gradio interface (Section 7):

| # | Comment | Predicted | Confidence | Correct? |
|---|---|---|---|---|
| 1 | "I ran this in prod for 6 months, the p99 latency was 40ms" | substantive | 0.349 | ✅ Yes |
| 2 | "This changes everything, absolutely incredible!!" | hype | 0.358 | ✅ Yes |
| 3 | "meh, seen this a hundred times" | hype | 0.357 | ❌ No (expected `dismissive`) |
| 4 | "Does this support OAuth login?" | hype | 0.356 | ❌ No (expected `substantive` — a specific, on-topic technical question) |
| 5 | "if sam altman didnt exist i could afford to run this" | hype | 0.348 | ❌ No (expected `dismissive`) |

**Why #2 is reasonable**: "This changes everything, absolutely incredible!!" is a textbook `hype` comment — pure enthusiasm, exclamation points, no specific claim about *what* changes or *how* — so the model getting this one right, even at low confidence, lines up with the definition.

**The more important finding from this set**: look at the full class-probability breakdown, not just the winning label. All five comments — a firsthand latency report, an enthusiastic one-liner, a dry dismissal, a neutral technical question, and a sarcastic joke — produce probabilities clustered tightly between **0.30 and 0.36 for every class, every time**. The model isn't confidently right or confidently wrong on any of them; it's barely separating the three classes at all on genuinely new text, and "hype" wins 4 of 5 simply by being the slightly-larger of three nearly-equal numbers. This is a stronger and more direct demonstration of the same problem the confidence-calibration table shows on the locked test set: the model did not converge on real decision boundaries.

### Confidence Calibration (Stretch Feature)

| Confidence bucket | N | Accuracy |
|---|---|---|
| <0.50 | 39 | 0.744 |
| 0.50–0.70 | 0 | n/a |
| 0.70–0.85 | 0 | n/a |
| 0.85–1.00 | 0 | n/a |

**Finding: confidence is not meaningful in this run.** Every single one of the 39 test predictions — correct and incorrect alike — falls below 0.50 confidence (the individual wrong-prediction confidences above are all 0.35–0.36, barely above the 1-in-3 random baseline for a 3-class problem). There's no spread to bucket, which means the model isn't just sometimes wrong with high confidence — it's *never* confident, even when it happens to be right. A 90%-confident prediction doesn't exist in this run to compare against a 60%-confident one. This is itself diagnostic: it suggests the fine-tuned model didn't converge on a strong decision boundary for any class, consistent with the regression in overall accuracy.

### Error Pattern Analysis (Stretch Feature)

The systematic pattern, verified by re-reading every wrong prediction (not just the first one): **the model collapsed the `dismissive` class entirely**, splitting its examples between `hype` (3/5) and `substantive` (2/5), and never predicting `dismissive` once across the whole test set. Looking at *which* `dismissive` examples went where: the ones with longer sentence structure or named entities (companies, products) were pulled toward `substantive`; the shorter, punchier one-liners were pulled toward `hype`. This suggests the model partially learned "shortness + emphasis → hype" and "length + named entities → substantive" as shortcuts, neither of which is the actual distinguishing feature of `dismissive` (lack of supporting argument) — it learned correlated surface features instead of the underlying pragmatic distinction.

Testing 5 brand-new comments through the deployed interface (Sample Classifications, above) sharpened this further: it isn't only `dismissive` that the model struggles to separate — **the model barely separates *any* of the three classes on new text.** Every one of the 5 new comments produced class probabilities clustered between 0.30 and 0.36, regardless of how clear-cut the comment was (a firsthand latency number vs. a dry one-word dismissal vs. a neutral technical question). `hype` won 4 of 5 simply by edging out the other two by a few hundredths. So the more precise version of the pattern is: **the model learned a weak, slightly-better-than-chance signal for `substantive` and `hype`, essentially no usable signal for `dismissive`, and defaults to `hype` under uncertainty** — which is consistent with `hype`'s unusually low precision (0.46) despite respectable recall (0.86) in the per-class metrics above: it's catching real `hype` examples, but it's also the bucket everything uncertain falls into.

### Deployed Interface (Stretch Feature)

Section 7 of [`notebook/takemeter_finetune.ipynb`](notebook/takemeter_finetune.ipynb) adds a Gradio interface that loads the fine-tuned model directly from the Colab session's memory and classifies new text with label + full class-probability breakdown. No separate hosting required — runs inline in the same notebook session immediately after training.

## Reflection: What the Model Learned vs. What Was Intended

The intent was for the model to learn the *pragmatic function* of a comment — whether it argues, dismisses, or boosts — independent of surface features like length or topic. What it actually learned, based on the confusion matrix, error analysis, and the live Sample Classifications test above, is **a weak, barely-above-chance signal, not a real decision boundary.** The clearest evidence isn't just that `dismissive` recall is exactly 0 (not low — zero) while `hype` still achieved 0.86 recall on the locked test set; it's that on five brand-new comments tried live, the model's own predicted probabilities sat within a few hundredths of each other across all three classes every single time, including for a comment that should have been unambiguous ("This changes everything, absolutely incredible!!" scored only 0.358 for `hype` against 0.334 for `substantive`). The model isn't confidently capturing "boosts a product" vs. "dismisses without argument" vs. "argues with evidence" — it's making a coin-flip-with-a-thumb-on-the-scale guess every time, and `hype` happens to be the side the thumb favors when the model is unsure, which is most of the time. That thumb-on-the-scale bias is consistent enough to explain `hype`'s respectable recall (0.86) alongside its poor precision (0.46): it catches real hype examples, but it also absorbs everything the model can't otherwise place. This is a distributional/data problem rather than a labeling problem (see the wrong-prediction analysis above) or a task-impossibility problem — the Groq baseline, given the same definitions in its prompt, classified `dismissive` at 0.89 F1 with no training at all, so the task itself is learnable; this particular run, with this little data for the smallest class and only 3 epochs, did not learn it.

## Spec Reflection

**How the spec helped**: the explicit instruction to "read 30-40 posts before committing to labels" (and the parallel instruction to collect real data before annotating) is what surfaced, early, that genuine `hype` is rare on Hacker News relative to `substantive` and `dismissive` — without that step, the first data-collection pass would have produced an unusably hype-starved dataset, and the problem wouldn't have been caught until much later.

**Where the implementation diverged from the spec, and why**: the spec's example community and label set are all Reddit-based (e.g. r/nba's "hot take vs. analysis"). Reddit was completely unreachable from this project's working environment (confirmed via both direct HTTP requests and an AI web-fetch tool — every reddit.com subdomain failed, while general web access worked fine). The community was switched to Hacker News rather than working around the block, because HN has a public, no-auth API that returns exact verbatim text — a more reproducible and more defensible data source than trying to route around a network restriction.

## AI Usage

This project's primary workflow — figuring out labels, collecting data, annotating, and analyzing results — was done by an AI assistant (Claude) directing itself through the milestones, with the student reviewing and approving each milestone before the next began (recorded in `CLAUDE.md`'s project log) and personally running the GPU-dependent Colab steps. Two specific instances of AI tool use, with what was reviewed/overridden:

1. **Label stress-testing**: before annotating real data, the assistant generated several boundary-case Hacker-News-style comments to test the `substantive`/`hype` and `substantive`/`dismissive` lines. This produced the specificity-over-tone decision rule in `planning.md` — the first draft of the labels didn't have an explicit rule for tone vs. specificity, and the generated edge cases exposed that gap before 255 real examples were annotated against an incomplete definition.
2. **Annotation**: the assistant performed first-pass — and, in this workflow, *only*-pass — labeling of the entire 255-example dataset directly against the `planning.md` definitions; there was no separate human-reviews-AI-pre-labels step. This is disclosed here rather than implied to be human-verified: it is a real limitation of this submission, and a stronger version of this project would have the student spot-check a sample of the labels before relying on them for fine-tuning.

Beyond the dataset, the assistant also diagnosed the fine-tuning regression (Reflection section above) by reading the confusion matrix, per-class metrics, and the specific wrong-prediction texts together, rather than accepting "fine-tuning regressed because the run was unlucky" as an explanation — the student reviewed this diagnosis and it is presented above as the project's central finding rather than an after-the-fact excuse.

## Repository Structure

```
ai201-project3-takemeter/
  README.md                      this file
  planning.md                    pre-annotation design doc (labels, edge cases, AI tool plan)
  CLAUDE.md                       project log + video guide
  data/
    takemeter_dataset.csv         255 labeled examples (final dataset)
    hn_raw_candidates.csv         raw candidate pool, pass 1 (557 comments)
    hn_extra_show.csv             raw candidate pool, pass 2, Show-HN-weighted (183 comments)
  scripts/
    collect_hn_data.ps1           HN data collection (pass 1)
    build_dataset.ps1             applies label decisions, builds final dataset
  notebook/
    takemeter_finetune.ipynb      fine-tuning + baseline + evaluation + stretch features
  evaluation_results.json         exported metrics from the Colab run
  confusion_matrix.png            confusion matrix image (supplementary to the markdown table above)
```
