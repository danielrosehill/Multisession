---
name: breakout-model
description: Offload a new AI model project as a side job: create a GitHub repo and a Hugging Face dataset together, link them, open a new Claude in a split or tab, and hand it the starting plan. Use on "new repo and a Hugging Face dataset for this", "bootstrap a model project", "spin up a model development project", "new fine-tune project", "repo plus HF dataset and hand it over". For a repo with no dataset, use breakout.
---

# breakout-model

`multisession:breakout` plus a Hugging Face dataset, for starting an AI model development project.
Follow that skill throughout. This one adds the dataset, and changes only what is listed here.

## Parameters

Everything `breakout` takes, plus:

| Parameter | Values | Default |
|---|---|---|
| `dataset_visibility` | `private` or `public` | `private`, whatever the repo is |
| `dataset_owner` | Hugging Face user or organisation | as `hf-ops:create-dataset` decides |
| `dataset_name` | Title-Case-With-Hyphens | the repo name |
| `model_repo` | `yes` or `no`: also reserve a model repo | `no` |

The two visibilities are separate decisions: a public repo with a private dataset is normal, so
"public" for one is not "public" for the other. If the user said only "public" and it is unclear
which they meant, ask.

## Steps

1. **Check both names before creating anything.** Search for an existing repo and dataset on the
   subject (`repo-mgmt:create-repo`, `hf-ops:create-dataset`), so that a clash stops the run with
   nothing half made.
2. **Write the founding brief,** as in `breakout` section 2, and add:
   - the dataset id and URL, and its visibility
   - **Data:** what the data is, where it comes from, and its licence, or an open question for each
   - **First step:** usually finding what exists (`hf-ops:candidate-dataset-research`) before
     building anything, unless the user already has the data
3. **Create the GitHub repo,** as in `breakout` section 3.
4. **Create the dataset** with `hf-ops:create-dataset`, including its collection step. Confirm with
   `exists`. If `model_repo: yes`, also follow `hf-ops:create-model`. Leave uploading data to the new
   session.
5. **Link them.** Add the dataset's URL to the repo's README, commit and push. If the dataset is
   public and the repo is private, don't put the repo's URL on the dataset. Otherwise give the dataset
   a minimal card linking to the repo. Never put a private dataset's id in a public README.
6. **Spawn and hand off,** as in `breakout` section 4.

If the dataset step fails, keep going: the repo stands. Record the failure in the brief as the first
thing to fix, and tell the user.

## Report

> Broken out to `<owner/repo>` (<visibility>) with dataset `<owner/name>` (<visibility>): `<agent-name>` has the brief. Back to `<what you were doing>`.

## Hard limits

`breakout`'s limits apply. No secret values in the brief, the README or the card, and no data uploads
here.
