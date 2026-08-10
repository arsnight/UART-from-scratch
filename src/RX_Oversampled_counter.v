module Oversampled_counter #(
    parameter CLK_FREQ = 100_000_000,
    parameter BAUD_RATE = 115200,
    parameter OVERSAMPLING_RATE = 28
)(
    input clk,
    input rst_trigger,
    output reg [$clog2(OVERSAMPLING_RATE + 1) - 1:0] counter = 0
);

    wire tick;
    localparam width = $clog2(OVERSAMPLING_RATE + 1); // Obtained the width of the parameter
    localparam [width-1:0] Matched_rate = OVERSAMPLING_RATE - 1; //forced a 32 bit constant down to the required bit width
    
    oversampled_clk #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE),
        .OVERSAMPLING_RATE(OVERSAMPLING_RATE)
    )clk_tick(
        .clk(clk),
        .rst_trigger(rst_trigger),
        .tick(tick)
    );
    
    always @(posedge clk) begin
    
    
        if (rst_trigger) begin  
            counter <= 0;           
        end
        else if (tick) begin
           if (counter == Matched_rate) begin
                counter <= 0;
           end
           else begin
                counter <= counter + 1'b1;
           end
        end
    end    
endmodule
