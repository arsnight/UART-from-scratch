`timescale 1ns / 1ps

module UART_RX #(
    parameter CLK_FREQ = 100_000_000,
    parameter BAUD_RATE = 115200,
    parameter BIT_COUNT = 8,
    parameter NUM_STATES = 4,
    parameter OVERSAMPLING_RATE = 28,
    parameter MID_BIT_POSITION = (OVERSAMPLING_RATE/2)
)(
    input clk,
    input rst, //Added a reset port same as tx
    input serial_out,
    output reg [BIT_COUNT-1:0] parallel_out = 0
); 
    localparam STATE_WIDTH = $clog2(NUM_STATES + 1);
    localparam DATA_WIDTH = $clog2(BIT_COUNT + 1);
    localparam [DATA_WIDTH - 1:0] LAST_BIT = BIT_COUNT - 1;
    localparam COUNTER_WIDTH = $clog2(OVERSAMPLING_RATE + 1);
    localparam [COUNTER_WIDTH - 1:0] MID_BIT = MID_BIT_POSITION;
    
    reg [STATE_WIDTH - 1:0] state = 0;
    reg prev_serial_out = 1;
    reg [DATA_WIDTH - 1:0] count = 0;
    reg rst_trigger = 0;
    reg [COUNTER_WIDTH - 1:0] prev_counter = 0;
    wire [COUNTER_WIDTH - 1:0] counter; //wire shouldn't be initialized, Module output already drives it
    
    localparam IDLE = 0;
    localparam START_RX = 1;
    localparam DATA_RX = 2;
    localparam STOP_RX = 3;
    
    Oversampled_counter #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE),
        .OVERSAMPLING_RATE(OVERSAMPLING_RATE)
    )clk_counter(
        .clk(clk),
        .rst_trigger(rst_trigger),
        .counter(counter)
    );
    
    always @(posedge clk) begin
       if (rst) begin
          rst_trigger <= 1;
          state <= IDLE;
          count <= 0;
       end else begin 
            rst_trigger <= 0;
            case(state)
                IDLE: begin
                    if (prev_serial_out == 1 && serial_out == 0) begin
                        rst_trigger <= 1;
                        state <= START_RX;
                    end
                end
                START_RX: begin
                    if (counter == MID_BIT && prev_counter != counter) begin
                        if(serial_out == 0) begin
                            state <= DATA_RX;
                        end else begin
                            state <= IDLE;
                        end
                    end
                end
                DATA_RX: begin
                    if (counter == MID_BIT && prev_counter != counter) begin
                        parallel_out[count] <= serial_out;
        
                        if (count == LAST_BIT) begin
                            state <= STOP_RX;
                        end else begin
                            count <= count + 1'b1;
                        end
                    end
                end   
                STOP_RX: begin
                    if (counter == MID_BIT && prev_counter != counter) begin
                        state <= IDLE;
                        count <= 0;
                        rst_trigger <= 1;
                    end               
                end
                default: state <= IDLE;
            endcase
            prev_counter <= counter;
            prev_serial_out <= serial_out;
        end
   end
   
endmodule
