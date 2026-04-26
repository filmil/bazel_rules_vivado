# General change rules

* Do not change files in `//third_party` without user's explicit permission.
* Ensure that tests pass after every change.


## General git commit rules

Any git commit created by Gemini must contain this note as the last line in the
commit message in addition to any commit summaries added:

```
This commit has been created by an automated coding assistant,
with human supervision.
```

Also append the prompt used to generate the commit in full.

## Prefer rebase over merge

Instead of creating merges into a branch try to rebase the current branch on
top of another.

For example, to get content from branch `main` from the `origin` repo use `git
rebase --pull origin main`.


## Create pull request

Use the `gh` utility to create the pull request.

Use the remote `origin/main` as a baseline for the pull request.

Any pull request you create must contain this note as the last line in the
commit message in addition to any commit summaries added:

```
This pull request has been created by an automated coding assistant,
with human supervision.
```

Also append the prompt used to generate the pull request in full.

Rebase the branch `main` from remote `origin/main`.

Once the `gh` command to create the pull request completes, the task is done.


# `//third_party` maintenance

Every subdir under `//third_party` must have a LICENSE file with the appropriate
license copied from its source distribution.



# Public API documentation maintenance

Ensure that the repository is clean before starting this procedure.

For all source files, we want to maintain an up-to-date documentation of their
respective public API.


# Bazel Basics

This skill provides fundamental information on how to interact with a Bazel workspace.

## Core Concepts

*   **Workspace Root**: The root of a Bazel project is identified by a
    `MODULE.bazel`, `WORKSPACE`, or `WORKSPACE.bazel` file. The workspace root
    is referred to as `//`.
*   **BUILD Files**: Targets are defined in `BUILD.bazel` (or `BUILD`) files.
*   **Packages**: A `BUILD.bazel` file defines a "package" that extends from
    its directory into all subdirectories that do *not* have their own
    `BUILD.bazel` file.
*   **Labels**: Packages and targets are referenced using labels. A path
    relative to the workspace root forms the package name. For example,
    `//foo/bar` refers to the package defined by `foo/bar/BUILD.bazel`.

## Common Commands

*   **Build Everything**: `bazel build //...`
*   **Test Everything**: `bazel test //...`
*   **List Targets**: Use `bazel query` to list targets defined below a certain
    path.
    *   Example: `bazel query //foo/bar/...` lists all targets under
        `//foo/bar`.

