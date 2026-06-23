# TakeMeter — Planning

## Community

**Hacker News (news.ycombinator.com) comment threads.**

HN was the original target idea (a subreddit), but reddit.com turned out to be unreachable from my working environment, so I switched to HN — which has the same "discourse quality varies wildly" property the project asks for, plus a public, scrape-friendly API (`hacker-news.firebaseio.com`) that returns exact comment text with no auth required. HN is a good fit for a discourse-quality classifier because its comment sections genuinely span the full range the project is after: deeply substantive technical/firsthand-experience comments sit right next to drive-by snark and product-hype comments in the same thread, and HN's own moderation culture (the site guidelines, and moderator "dang"'s public comments) explicitly treats "low-effort dismissiveness" and "hype without substance" as recognized, named failure modes — meaning the distinction I'm measuring is one the community itself already cares about, not one I invented from outside.

## Labels

1. **`substantive`** — The comment engages with the specifics of the post or thread using reasoning, evidence, or firsthand experience, even if brief.
   - Example: "I ran this exact migration at my last job on a 40M row table — the issue isn't the index, it's that the ALTER TABLE takes a write lock for the full duration on MySQL 5.7. You want pt-online-schema-change or to wait for 8.0's instant DDL."
   - Example: "The benchmark numbers in the post don't control for cold start — Lambda's first invocation after a deploy is always 3-5x slower regardless of runtime, so this isn't really a Go vs. Python comparison, it's a cold-start comparison."

2. **`dismissive`** — Low-effort negativity or snark about the post/topic that contains no supporting argument, evidence, or specific reasoning — it rejects without engaging.
   - Example: "This again? We've seen this exact post six times this year."
   - Example: "lol no. This will never work in prod."

3. **`hype`** — Enthusiastic, boosterish reaction to a product, company, or technology that contains no specific reasoning or evidence beyond excitement — the positive mirror of `dismissive`.
   - Example: "This is going to change everything. Incredible work, can't wait to see where this goes!"
   - Example: "Insanely good. We need this yesterday. Take my money."

### Hardest anticipated edge case

A comment that is enthusiastic **and** gives a specific reason — e.g. "This is huge — finally a vector DB that doesn't choke past 10M rows, we benchmarked it at 200ms p99 vs. 1.4s on our current setup." This sits right on the `substantive`/`hype` line: it has the emotional register of hype but also a concrete, checkable claim (a benchmark number). **Decision rule: if a comment contains a specific, checkable claim (a number, a named mechanism, a firsthand test) it is `substantive` regardless of tone — enthusiasm alone does not disqualify a comment from `substantive`, and absence of any checkable claim is what makes something `hype` instead.** The same rule applies on the negative side: harsh-but-specific criticism ("this benchmark is misleading because it excludes index rebuild time") is `substantive`, not `dismissive` — tone is not the deciding signal for either boundary, specificity is.

## Data Collection Plan

- **Source**: `hacker-news.firebaseio.com/v0/` — HN's official public Firebase-backed API. No auth, no rate limit issues for this volume, returns the exact comment `text` field verbatim (HTML-entity encoded, which I decode before saving).
- **Method**: `scripts/collect_hn_data.ps1` pulls a diverse mix of story types — front-page tech/programming stories, Show HN (product launch) threads, and front-page stories on contentious/policy-adjacent topics — because each label concentrates in different thread types: `hype` is dense in Show HN comment sections, `dismissive` is dense in contentious/repetitive-topic threads, `substantive` is broadly distributed but especially dense in "Ask HN" and technical post-mortem threads. I deliberately sample across all three thread types so no label is starved.
- **Target**: collect a raw candidate pool of ~350–400 comments (after filtering out `[deleted]`/`[dead]`/empty and comments under ~10 words, which are usually unlabelable fragments), then hand-label down to 200+ for the final dataset.
- **If a label is underrepresented after the first pass**: pull additional comments specifically from the thread type that concentrates that label (e.g., more Show HN threads if `hype` is short) rather than relabeling borderline `substantive` comments into the underrepresented bucket just to hit a number.

## Evaluation Metrics

Accuracy alone is not enough here because the three labels are not equally easy to confuse in the same way — `dismissive` vs. `hype` are rarely confused with each other (opposite tone), but both are plausibly confused with `substantive` depending on phrasing, and the two confusions matter differently (e.g. the project's most interesting failure mode, a sarcastic substantive-sounding dismissal, would show up as a `substantive`→`dismissive` confusion). I will report:
- **Overall accuracy** for both models (a quick top-line comparison).
- **Per-class precision, recall, and F1** for all three labels (not just one) — this is the only way to see if the model is, say, great at `hype` but unable to learn `dismissive`, which a single accuracy number would hide entirely.
- **A full 3×3 confusion matrix** — directional confusion (is `substantive` being called `dismissive`, or vice versa?) is the actionable signal the project asks for, and only the matrix shows direction.

## Definition of Success

A "good enough for a real community tool" classifier here would need: **all three per-class F1 scores ≥ 0.65**, and the fine-tuned model beating the Groq zero-shot baseline by **at least 10 percentage points of accuracy** on the same test set. The 0.65 F1 threshold is below the spec's "well-learned" bar of 0.70 deliberately — this is a 3-way subjective judgment call on short, informal text with only ~200 examples, and I'd rather state an honest, slightly lower bar I can actually evaluate against than an aspirational one. If any class's F1 lands near 0, that's an explicit failure for that class regardless of overall accuracy, and I will say so rather than average over it. These are the numbers I will check the final results against in the evaluation report — not "it should work well."

## AI Tool Plan

- **Label stress-testing**: Before annotating the real dataset, I (Claude, acting as the student's assistant for this project) generated several boundary-case HN-style comments to test the `substantive`/`hype` and `substantive`/`dismissive` lines — this is what produced the "specificity over tone" decision rule above. If the generated cases hadn't resolved cleanly under the existing definitions, the definitions would have needed tightening before real annotation began.
- **Annotation assistance**: Because I am the one collecting *and* labeling the dataset (there is no separate human annotator in this workflow), every label in `takemeter_dataset.csv` is first-pass AI annotation against the definitions above, not human-reviewed-after-AI-pre-labeled. This is disclosed explicitly in the README's AI Usage section. I flag this as a real limitation: the dataset would be stronger if the student spot-checked a sample before submission, and I recommend doing so even though it isn't required for the pipeline to run.
- **Failure analysis**: Once the fine-tuned model's wrong predictions come back from Colab, I will paste the list into this same context and ask myself (as the analysis step, not a separate tool) to identify a systematic pattern — e.g. a specific label pair, a comment length effect, or a tone/specificity confusion — then verify the pattern by re-reading the actual flagged comments before writing it into the evaluation report, rather than accepting the first pattern that looks plausible.

## Hard Edge Cases Encountered During Annotation

Collected 740 raw candidate comments from a mix of front-page, Show HN, and Ask HN threads via the HN Firebase API, then hand-labeled down to a final 255-example dataset (substantive 175/68.6%, hype 42/16.5%, dismissive 38/14.9% — no label over 70%). Five cases that genuinely required applying the specificity-over-tone decision rule, or that didn't fit any label and were excluded rather than forced:

1. *"Can't run this myself. But I do like Unsloth Studio, quite a lot. It's nicely designed."* — Positive in tone but contains no checkable claim or reasoning beyond "nicely designed." **Decided: `hype`** — enthusiasm without substance, even though mild.
2. *"Is it just me or is it weird seeing these clickbaity AI-generated taglines in an otherwise scientific work?"* — Reads as a snarky aside at first glance, but it quotes a specific piece of text from the article and makes a real, checkable observation about it. **Decided: `substantive`** — specificity wins over the mildly dismissive tone, per the decision rule in the Labels section.
3. *"No mention of a built in camera makes this a total non starter for me... so my next of kin can get a payout from whatever pavement princess flattened me."* — Sarcastic and harsh, but states a specific, checkable requirement (no camera = dealbreaker) and a specific reason. **Decided: `substantive`**, not `dismissive` — the snark is decoration on a real argument, not the argument itself.
4. *"Original source (please submit) (42 points, 2 days ago, 4 comments) [link]"* — A meta-moderation comment pointing to a duplicate submission. It isn't an opinion about the topic at all, so it doesn't fit any of the three labels. **Decided: excluded from the dataset** rather than forced into a bucket — this is the kind of case the spec's "exhaustive enough" requirement anticipates, and forcing it in would have introduced noise.
5. *"So glad we got them kicked out of Mountain View."* — Positive and brief, but it isn't `hype` (not boosting a product/company) and isn't `dismissive` (no negativity). **Decided: excluded** — a real, if rare, case of a comment that's simply too short and contextless to support any of the three labels confidently.
