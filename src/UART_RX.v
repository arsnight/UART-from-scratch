`timescale 1ns / 1ps

module UART_RX(
    input clk,
    input serial_out,
    output reg [7:0] parallel_out = 0
); 
    
    reg [2:0] state = 0;
    reg prev_serial_out = 0;
    reg [2:0] count = 0;
    reg rst_trigger = 0;
    reg [4:0] prev_counter = 0;
    wire [4:0] counter; //wire shouldn't be initialized, Module output already drives it
    wire falling_edge;
    
    assign falling_edge = (prev_serial_out == 1 && serial_out == 0); //falling_edge is always recomputed whenever prev_serial_out OR serial_out changes
    
    
    localparam IDLE = 0;
    localparam START_RX = 1;
    localparam DATA_RX = 2;
    localparam STOP_RX = 3;
    
    Oversampled_counter clk_counter(
        .clk(clk),
        .rst_trigger(rst_trigger),
        .counter(counter)
    );
    
    always @(posedge clk) begin
       rst_trigger <= 0;
       case(state)
            IDLE: begin
                if (prev_serial_out == 1 && serial_out == 0) begin
                    rst_trigger <= 1;
                    state <= START_RX;
                end
            end
            START_RX: begin
                if (counter == 5'd14 && prev_counter != counter) begin
                    if(serial_out == 0) begin
                        state <= DATA_RX;
                    end else begin
                        state <= IDLE;
                    end
                end
            end
            DATA_RX: begin
                if (counter == 5'd14 && prev_counter != counter) begin
                    parallel_out[count] <= serial_out;
        
                if (count == 3'd7) begin
                    state <= STOP_RX;
                    end else begin
                        count <= count + 1'b1;
                    end
                end
            end   
            STOP_RX: begin
                if (counter == 5'd14 && prev_counter != counter) begin
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
   
endmodule
