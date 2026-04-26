module top(
    input logic clk_in,
    input logic rst,
    output logic clk_out,
    output logic locked
);

    // Instantiate the generated clock wizard IP
    clk_wiz_0 clk_wiz_inst (
        .clk_in1(clk_in),
        .reset(rst),
        .clk_out1(clk_out),
        .locked(locked)
    );

endmodule
