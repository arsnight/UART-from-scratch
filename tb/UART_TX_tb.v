module UART_TX_tb;

    parameter CLK_FREQ  = 100_000_000;
    parameter BAUD_RATE = 115200;
    parameter BIT_COUNT = 8;

    reg clk;
    reg rst;
    reg [BIT_COUNT-1:0] parallel_in;
    reg start_tx;
    wire serial_out;

    UART_TX #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE),
        .BIT_COUNT(BIT_COUNT)
    ) dut (
        .clk(clk),
        .rst(rst),
        .parallel_in(parallel_in),
        .start_tx(start_tx),
        .serial_out(serial_out)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    initial begin

        rst = 1;
        start_tx = 0;
        parallel_in = 8'h00;

        // Hold reset
        #100;
        rst = 0;

        #100;

        // Send 0x73: 01110011
        parallel_in = 8'h73;

        // Pulse start_tx for one clock
        @(posedge clk);
        start_tx <= 1;

        @(posedge clk);
        start_tx <= 0;
        
        // Wait long enough for transmission
        #10000;

        $finish;
    end
    initial begin
        $display("Time(ns)\tSerial");
        $monitor("%0t\t%b", $time, serial_out);
    end

endmodule
