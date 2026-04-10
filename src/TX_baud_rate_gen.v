module baud_rate_gen(
    input clk,
    output reg tick
);

reg [9:0] count = 0;

always @(posedge clk) begin
if (count == 10'd867) begin
    tick <= 1;
    count <= 0;
end                                
else begin
    count <= count + 1'b1;
    tick <= 0;
end
end

endmodule
