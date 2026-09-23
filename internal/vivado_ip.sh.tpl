{SCRIPT} \
LD_LIBRARY_PATH="{VIVADO_PATH}/lib/lnx64.o" \
{VIVADO_PATH}/bin/setEnvAndRunCmd.sh vivado \
    -notrace -mode batch -source {TCL_SCRIPT} > {LOG} 2>&1 || ( cat {LOG} && exit 1 )

# Vivado has been seen to leave with a clean status after an error, so
# the log is read as well. Only the part of it before the generation
# finished is read: the out-of-context synthesis the script attempts
# after that is best effort, and an IP that will not synthesize on its
# own still delivers its sources.
if sed -n '1,/^RULES_VIVADO: .* generated$/p' {LOG} | grep -q '^ERROR:'; then
    cat {LOG}
    echo "vivado reported an error while generating {MODULE_NAME}" >&2
    exit 1
fi

# Copy the generated IP files to the output directory.
# When create_project {MODULE_NAME} is used, Vivado creates a directory {MODULE_NAME}
# The generated files are in {MODULE_NAME}.gen/sources_1/ip/{MODULE_NAME}/
# The source files are in {MODULE_NAME}.srcs/sources_1/ip/{MODULE_NAME}/

GEN_DIR="{MODULE_NAME}.gen/sources_1/ip/{MODULE_NAME}"
SRC_DIR="{MODULE_NAME}.srcs/sources_1/ip/{MODULE_NAME}"

if [ -d "$GEN_DIR" ]; then
    cp -R "$GEN_DIR"/* {IP_OUTPUT_DIR}/
fi

if [ -d "$SRC_DIR" ]; then
    cp -R "$SRC_DIR"/* {IP_OUTPUT_DIR}/
fi

# Find files for compilation in the generated IP directory.
# We prioritize simulation files if available.
# Some IPs have a 'sim' subdirectory, others have files at the root.
# The example design's imported sources, when the rule opened one: the
# testbench and the models Vivado ships for the IP, kept where a
# library rule can be pointed at them.
EXAMPLE_IMPORTS=$(ls -d {MODULE_NAME}.example/*/imports 2>/dev/null | head -1)
if [ -n "$EXAMPLE_IMPORTS" ]; then
    mkdir -p "{IP_OUTPUT_DIR}/example"
    cp -R "$EXAMPLE_IMPORTS" "{IP_OUTPUT_DIR}/example/"
fi
# The exported simulation: Vivado's own compile order for the IP, its
# includes, its compiler options and the precompiled libraries it
# elaborates against. When it is there, the library is compiled from
# it; the walk over `sim` below is the fallback for an IP that exports
# nothing.
EXPORT="{MODULE_NAME}.export/{MODULE_NAME}/xsim"
if [ -f "$EXPORT/vlog.prj" ] || [ -f "$EXPORT/vhdl.prj" ]; then
    mkdir -p "{IP_OUTPUT_DIR}/export"
    cp -R "$EXPORT" "{IP_OUTPUT_DIR}/export/"
    # The options the export gives its compilers, less the incremental
    # flag, which has nothing to be incremental against here.
    XVLOG_OPTS=$(sed -n 's/^xvlog_opts="\(.*\)"/\1/p' "$EXPORT/{MODULE_NAME}.sh" | sed 's/--incr//')
    XVHDL_OPTS=$(sed -n 's/^xvhdl_opts="\(.*\)"/\1/p' "$EXPORT/{MODULE_NAME}.sh" | sed 's/--incr//')
    # Every source into the one library named for the IP, wherever the
    # export put it, so that a user names one library and the sources
    # find each other.
    sed -i 's/^\(verilog\|sv\|vhdl\|vhdl2008\) [A-Za-z0-9_]* /\1 {MODULE_NAME} /' \
        "$EXPORT/vlog.prj" "$EXPORT/vhdl.prj" 2>/dev/null || true
    mkdir -p {LIBRARY_OUTPUT_DIR}
    if grep -q '^\(verilog\|sv\) ' "$EXPORT/vlog.prj" 2>/dev/null; then
        {SCRIPT} \
        LD_LIBRARY_PATH="{VIVADO_PATH}/lib/lnx64.o" \
        {VIVADO_PATH}/bin/setEnvAndRunCmd.sh xvlog $XVLOG_OPTS \
            --work {MODULE_NAME}={LIBRARY_OUTPUT_DIR} -prj "$EXPORT/vlog.prj" 2>&1 >> {LOG} \
            || ( cat {LOG} && exit 1 )
    fi
    if grep -q '^vhdl' "$EXPORT/vhdl.prj" 2>/dev/null; then
        {SCRIPT} \
        LD_LIBRARY_PATH="{VIVADO_PATH}/lib/lnx64.o" \
        {VIVADO_PATH}/bin/setEnvAndRunCmd.sh xvhdl $XVHDL_OPTS \
            --work {MODULE_NAME}={LIBRARY_OUTPUT_DIR} -prj "$EXPORT/vhdl.prj" 2>&1 >> {LOG} \
            || ( cat {LOG} && exit 1 )
    fi
    exit 0
fi
SIM_DIR="{IP_OUTPUT_DIR}/sim"
if [ ! -d "$SIM_DIR" ]; then
    SIM_DIR="{IP_OUTPUT_DIR}"
fi

V_FILES=$(find "$SIM_DIR" -name "*.v")
SV_FILES=$(find "$SIM_DIR" -name "*.sv")
VHDL_FILES=$(find "$SIM_DIR" -name "*.vhd" -o -name "*.vhdl")

# Compile into library. Each compiler's status is checked too: an IP
# whose sources do not analyse is not a library anyone can use.
if [ -n "$V_FILES" ] || [ -n "$SV_FILES" ] || [ -n "$VHDL_FILES" ]; then
    if [ -n "$V_FILES" ]; then
        {SCRIPT} \
        LD_LIBRARY_PATH="{VIVADO_PATH}/lib/lnx64.o" \
        {VIVADO_PATH}/bin/setEnvAndRunCmd.sh xvlog \
            --work {MODULE_NAME}={LIBRARY_OUTPUT_DIR} $V_FILES >> {LOG} 2>&1 \
            || ( cat {LOG} && exit 1 )
    fi
    if [ -n "$SV_FILES" ]; then
        {SCRIPT} \
        LD_LIBRARY_PATH="{VIVADO_PATH}/lib/lnx64.o" \
        {VIVADO_PATH}/bin/setEnvAndRunCmd.sh xvlog --sv \
            --work {MODULE_NAME}={LIBRARY_OUTPUT_DIR} $SV_FILES >> {LOG} 2>&1 \
            || ( cat {LOG} && exit 1 )
    fi
    if [ -n "$VHDL_FILES" ]; then
        {SCRIPT} \
        LD_LIBRARY_PATH="{VIVADO_PATH}/lib/lnx64.o" \
        {VIVADO_PATH}/bin/setEnvAndRunCmd.sh xvhdl -2008 \
            --work {MODULE_NAME}={LIBRARY_OUTPUT_DIR} $VHDL_FILES >> {LOG} 2>&1 \
            || ( cat {LOG} && exit 1 )
    fi
else
    echo "No HDL files found to compile for IP {MODULE_NAME} in $SIM_DIR" >> {LOG}
    mkdir -p {LIBRARY_OUTPUT_DIR}
fi
