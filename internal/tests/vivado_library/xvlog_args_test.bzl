"""Analysis tests: vivado_library puts xvlog_args on the xvlog command line."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")

def _command(env, mnemonic):
    actions = [
        a
        for a in analysistest.target_actions(env)
        if a.mnemonic == mnemonic
    ]
    asserts.equals(env, 1, len(actions), "expected one %s action" % mnemonic)
    if not actions:
        return ""

    # A run_shell action: bash -c <command>, the command is the last argument.
    return actions[0].argv[-1]

def _in_order(env, command, parts):
    """Asserts that each of parts appears in command, in this order."""
    at = -1
    for part in parts:
        found = command.find(part, at + 1)
        asserts.true(env, found > at, "%r missing or out of order in: %s" % (part, command))
        if found > at:
            at = found

def _with_args_test_impl(ctx):
    env = analysistest.begin(ctx)
    command = _command(env, "VivadoVerilog")

    # After the defines, in the order given, each quoted as one shell word,
    # and before the source.
    _in_order(env, command, [
        " xvlog ",
        "-d FOO=1",
        " '--relax' ",
        " '-d' ",
        " 'MSG=a b' ",
        "lib.v",
    ])
    return analysistest.end(env)

with_args_test = analysistest.make(_with_args_test_impl)

def _sv_test_impl(ctx):
    env = analysistest.begin(ctx)
    command = _command(env, "VivadoSystemVerilog")
    _in_order(env, command, [" xvlog ", "--sv", " '--relax' ", "lib.sv"])
    return analysistest.end(env)

sv_test = analysistest.make(_sv_test_impl)

def _without_args_test_impl(ctx):
    env = analysistest.begin(ctx)
    command = _command(env, "VivadoVerilog")

    # Without xvlog_args, the defines are followed directly by the source.
    _in_order(env, command, [" xvlog ", "-d FOO=1 "])
    asserts.true(
        env,
        "-d FOO=1 internal/tests/vivado_library/lib.v" in command,
        "something between the defines and the source in: " + command,
    )
    return analysistest.end(env)

without_args_test = analysistest.make(_without_args_test_impl)

def _vhdl_test_impl(ctx):
    env = analysistest.begin(ctx)
    command = _command(env, "VivadoVHDL")
    asserts.true(env, " xvhdl " in command, "no xvhdl in: " + command)
    return analysistest.end(env)

vhdl_test = analysistest.make(_vhdl_test_impl)

def _vhdl_with_args_test_impl(ctx):
    env = analysistest.begin(ctx)
    asserts.expect_failure(env, "xvlog_args applies to Verilog")
    return analysistest.end(env)

vhdl_with_args_test = analysistest.make(_vhdl_with_args_test_impl, expect_failure = True)
