module oversampled_clk #(
    parameter CLK_FREQ = 100_000_000,
    parameter BAUD_RATE = 115200,
    parameter OVERSAMPLING_RATE = 28
)(
    input clk,
    input rst_trigger,
    output reg tick = 0
    );
    
    localparam DIVIDER = CLK_FREQ/(BAUD_RATE * OVERSAMPLING_RATE);
    localparam DIVIDER_WIDTH = $clog2(DIVIDER + 1);
    localparam [DIVIDER_WIDTH - 1:0] WIDTH_ADJUSTED_DIVIDER = DIVIDER - 1;
    
    reg [DIVIDER_WIDTH - 1:0] count = 0;
    
    
    always @(posedge clk) begin
        tick <= 0;
        if (rst_trigger) begin
            count <= 0;
            tick <= 0;
        end
        
        else if (count == WIDTH_ADJUSTED_DIVIDER) begin
            tick <= 1;
            count <= 0;
        end else begin
            count <= count + 1'b1;
        end    
    end
endmodule
