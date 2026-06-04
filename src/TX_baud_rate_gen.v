module baud_rate_gen #(
    parameter BAUD_DIV = 868
)(
    input clk,
    input rst,
    output reg tick
);

localparam COUNT_WIDTH = $clog2(BAUD_DIV + 1);
reg [COUNT_WIDTH-1:0] count = 0;

always @(posedge clk) begin
    tick <= 0; // initialise default value
    if (rst) begin
        count <= 0;
    end else begin
        if (count == BAUD_DIV - 1) begin
            tick <= 1;
            count <= 0;
        end                                
        else begin
            count <= count + 1'b1;
        end
    end
end

endmodule
