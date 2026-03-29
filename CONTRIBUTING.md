# Contributing Guide

Thank you for your interest in contributing to this project! This document describes a basic workflow to help you submit changes (pull requests) smoothly.

## 1. Before you begin

- Read the [README](/docs/README.md) and any relevant documentation to understand the project's goals.
- For large changes, open an issue to describe your plan and discuss it first.

## 2. Basic contribution workflow

### 2.1. Fork the repository

- Click "Fork" on GitHub to create your own copy.

### 2.2. Clone your fork locally

- HTTPS:
    ```bash
    git clone https://github.com/<your-username>/<repo>.git
    ```
- SSH:
    ```bash
    git clone git@github.com:<your-username>/<repo>.git
    ```

### 2.3. Set up the upstream remote (to sync changes from the original repo)

- 
    ```bash
    git remote add upstream https://github.com/<original-owner>/<repo>.git
    ```
-
    ```bash
    git fetch upstream
    ```

### 2.4. Create a new branch for your feature or fix

- Always work on a separate branch (do not work directly on `main`/`master`).
    ```bash
    git checkout -b feature/<short-description>
    ```
- Use clear branch names such as `feature/`, `fix/`, `chore/`, `docs/`...

### 2.5. Make changes, run tests, and check formatting

- Run tests/linters as described in the README.
- Keep changes small and focused: one goal per PR.

### 2.6. Commit your changes

- Write clear, concise commit messages; you can follow a conventional format:
    ```text
    type(scope): short description

    More detailed description (if needed).
    ```
- Stage and commit:
    ```bash
    git add .
    ```
    ```bash
    git commit -m "feat: add X feature"
    ```

### 2.7. Sync your branch with upstream before pushing (to avoid conflicts)
- If `master` is the primary branch:
    ```bash
    git fetch upstream
    ```
    ```bash
    git checkout main
    ```
    ```bash
    git pull upstream main
    ```
    ```bash
    git checkout feature/...
    ```
    ```bash
    git rebase main
    ```
- If you're not comfortable with `rebase`, you can `merge` instead:
    ```bash
    git merge upstream/main
    ```

### 2.8. Push your branch to your fork

-
    ```bash
    git push origin feature/<short-description>
    ```

### 2.9. Create a Pull Request (PR)

   - Go to the original repository -> "Compare & pull request" or "New pull request".
   - Choose your fork branch as the source and the original repo's `master` (or appropriate branch) as the target.
   - Fill in a title and a detailed description:
     - What the change is, why it is needed, and what parts it affects.
     - Link to an issue if applicable (e.g., `Fixes #123`).
     - Describe how to test the change if needed.

### 2.10. Respond to review feedback

- Maintainers may request changes. Make new commits on the same branch and push — the PR will update automatically.
- Reply politely to comments and update the description when necessary.

### 2.11. After the PR is merged

- Optionally delete the branch from your fork.
- Update your local `main`:
    ```bash
    git checkout main
    ```
    ```bash
    git fetch upstream
    ```
    ```bash
    git merge upstream/main
    ```
    ```bash
    git push origin main
    ```

## 3. Additional tips
- For large or breaking changes: open an issue to discuss first.
- For small fixes (typos, docs): it’s usually fine to open a direct PR.

Thank you - contributions are welcome!