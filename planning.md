# TakeMeter Planning

## Project Overview

TakeMeter is a text classification project that evaluates the type and substance of online basketball discourse. The goal is not to determine whether a comment is factually correct. Instead, the model will classify how the comment functions as a take: whether it is analytical, unsupported, emotional, or low-effort.

This project focuses on the hardest part of classification: designing labels that are clear enough for humans to apply consistently and meaningful enough for a model to learn.

---

## Community Choice

The community I chose is NBA discussion, especially comments from r/nba-style game threads, post-game threads, trade discussion threads, player ranking debates, and award discussions.

This community is a strong fit for a classification task because NBA discourse is active, opinionated, and varied in quality. Some comments are detailed basketball analysis using tactics, statistics, roster construction, or historical comparison. Others are confident but unsupported claims, emotional reactions after games, or short meme replies. These differences matter to people in the community because fans often debate not only basketball opinions themselves, but also whether a take is actually thoughtful or just reactionary.

The discourse is varied enough to make classification interesting because the same topic can produce many different types of comments. For example, after one playoff game, users may post serious matchup analysis, unsupported claims about a player's legacy, emotional overreactions, and low-effort jokes all in the same thread.

---

## What the Classifier Measures

TakeMeter measures the **discourse type and substance** of a basketball take.

It does **not** measure:

* whether the take is objectively true
* whether I personally agree with the take
* whether the comment is positive or negative
* whether the comment is popular in the thread

A comment can be wrong but still analytical if it gives a clear argument. A comment can be correct but still be a hot take if it simply asserts a claim without support. This distinction is important because the model should learn how discourse is presented, not whether the basketball opinion is correct.

---

## Label Taxonomy

The classifier will use four labels:

1. `analysis`
2. `hot_take`
3. `reaction`
4. `low_effort`

These labels are intended to be mutually exclusive. Each comment should receive exactly one label.

---

## Label 1: `analysis`

**Definition:**
A comment is `analysis` if it makes a specific basketball claim and supports that claim with reasoning, evidence, tactical observation, statistics, matchup context, roster logic, or historical comparison.

**Example 1:**

> The Celtics offense looked worse late because they stopped using Porzingis as a release valve. Once the defense trapped Tatum, nobody punished the weak-side rotation.

**Example 2:**

> I do not think that trade fixes their problem. They already have enough shot creation, but they still need a rim protector and a point-of-attack defender.

**Notes:**
The comment does not have to be correct to count as `analysis`. The key requirement is that it gives a basketball reason for its claim.

---

## Label 2: `hot_take`

**Definition:**
A comment is a `hot_take` if it makes a bold or confident basketball claim with little or no supporting reasoning.

**Example 1:**

> Tatum is never winning a title as the best player on his team.

**Example 2:**

> The Suns should trade Booker before his value drops.

**Notes:**
A `hot_take` is still a real basketball opinion. It is different from `low_effort` because it makes an interpretable claim. However, it asserts rather than argues.

---

## Label 3: `reaction`

**Definition:**
A comment is `reaction` if it is mainly an immediate emotional response to a game, trade, injury, player performance, or NBA event, with little sustained reasoning.

**Example 1:**

> Blow this team up. I cannot watch this garbage anymore.

**Example 2:**

> That was the worst fourth quarter I have ever seen. This team is cooked.

**Notes:**
A reaction may contain a basketball opinion, but the main purpose of the comment is emotional expression. Common signals include frustration, celebration, disbelief, panic, exaggeration, or rage after a specific event.

---

## Label 4: `low_effort`

**Definition:**
A comment is `low_effort` if it does not meaningfully evaluate basketball and is mainly a meme, joke, emoji reaction, slogan, one-word reply, pure insult, or context-dependent phrase.

**Example 1:**

> LMAOOOOOO

**Example 2:**

> Bro is him.

**Notes:**
A `low_effort` comment may still be understandable to community members, but it does not contain enough standalone substance to classify as analysis, hot take, or reaction.

---

## Label Decision Rules

When a comment could fit multiple labels, I will use the following decision process:

1. **Does the comment contain a meaningful basketball claim?**
   If no, label it `low_effort`.

2. **Is the comment mainly emotional or exaggerated?**
   If yes, label it `reaction`.

3. **Does the comment support its claim with specific basketball reasoning or evidence?**
   If yes, label it `analysis`.

4. **Does the comment make a basketball claim but mostly assert it without support?**
   If yes, label it `hot_take`.

This decision order is meant to make annotation more consistent. It also prevents me from labeling comments based only on whether I personally agree with them.

---

## Hard Edge Cases

### Edge Case 1: Sarcastic analysis vs. reaction

Some comments use emotional or sarcastic language while still making a real basketball point.

**Example:**

> Great idea, keep switching a slow center onto guards and act shocked when he gets cooked.

This could be `reaction` because of the sarcastic tone, but it could also be `analysis` because it identifies a specific defensive issue.

**Decision rule:**
If the sarcasm contains a clear basketball mechanism or explanation, I will label it `analysis`. If the comment is mostly venting without a clear basketball reason, I will label it `reaction`.

---

### Edge Case 2: Short analysis vs. low effort

Some short comments are still meaningful if they contain basketball terminology.

**Example:**

> Drop coverage killed them.

This is short, but it identifies a specific tactical issue.

**Decision rule:**
If a short comment contains a clear basketball concept that explains a result, I will label it `analysis`. If it is only a slogan, meme, or vague phrase, I will label it `low_effort`.

---

### Edge Case 3: Hot take vs. analysis

Some comments give a small amount of evidence, but not enough to become real analysis.

**Example:**

> LeBron is overrated because his playoff record against top-seeded teams is worse than people think.

This could be `analysis` because it refers to a statistic, but it could also be `hot_take` because the evidence is vague and selected mainly to support a bold claim.

**Decision rule:**
If the evidence is specific and used as part of a developed argument, I will label the comment `analysis`. If the evidence is vague, cherry-picked, or decorative, I will label it `hot_take`.

---

### Edge Case 4: Reaction vs. hot take

Some comments make a bold claim in emotional language.

**Example:**

> This coach is a terrorist for keeping that lineup in during the fourth.

This could be `reaction` because of the exaggerated language, but it could also be `hot_take` because it criticizes a coaching decision.

**Decision rule:**
If the exaggeration or emotion dominates the comment, I will label it `reaction`. If the comment calmly states a bold basketball claim without support, I will label it `hot_take`. If it explains the lineup problem specifically, I will label it `analysis`.

---

## Data Collection Plan

I will collect at least 200 public NBA discussion comments. I will use a mix of thread types so that the dataset is not dominated by only one kind of discourse.

Potential sources include:

* post-game discussion threads
* game threads
* trade rumor threads
* player ranking debates
* MVP or award discussion threads
* playoff series discussion threads
* team performance discussion threads

I will avoid collecting all examples from one thread because that could bias the dataset toward one emotional moment or one topic.

---

## Target Dataset Size and Label Balance

The minimum dataset size is 200 labeled examples. My target distribution is:

| Label        | Target Count |
| ------------ | -----------: |
| `analysis`   |           50 |
| `hot_take`   |           50 |
| `reaction`   |           50 |
| `low_effort` |           50 |
| **Total**    |      **200** |

A perfectly balanced dataset may not happen naturally, but I will try to keep the labels close enough that the model does not learn only the majority class.

If one label is underrepresented after collecting 200 examples, I will collect additional examples from thread types where that label is more likely to appear. For example:

* If `analysis` is underrepresented, I will collect more from serious discussion, trade analysis, playoff adjustment, or ranking debate threads.
* If `reaction` is underrepresented, I will collect more from post-game or live game threads.
* If `low_effort` is underrepresented, I will collect more from high-traffic game threads.
* If `hot_take` is underrepresented, I will collect more from player comparison, trade rumor, award debate, or legacy discussion threads.

I will not solve imbalance by forcing unclear examples into an underrepresented label. If a label is underrepresented, I will collect more data rather than weaken the label definitions.

---

## Annotation Process

Before labeling the full dataset, I will read 30–40 comments and test whether the taxonomy works. If too many comments are difficult to classify, I will revise the label definitions and decision rules before continuing.

Each labeled example will include:

| Field           | Description                                              |
| --------------- | -------------------------------------------------------- |
| `text`          | The comment text                                         |
| `label`         | One of the four labels                                   |
| `source_thread` | The thread or type of thread where the comment came from |
| `notes`         | Optional notes for difficult examples                    |
| `split`         | Train, validation, or test                               |

For the first version of the dataset, I will use this split:

| Split      |   Count |
| ---------- | ------: |
| Train      |     140 |
| Validation |      30 |
| Test       |      30 |
| **Total**  | **200** |

The test set will be kept separate and will not be used for label revision, training, or hyperparameter decisions.

---

## Model Plan

I plan to fine-tune `distilbert-base-uncased` for a four-class text classification task.

The model will take a single NBA comment as input and output one of the four labels:

* `analysis`
* `hot_take`
* `reaction`
* `low_effort`

Planned starting hyperparameters:

| Hyperparameter      |            Starting Value |
| ------------------- | ------------------------: |
| Base model          | `distilbert-base-uncased` |
| Max sequence length |                       128 |
| Learning rate       |                    `2e-5` |
| Epochs              |                         3 |
| Batch size          |                   8 or 16 |
| Evaluation strategy |            once per epoch |

I expect to adjust the number of epochs if the model is clearly underfitting or overfitting. Since the dataset is small, I will be careful not to overstate the final model’s generality.

---

## Baseline Plan

I will compare the fine-tuned model against a zero-shot LLM baseline using Groq’s `llama-3.3-70b-versatile`.

The baseline will classify the same test examples as the fine-tuned model. The zero-shot prompt will include the label names and definitions, but no training examples.

The baseline matters because the fine-tuned model should be compared against a strong general-purpose model. If the fine-tuned model performs worse than the zero-shot baseline, that would suggest either the dataset is too small, the labels are unclear, or the task is better handled by a larger instruction-tuned model.

---

## Evaluation Metrics

Accuracy alone is not enough for this task because the dataset may not be perfectly balanced. A model could get a decent accuracy score while performing badly on one or two labels.

I will report:

1. **Overall accuracy**
   This shows the percentage of test examples classified correctly.

2. **Per-class precision**
   This shows how often the model is correct when it predicts a specific label. This matters because I want to know, for example, whether comments predicted as `analysis` are actually analytical.

3. **Per-class recall**
   This shows how many true examples of each label the model successfully finds. This matters because a model might avoid predicting a difficult label, such as `analysis`, and still get acceptable accuracy.

4. **Per-class F1 score**
   This combines precision and recall, making it useful for comparing performance across labels.

5. **Confusion matrix**
   This will show which labels the model confuses with each other. This is especially important for this project because the most interesting mistakes will likely happen between `analysis` and `hot_take`, or between `reaction` and `low_effort`.

I will report these metrics for both the fine-tuned model and the zero-shot baseline on the same test set.

---

## Definition of Success

For this classifier to be genuinely useful, it needs to do more than achieve decent overall accuracy. It needs to distinguish between the labels that matter most in real community use.

A successful model would meet these criteria on the test set:

* Overall accuracy of at least **75%**
* Per-class F1 of at least **0.70** for each label
* No single label with recall below **0.65**
* A confusion matrix that shows understandable errors rather than random guessing
* Better performance than the zero-shot baseline on at least overall accuracy or macro F1

For deployment in a real community tool, I would want stronger performance:

* Overall accuracy of at least **85%**
* Macro F1 of at least **0.80**
* Consistent performance across all four labels
* Clear confidence scores, where high-confidence predictions are usually correct
* Human review for borderline or low-confidence cases

For this class project, I would consider the model “good enough” if it reaches around **75% accuracy**, has a **macro F1 near or above 0.70**, and produces errors that are explainable based on the label boundaries. If the model performs well overall but fails badly on `analysis` vs. `hot_take`, I would not consider it fully successful because that distinction is central to the project.

---

## Expected Failure Modes

I expect the model to struggle with several patterns:

### Sarcasm

Sarcastic analytical comments may be mislabeled as `reaction` because the tone sounds emotional.

### Short but meaningful comments

Short comments like “Drop coverage killed them” may be mislabeled as `low_effort` because the model may associate short length with low substance.

### Long but vague comments

The model may label long comments as `analysis` even if they are mostly vague claims with basketball-sounding language.

### Community slang

Terms like “ethical hoops,” “generational whistle,” “bus rider,” or “legacy game” may confuse the model because they are community-specific and context-dependent.

### Profanity and exaggeration

The model may over-associate profanity, all caps, or insults with `reaction`, even when the comment also contains real analysis.

---

## AI Tool Plan

AI tools will be used carefully during the project, but they will not replace my own labeling judgment.

### 1. Label Stress-Testing

Before annotating the full dataset, I will give an AI tool my label definitions and edge case rules. I will ask it to generate 5–10 NBA-style comments that sit near the boundary between two labels.

The purpose is to test whether my definitions are actually usable. If the AI produces examples that I cannot classify cleanly, I will revise my definitions and decision rules before labeling 200 examples.

I will especially stress-test these boundaries:

* `analysis` vs. `hot_take`
* `reaction` vs. `hot_take`
* `reaction` vs. `low_effort`
* `analysis` vs. `reaction` in sarcastic comments

I will not include AI-generated examples in the final training dataset unless the project allows synthetic data. The main dataset should come from real community text.

---

### 2. Annotation Assistance

I may use an LLM to pre-label a batch of comments before reviewing them manually. If I do this, I will still make the final label decision myself.

If I use AI pre-labeling, I will track it in the dataset with an extra field:

| Field                | Meaning                                      |
| -------------------- | -------------------------------------------- |
| `ai_prelabeled`      | Whether an AI tool suggested the first label |
| `ai_suggested_label` | The label suggested by the AI                |
| `final_label`        | The label I chose after review               |

This will allow me to disclose AI usage honestly in the README. It will also let me check whether the AI’s pre-labels biased my own decisions.

If the AI pre-labels are often wrong or push examples toward one label too strongly, I will stop using AI for annotation assistance and label manually.

---

### 3. Failure Analysis

After evaluation, I will collect the model’s wrong predictions and give them to an AI tool to help identify possible error patterns.

I will ask the AI to look for patterns such as:

* sarcasm being confused with emotional reaction
* short analytical comments being labeled as low effort
* vague basketball language being mislabeled as analysis
* profanity causing overprediction of reaction
* community slang confusing the model

I will verify these patterns myself by reading the examples and checking the confusion matrix. I will not report an error pattern just because the AI suggests it. The pattern must be supported by actual wrong predictions from my test set.

---

## Stretch Feature Planning

I will update this planning document before starting any stretch feature.

Possible stretch features include:

1. **Inter-annotator reliability**
   I may ask another person to label at least 30 examples independently. If I do this, I will report agreement rate and analyze where we disagreed.

2. **Confidence calibration**
   I may compare the model’s confidence scores against actual correctness to see whether high-confidence predictions are more reliable than low-confidence predictions.

3. **Error pattern analysis**
   I plan to do this if time allows, because it would make the evaluation report stronger.

4. **Deployed interface**
   I may build a simple interface where a user enters an NBA comment and receives a predicted label with confidence.

If I add any stretch feature, I will update this section before implementing it.

---

## Final Check Before Data Collection

Before collecting labeled examples, I should be able to answer these questions clearly:

* Can every comment receive exactly one label most of the time?
* Are the labels grounded in real NBA community discourse?
* Do the labels measure discourse type instead of personal agreement?
* Do I have clear decision rules for ambiguous cases?
* Are my success criteria specific enough to evaluate objectively?

If the answer to any of these is no, I should revise the taxonomy before collecting the full dataset.
