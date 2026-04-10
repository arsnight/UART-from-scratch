module UART_TX_tb();

reg clk = 0;
reg [7:0] parallel_in = 0;
reg start_tx = 0;
wire serial_out; 

always #5 clk = ~clk;

UART_TX dut(
    .clk(clk),
    .parallel_in(parallel_in),
    .start_tx(start_tx),
    .serial_out(serial_out)
);

initial begin
    parallel_in = 8'h43; //Test for alphabet C
    #100
    start_tx = 1; 
    #100
    start_tx = 0;
    #200
    #1000000000
    #1000000000
    $finish;
end

endmodule
