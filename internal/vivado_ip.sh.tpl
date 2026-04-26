{SCRIPT} \
LD_LIBRARY_PATH="{VIVADO_PATH}/lib/lnx64.o" \
{VIVADO_PATH}/bin/setEnvAndRunCmd.sh vivado \
    -notrace -mode batch -source {TCL_SCRIPT} 2>&1 > {LOG} || ( cat {LOG} && exit 1 )

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
SIM_DIR="{IP_OUTPUT_DIR}/sim"
if [ ! -d "$SIM_DIR" ]; then
    SIM_DIR="{IP_OUTPUT_DIR}"
fi

V_FILES=$(find "$SIM_DIR" -name "*.v")
SV_FILES=$(find "$SIM_DIR" -name "*.sv")
VHDL_FILES=$(find "$SIM_DIR" -name "*.vhd" -o -name "*.vhdl")

# Compile into library
if [ -n "$V_FILES" ] || [ -n "$SV_FILES" ] || [ -n "$VHDL_FILES" ]; then
    if [ -n "$V_FILES" ]; then
        {SCRIPT} \
        LD_LIBRARY_PATH="{VIVADO_PATH}/lib/lnx64.o" \
        {VIVADO_PATH}/bin/setEnvAndRunCmd.sh xvlog \
            --work {MODULE_NAME}={LIBRARY_OUTPUT_DIR} $V_FILES 2>&1 >> {LOG}
    fi
    if [ -n "$SV_FILES" ]; then
        {SCRIPT} \
        LD_LIBRARY_PATH="{VIVADO_PATH}/lib/lnx64.o" \
        {VIVADO_PATH}/bin/setEnvAndRunCmd.sh xvlog --sv \
            --work {MODULE_NAME}={LIBRARY_OUTPUT_DIR} $SV_FILES 2>&1 >> {LOG}
    fi
    if [ -n "$VHDL_FILES" ]; then
        {SCRIPT} \
        LD_LIBRARY_PATH="{VIVADO_PATH}/lib/lnx64.o" \
        {VIVADO_PATH}/bin/setEnvAndRunCmd.sh xvhdl --2008 \
            --work {MODULE_NAME}={LIBRARY_OUTPUT_DIR} $VHDL_FILES 2>&1 >> {LOG}
    fi
else
    echo "No HDL files found to compile for IP {MODULE_NAME} in $SIM_DIR" >> {LOG}
    mkdir -p {LIBRARY_OUTPUT_DIR}
fi
