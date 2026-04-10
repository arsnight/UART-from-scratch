`timescale 1ns / 1ps

module UART_main(
    input clk,
    input [7:0] parallel_in,
    input start_tx,
    output [7:0] parallel_out
    );
    
    wire serial_out;
    
    UART_TX Transmitter(
        .clk(clk),
        .parallel_in(parallel_in),
        .start_tx(start_tx),
        .serial_out(serial_out)
        );
            
    UART_RX Receiver(
        .clk(clk),
        .serial_out(serial_out),
        .parallel_out(parallel_out)
        );
endmodule

module UART_TX(
    input clk,
    input [7:0] parallel_in,
    input start_tx,
    output serial_out
    );


    reg [7:0] data_stored;
    reg prev_state = 0;
    reg edge_detect = 0;
    reg edge_detect_d = 0;
    wire tick;
    
    always @(posedge clk) begin
        edge_detect_d <= edge_detect;
        if (prev_state == 0 && start_tx == 1) begin
            data_stored <= parallel_in;
            edge_detect <= 1;
        end
        
        else if(edge_detect_d && tick) begin
            edge_detect <= 0;
        end
                
        prev_state <= start_tx;
    end
      
    baud_rate_gen baud_rate(
        .clk(clk),
        .tick(tick)
        );

    uart_tx_fsm fsm_init(
        .clk(clk),
        .data_stored(data_stored),
        .tick(tick),
        .edge_detect(edge_detect),
        .serial_out(serial_out)
        );
            
endmodule

module UART_RX(
    input clk,
    input serial_out,
    output reg [7:0] parallel_out = 0
); 
    reg sync1 = 0;
    reg sync2 = 0;
    reg [2:0] state = 0;
    reg prev_serial_out = 1;
    reg [2:0] count = 0;
    reg rst_trigger = 0;
    reg [4:0] prev_counter = 0;
    wire [4:0] counter; //wire shouldn't be initialized, Module output already drives it
      
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
       sync1 <= serial_out;
       sync2 <= sync1; 
       rst_trigger <= 0;
       case(state)
            IDLE: begin
                if (prev_serial_out == 1 && sync2 == 0) begin
                    rst_trigger <= 1;
                    state <= START_RX;
                end
            end
            START_RX: begin
                if (counter == 5'd14 && prev_counter != counter) begin
                    if(sync2 == 0) begin
                        state <= DATA_RX;
                    end else begin
                        state <= IDLE;
                    end
                end
            end
            DATA_RX: begin
                if (counter == 5'd14 && prev_counter != counter) begin
                    parallel_out[count] <= sync2;
        
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
        prev_serial_out <= sync2;
   end
   
endmodule

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

module uart_tx_fsm(
    input clk,
    input [7:0] data_stored,
    input tick,
    input edge_detect,
    output reg serial_out
    );
    
    initial serial_out = 1;
    
    reg [3:0] state = 0;
    reg [3:0] counter = 0;
    reg output_pipeline = 1;
    
    localparam IDLE = 0;
    localparam START_BIT = 1;
    localparam DATA_BITS = 2;
    localparam STOP_BIT = 3;
    
    always @(posedge clk) begin            
            if (tick) begin
                serial_out <= output_pipeline;
                if (state == IDLE) begin
                    output_pipeline <= 1;
                    if (edge_detect) begin
                        state <= START_BIT;
                    end
                end
                else if (state == START_BIT) begin
                        state <= DATA_BITS;
                        counter <= 0;
                        output_pipeline <= 0;
                end
                else if (state == DATA_BITS) begin
                    output_pipeline <= data_stored[counter];
                    counter <= counter + 1'b1;
                    if (counter == 4'd7) begin
                            state <= STOP_BIT;
                    end
                end
                else if (state == STOP_BIT) begin
                        state <= IDLE;
                        counter <= 0;
                        output_pipeline <= 1;
                end
                end
            end                        
endmodule

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
