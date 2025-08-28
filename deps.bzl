load("@bazel_tools//tools/build_defs/repo:git.bzl", "git_repository")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")


def rules_vivado_dependencies():
    maybe(
        git_repository,
        name = "bazel_rules_bid",
        commit = "acac74fdccc8263117501e28fa6954bcc89f8f95",
        remote = "https://github.com/filmil/bazel-rules-bid.git",
        shallow_since = "1726367346 +0000",
    )

