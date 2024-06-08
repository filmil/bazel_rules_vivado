load("@bazel_tools//tools/build_defs/repo:git.bzl", "git_repository")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")


def rules_vivado_dependencies():
    maybe( 
        git_repository,
        name = "bazel_rules_bid",
        commit = "edad8e05fedb707792ac7e04f142c9adfe3baf52",
        remote = "https://github.com/filmil/bazel-rules-bid.git",
        shallow_since = "1706736734 -0800",
    )

