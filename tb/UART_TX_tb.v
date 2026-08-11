`timescale 1ns / 1ps

module UART_TX_tb();

reg clk = 0;
reg rst = 0;

reg [7:0] parallel_in = 0;
reg start_tx = 0;

wire serial_out;

// Same parameters as DUT
localparam CLK_FREQ = 100_000_000;
localparam BAUD_RATE = 115200;
localparam BIT_COUNT = 8;

localparam BAUD_DIV = CLK_FREQ / BAUD_RATE;

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

// 100 MHz clock
always #5 clk = ~clk;


// ============================================================
// Send a byte request to the TX
// ============================================================

task send_byte;
    input [7:0] data;

    begin
        $display("==========================================");
        $display("Requesting Byte: %h at time %t", data, $time);

        parallel_in = data;

        // Generate rising edge on start_tx
        @(negedge clk);
        start_tx = 1;

        @(negedge clk);
        start_tx = 0;

        // Wait until TX actually becomes busy
        wait(dut.TX_busy == 1);

        $display("TX started at time %t", $time);

        // Wait until entire frame is finished
        wait(dut.TX_busy == 0);

        $display("TX finished at time %t", $time);
        $display("==========================================");
    end
endtask

task send_byte_while_busy;
    input [7:0] first_data;
    input [7:0] busy_data;

    begin
        $display("==========================================");
        $display("Starting Byte: %h", first_data);
        $display("Will request %h while TX is busy", busy_data);
        $display("==========================================");

        // Put first byte on input
        parallel_in = first_data;

        // Generate start_tx rising edge
        @(negedge clk);
        start_tx = 1;

        @(negedge clk);
        start_tx = 0;

        // IMPORTANT:
        // Wait until the first transmission is actually underway.
        wait(dut.TX_busy == 1);

        $display("First TX started at time %t", $time);

        // Let the first byte transmit for a few bits.
        repeat(3 * BAUD_DIV) @(posedge clk);

        // --------------------------------------------------
        // request another byte while TX_busy == 1
        // --------------------------------------------------

        parallel_in = busy_data;

        $display("Requesting %h WHILE TX_busy = %b at time %t",
                 busy_data, dut.TX_busy, $time);

        // Generate a fresh rising edge on start_tx
        @(negedge clk);
        start_tx = 1;

        @(negedge clk);
        start_tx = 0;

        $display("Busy request issued. TX_busy = %b at time %t",
                 dut.TX_busy, $time);

        // Wait for the ORIGINAL transmission to finish
        wait(dut.TX_busy == 0);

        $display("First TX finished at time %t", $time);
        $display("==========================================");
        repeat(2*BAUD_DIV) @(posedge clk);
        
        if (serial_out !== 1 || dut.TX_busy !== 0) $display(">>> FAIL: spurious activity after busy-drop <<<"); 
        else $display(">>> PASS: line stayed idle <<<");

    end
endtask

// ============================================================
// Monitor one UART frame
//
// Waits for falling edge = start bit
// Then samples at middle of every bit
//
// Frame:
// START | D0 | D1 | D2 | D3 | D4 | D5 | D6 | D7 | STOP
//   0     ...                         ...              1
// ============================================================

task check_byte;
    input [7:0] expected;

    reg [7:0] received;
    reg start_bit;
    reg stop_bit;
    integer i;

    begin

        // Wait for start bit
        @(negedge serial_out);

        // Move to middle of start bit
        repeat(BAUD_DIV/2) @(posedge clk);

        start_bit = serial_out;

        // Sample data bits
        for(i = 0; i < 8; i = i + 1) begin

            repeat(BAUD_DIV) @(posedge clk);

            received[i] = serial_out;

        end

        // Move to middle of stop bit
        repeat(BAUD_DIV) @(posedge clk);

        stop_bit = serial_out;

        $display("RX Monitor:");
        $display("  Expected = %h", expected);
        $display("  Received = %h", received);
        $display("  Start bit = %b", start_bit);
        $display("  Stop bit  = %b", stop_bit);

        if(received == expected &&
           start_bit == 0 &&
           stop_bit == 1) begin

            $display(">>> PASS <<<");

        end
        else begin

            $display(">>> FAIL <<<");

        end

    end
endtask


// ============================================================
// Send byte but reset TX in the middle of a data bit
// ============================================================

task send_byte_with_reset;

    input [7:0] data;
    input integer reset_after_bit;

    integer i;

    begin

        $display("");
        $display("##########################################");
        $display("Starting interrupted byte: %h", data);
        $display("Reset during data bit: %0d", reset_after_bit);
        $display("##########################################");

        parallel_in = data;

        // Start TX
        @(negedge clk);
        start_tx = 1;

        @(negedge clk);
        start_tx = 0;

        // Wait until transmission actually begins
        wait(dut.TX_busy == 1);

        $display("TX started at %t", $time);

        // ----------------------------------------------------
        // Wait until the selected data bit is being transmitted
        //
        // +1 = skip START bit
        // +reset_after_bit = reach selected DATA bit
        //
        // Then wait half a bit so reset occurs MID-BIT.
        // ----------------------------------------------------

        repeat((reset_after_bit + 1) * BAUD_DIV +
               BAUD_DIV/2) @(posedge clk);

        // Assert reset away from clock edge to avoid TB race
        @(negedge clk);

        $display(">>> ASSERTING RESET at time %t <<<", $time);

        rst = 1;

        // Synchronous reset: keep it active across 2 clocks
        repeat(2) @(posedge clk);

        rst = 0;

        $display(">>> RESET RELEASED at time %t <<<", $time);

        // TX should now be idle
        @(negedge clk);

        $display("TX_busy after reset = %b", dut.TX_busy);
        $display("serial_out after reset = %b", serial_out);

        // Let UART line remain idle
        repeat(BAUD_DIV) @(posedge clk);

        $display("Interrupted frame successfully aborted.");

    end
endtask


// ============================================================
// VCD
// ============================================================

initial begin

    $dumpfile("uart_tx.vcd");
    $dumpvars(0, UART_TX_tb);

end


// ============================================================
// Main test
// ============================================================

initial begin

    parallel_in = 0;
    start_tx = 0;
    rst = 0;

    // UART idle
    repeat(2000) @(posedge clk);


    // ========================================================
    // TEST 1: Normal byte
    // ========================================================

    fork
        send_byte(8'h77);
        check_byte(8'h77);
    join


    // ========================================================
    // TEST 2: Back-to-back byte
    // ========================================================

    fork
        send_byte(8'hA5);
        check_byte(8'hA5);
    join


    // ========================================================
    // TEST 3: Reset in middle of transmission
    // ========================================================

    send_byte_with_reset(8'h3C, 3);


    // ========================================================
    // TEST 4: Verify TX recovers after reset
    // ========================================================

    fork
        send_byte(8'hA5);
        check_byte(8'hA5);
    join
    
    // ========================================================
    // TEST 5: Request another byte while TX is busy
    // ========================================================

    fork
        send_byte_while_busy(8'hA5, 8'h77);
        check_byte(8'hA5);
    join


    // Let waveform settle
    repeat(2000) @(posedge clk);

    $display("");
    $display("==========================================");
    $display("ALL TESTS COMPLETE");
    $display("==========================================");

    $finish;

end

endmodule
