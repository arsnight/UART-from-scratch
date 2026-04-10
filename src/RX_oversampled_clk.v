module oversampled_clk(
    input clk,
    input rst_trigger,
    output reg tick
    );
    
    reg [5:0] count = 0;
    
    
    always @(posedge clk) begin
        tick <= 0;
        if (rst_trigger) begin
            count <= 0;
            tick <= 0;
        end
        
        else if (count == 5'd30) begin
            tick <= 1;
            count <= 0;
        end else begin
            count <= count + 1'b1;
        end    
    end
endmodule
