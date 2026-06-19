module ila_top(
    input logic clk,
    input logic rst,
    input logic [7:0] data_bus
);

    logic [7:0] data_reg;
    logic active;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            data_reg <= 8'h00;
            active <= 1'b0;
        end else begin
            data_reg <= data_bus;
            active <= (data_bus != 8'h00);
        end
    end

    // Instantiate our custom ILA core
    my_ila_core ila_inst (
        .clk(clk),
        .probe0(active),
        .probe1(data_reg)
    );

endmodule
