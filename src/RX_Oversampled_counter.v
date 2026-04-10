module Oversampled_counter(
    input clk,
    input rst_trigger,
    output reg [4:0] counter = 0
);

    wire tick;

    oversampled_clk clk_tick(
        .clk(clk),
        .rst_trigger(rst_trigger),
        .tick(tick)
    );
    
    always @(posedge clk) begin
    
    
        if (rst_trigger) begin  
            counter <= 0;           
        end
        else if (tick) begin
           if (counter == 5'd27) begin
                counter <= 0;
           end
           else begin
                counter <= counter + 1'b1;
           end
        end
    end    
endmodule
