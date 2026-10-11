"""Unit tests for resolve_source in //internal:vivado_installation.bzl."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//internal:vivado_installation.bzl", "resolve_source")

def _resolve_source_test_impl(ctx):
    env = unittest.begin(ctx)

    # Nothing in the environment: the module's own declaration is used.
    plain = resolve_source(
        urls = ["https://mirror/vivado.tar"],
        sha256 = "abc",
        env_url = "",
        env_sha256 = "",
    )
    asserts.equals(env, ["https://mirror/vivado.tar"], plain.urls)
    asserts.equals(env, "abc", plain.sha256)
    asserts.false(env, plain.overridden)

    # The override wins over the declared URLs, and the committed checksum
    # still applies: redirecting to a mirror is safe, a substitution is
    # caught.
    over = resolve_source(
        urls = ["https://mirror/vivado.tar", "file:///other/vivado.tar"],
        sha256 = "abc",
        env_url = "file:///home/me/vivado.tar",
        env_sha256 = "",
    )
    asserts.equals(env, ["file:///home/me/vivado.tar"], over.urls)
    asserts.equals(env, "abc", over.sha256)
    asserts.true(env, over.overridden)

    # A different archive needs its own checksum.
    other = resolve_source(
        urls = ["https://mirror/vivado.tar"],
        sha256 = "abc",
        env_url = "file:///home/me/other.tar",
        env_sha256 = "def",
    )
    asserts.equals(env, ["file:///home/me/other.tar"], other.urls)
    asserts.equals(env, "def", other.sha256)
    asserts.true(env, other.overridden)

    # A checksum override alone keeps the declared URLs, and is trimmed.
    sha_only = resolve_source(
        urls = ["https://mirror/vivado.tar"],
        sha256 = "abc",
        env_url = "",
        env_sha256 = " def\n",
    )
    asserts.equals(env, ["https://mirror/vivado.tar"], sha_only.urls)
    asserts.equals(env, "def", sha_only.sha256)
    asserts.false(env, sha_only.overridden)

    # The override works when the module declares no URL at all.
    bare = resolve_source(
        urls = [],
        sha256 = "",
        env_url = "  file:///home/me/vivado.tar\n",
        env_sha256 = "",
    )
    asserts.equals(env, ["file:///home/me/vivado.tar"], bare.urls)
    asserts.equals(env, "", bare.sha256)
    asserts.true(env, bare.overridden)

    # Nothing declared and nothing in the environment: no URLs, which the
    # repository rule turns into an error naming both ways to fix it.
    empty = resolve_source(urls = [], sha256 = "", env_url = "", env_sha256 = "")
    asserts.equals(env, [], empty.urls)
    asserts.false(env, empty.overridden)

    # Whitespace alone is no override.
    blank = resolve_source(
        urls = ["https://mirror/vivado.tar"],
        sha256 = "",
        env_url = "   ",
        env_sha256 = " ",
    )
    asserts.false(env, blank.overridden)
    asserts.equals(env, ["https://mirror/vivado.tar"], blank.urls)
    asserts.equals(env, "", blank.sha256)

    return unittest.end(env)

resolve_source_test = unittest.make(_resolve_source_test_impl)

def resolve_source_test_suite(name):
    unittest.suite(name, resolve_source_test)
