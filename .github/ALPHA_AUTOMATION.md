# Automatic Alpha instruction tasks

The `Work on Alpha instructions` workflow starts Codex when a push or merge to
`main` changes anything under `alphainstructions/`. It selects added or updated
Markdown files across the whole push, including numbered files such as
`instructions1.md` and files inside subfolders. Renamed Markdown files are treated
as new instructions. Deleting instructions alone does not start agent work.

Codex reads the selected files, performs the work it can, and runs relevant
checks. Repository changes become a pull request for review; nothing is merged
automatically. Every run retains its report in the Actions summary and artifact,
including runs blocked on tools or requiring no changes. Separate pushes start
separate runs without cancelling previous work. They may create overlapping PRs
if instructions overlap; review those together before merging.

## One-time activation

1. Merge the workflow and helper files into `main`.
2. In repository **Settings → Secrets and variables → Actions**, add an Actions
   secret named `OPENAI_API_KEY` with an OpenAI API key. Never commit it or paste
   it into an instruction file. The Action uses API billing, separately from a
   ChatGPT subscription.
3. In **Settings → Actions → General**, enable Actions and allow GitHub Actions
   to create pull requests. Organization policies may require an administrator.
4. Open **Actions → Work on Alpha instructions → Run workflow**, select `main`,
   and run it once to process the existing instruction files. Later pushes to
   `main` changing `alphainstructions/` start work automatically. A manual run
   always selects all current Markdown instructions, so it also retries blockers.

This automation runs a new Codex process on a disposable GitHub-hosted Linux
runner. It does not resume a chat, use the saved Codex cloud environment, or
connect to desktop Roblox Studio. The current modeling instructions require
Studio and Big Dink Studios asset ownership; those operations remain blocked
until a suitable Studio-connected automation is provided. The agent must report
that limitation rather than claim it completed models or uploads.

Only changes already pushed to `main` trigger automatic work. Pull requests from
other branches wait until merged. The workflow uses the triggering commit, not a
moving checkout of newer main commits. Keep instructions in GitHub; direct
Team Create edits do not trigger this workflow. GitHub may suppress push workflows
for skip-CI commit messages, and path filtering has GitHub's normal limits.
Use a manual run to recover a missed trigger.

## Checking runs

Each run's Actions page shows the final report, logs, and artifact. If repository
files changed successfully, the `open-pr` job creates a PR. If no PR appears,
check the report for already-completed tasks or unavailable capabilities. A
missing API key causes an explicit failure before invoking Codex. Failed agent
runs do not publish partial changes. No running chat watches events; GitHub
Actions is the persistent event handler.
