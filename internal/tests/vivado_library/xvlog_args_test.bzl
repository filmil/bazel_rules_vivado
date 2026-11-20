"""Analysis tests: vivado_library puts xvlog_args on the xvlog command line."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")

def _xvlog_command(env):
    actions = [
        a
        for a in analysistest.target_actions(env)
        if a.mnemonic == "VivadoVerilog"
    ]
    asserts.equals(env, 1, len(actions), "expected one VivadoVerilog action")
    if not actions:
        return ""

    # A run_shell action: the command is the last argument.
    return actions[0].argv[-1]

def _with_args_test_impl(ctx):
    env = analysistest.begin(ctx)
    command = _xvlog_command(env)
    xvlog = command.find(" xvlog ")
    relax = command.find(" --relax ")
    source = command.find("lib.v")
    asserts.true(env, xvlog >= 0, "no xvlog in: " + command)
    asserts.true(env, relax > xvlog, "no --relax after xvlog in: " + command)
    asserts.true(env, source > relax, "--relax does not precede the sources in: " + command)
    return analysistest.end(env)

with_args_test = analysistest.make(_with_args_test_impl)

def _without_args_test_impl(ctx):
    env = analysistest.begin(ctx)
    command = _xvlog_command(env)
    asserts.true(env, " xvlog " in command, "no xvlog in: " + command)
    asserts.false(env, "--relax" in command, "unexpected --relax in: " + command)
    return analysistest.end(env)

without_args_test = analysistest.make(_without_args_test_impl)

def _vhdl_test_impl(ctx):
    env = analysistest.begin(ctx)
    asserts.expect_failure(env, "xvlog_args applies to Verilog")
    return analysistest.end(env)

vhdl_test = analysistest.make(_vhdl_test_impl, expect_failure = True)
