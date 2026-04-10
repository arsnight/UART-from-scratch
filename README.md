# UART From Scratch — Full Duplex UART Design

This project implements a UART Transmitter and Receiver entirely from scratch in Verilog, with a focus on:

- FSM-based architecture
- Fully synchronous design
- baud rate generation
- oversampling receiver

The transmitter and receiver were designed independently and later integrated into a full duplex UART system.

# UART-TX design
UART Transmitter (TX) implemented in Verilog from scratch, focusing on FSM design, baud rate generation and a testbench for verification.

## Features
- 115200 Baud UART TX
- FSM based design
- Fully synchronous design
- Testbench verification

# Day 1 - Design
Planned architecture:
- Baud rate generator
- Data storage

A lot in this project was just me switching from the "software" thinking to the hardware thinking. After reviewing the theory and concepts regarding a complete UART module, I decided to start with a transmitter module first as that felt easier than the receiver (And indeed it was!)

The first step in this project was to assume the input data is going to be received to the tx (transmitter) module in parallel form. This usually just meant instead of bit by bit input, the inputs will be a collection of bits instead (better called bytes). Example for the alphabet A, the parallel input would be 01000001. Hence, we need to store this data somewhere because if we use it raw, data can change and then the tx module will just output a bunch of gibberish.

This is where I got my first roadblock, I started thinking in terms of software, making codes like - 
```verilog  
module Input_storage (
  input clk,
  input reset,
  input [7:0] parallel_in,
  output reg [7:0] data_stored
  );
  always @(posedge clk or posedge reset) begin
    if (reset == 1'b1) begin
      data_stored <= 0;
    end
    else begin
      data_stored <= parallel_in;
    end
  end
endmodule
```
Looks correct right? No.
The thing is, this code forces data_stored to update every clock cycle.
For example, imagine transmitting:

A → B → C

If `data_stored` updates continuously, the transmitter may output:

- First few bits from A
- Then some bits from B
- Then remaining bits from C

Absolutely corrupted UART frame, essentially just a gibberish output. This was my first major realization in shifting from software thinking to hardware thinking — signals must often be *latched* at the right time rather than continuously updated.

To solve this I used a trigger, an edge detection logic instead. Introducing a reg start_tx along with another reg prev_state, while using this logic -
```verilog  
module Input_storage (
  input clk,
  input reset,
  input start_tx,
  input [7:0] parallel_in,
  output reg [7:0] data_stored
  );

  reg prev_state = 0;  //------> Don't forget to initialize, a good habit!
  always @(posedge clk or posedge reset) begin
    if (prev_state == 0 && start_tx == 1) begin
      data_stored <= parallel_in;
    end
      prev_state <= start_tx;
  end
endmodule
```
Now that this issue was resolved, the next part was to create the backbone of this project, `The Baud tick generator`. As complicated as it sounds, the code was rather simple. For this project I went with the most common baud rate of 115200:

- For the standard baud tick, Baud rate = 115200 bits/s
- Each bit will last for around 1/115200 seconds or 8.68us
- Assuming a 100 MHz FPGA clock, fundamental time period of on board clock = 10ns
- So, if 1 cycle takes 10ns, then 8.68us/10ns cycles take 8.68us.

By simple arthmetic, each baud tick will last for exactly 868 on board clock ticks. Hence the code logic is simple, initialize a counter that adds each time it isn't equal to 10'd867 (counter starts at 0, so total counts will be from 0 to 867) and reset it once it reaches 10'd867.
```verilog
module baud_rate_gen(
  input clk,
  output reg tick
);
  reg [9:0] count = 0;
  always @(posedge clk) begin
    if (count == 10'd867) begin
      tick <= 1'b1;
      count <= 0;
    end
    else begin
      count <= count + 1'b1;
      tick <= 0;
    end
  end
endmodule
```
This tick signal now acts as the timing reference for the UART FSM, ensuring each bit is transmitted at the correct baud rate.
However, it is important to note that the baud tick is **not another clock**. 
Using it directly in an `always @(posedge tick)` block is dangerous and can 
lead to timing issues.

Instead, a single global clock should be used throughout the design, while 
the baud tick is used as a **clock enable** signal:

# Day 2 - FSM
Planned architecture:
- Finite State Machine

Now started the confusing part of this project (as a beginner), the FSM. For this project i considered the use of four states:
- IDLE : serial_out will be High during the IDLE state.
- START_BIT : Transmit start bit.
- DATA_BITS : This is where the data will be actually transmitted one at a time.
- STOP_BIT : Detect stop bit and stop the FSM.

At first however I made the critical mistake of using multiple state flags like:
```verilog
reg IDLE;
reg START_BIT;
...
```
But this is extremely bad as it allowed for the possibility of multiple states to be active at once, which breakes the fundamental structure of FSM.
The realisation was to create one state variable and use 4 local parameters to assign the states.
```verilog
...
reg [3:0] state = 0;

localparam IDLE = 0;
localparam START_BIT = 1;
localparam DATA_BITS = 2;
localparam STOP_BIT = 3;
...
```

Before proceeding further, finding this in the dubugging state, the start_tx defined earlier was causing the FSM to be level triggered instead of edge triggered resulting in the FSM to retrigger continuously for no reason and causing errors in the transimitted serial output.
To conter this we just use a edge trigger instead by rewriting this code:
```verilog  
...
  reg prev_state = 0;
  always @(posedge clk or posedge reset) begin
    if (prev_state == 0 && start_tx == 1) begin
      data_stored <= parallel_in;
      edge_detect <= 1; //------> Change here
    end else begin
      edge_detect <= 0; //------> Change here
    prev_state <= start_tx;
...
```
Therefore the final FSM written after debugs:
```verilog
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
    
    
    localparam IDLE = 0;
    localparam START_BIT = 1;
    localparam DATA_BITS = 2;
    localparam STOP_BIT = 3;
    
    always @(posedge clk) begin            
            if (tick) begin
                if (state == IDLE) begin
                    serial_out <= 1;
                    if (edge_detect) begin
                        state <= START_BIT;
                    end
                end
                else if (state == START_BIT) begin
                        state <= DATA_BITS;
                        counter <= 0;
                        serial_out <= 0;
                end
                else if (state == DATA_BITS) begin
                    serial_out <= data_stored[counter];
                    counter <= counter + 1'b1;
                    if (counter == 4'd7) begin
                            state <= STOP_BIT;
                    end
                end
                else if (state == STOP_BIT) begin
                        state <= IDLE;
                        counter <= 0;
                        serial_out <= 1;
                end
                end
            end                        
endmodule
```

## Learned Experiences

1. Hardware ≠ Software Thinking
One of the biggest lessons from this project was understanding that hardware behaves fundamentally differently from software.
Initially, I designed logic assuming signals could update continuously without consequences. However, in hardware this can lead to unintended behavior such as data corruption.
This became evident when data_stored was updating every clock cycle, which caused mixed transmission frames. The solution was to latch data at the correct moment using edge detection logic.
This project reinforced that:
Signals must be latched intentionally
Timing matters more than instruction order
Hardware runs in parallel, not sequentially like software

2. Baud Tick is Not a Clock
Another important learning was understanding that the baud tick is not another clock.
Initially, it seemed intuitive to use:
```verilog
always @(posedge tick)
```
However, this creates a derived clock, which can introduce:
Timing violations
Clock domain crossing issues
Unreliable synthesis behavior
Instead, the correct approach is using a clock enable signal:
```verilog
always @(posedge clk)
  if (tick)
```      
This ensures the entire design remains synchronous and stable.

3. Proper FSM Design Matters
At first, I used multiple state flags:
```verilog
reg IDLE;
reg START_BIT;
```
This allowed multiple states to become active simultaneously, breaking FSM behavior.
The correct solution was:
- Use one state register
- Define states using localparam
- Ensure only one active state at any time
- This improved reliability and readability of the design.

4. Edge Detection is Essential in Hardware
The start_tx signal initially retriggered the FSM repeatedly because it was level-triggered.
This led to unexpected retransmissions.
Implementing edge detection solved this:
- Prevented multiple triggers
- Made transmission deterministic
- Improved overall design stability

5. Simple Designs Can Still Be Deep
Although UART TX appears simple, this project required understanding:

- Timing
- FSM design
- Data latching
- Synchronization
- Hardware debugging

This reinforced that even small modules can provide significant learning value.


# UART-RX design
UART Receiver (RX) implemented in Verilog using an unconventional 28× oversampled clock. Designed from scratch with mid-bit sampling, edge-triggered bit capture, and a fully synchronous FSM, without reliance on external IP cores

## Features

- 28× oversampled clock design
- Mid-bit sampling for reliable reception
- Edge-triggered bit capture
- Falling-edge start bit detection
- Fully synchronous FSM
- No vendor IP cores used
- Simulation-tested with multiple byte sequences

## Design Flow

Started on the Receiver module right after the tx, the approach here is a bit more complicated than the latter. There are many ways to write the RX, but it all narrows to either using the baud rate tick method as used in TX or a new technique called Oversampling.

The basic gist of oversampling is rather simple. Instead of sampling once every 868 clk cycles(for the standard baud rate 115200 and 100MHz master clock), we instead sample multiple times over the course of 868 cycles. This allows to use one of the samples to attain any part of our serial input, most commonly the exact mid part of the serial input is sampled. Mid bit sampling is very good as it prevents sampling during transitions and preventing data corruption.

Usually most common oversampling I noted was 16x oversampling which has it's own problems. For my project here with baud rate 115200, we obtain a decimal divider.
A divider is basically, how many master clock cycles you wait before generating one oversampled tick.
Generally,

                       Divider = (Master Clock frequency)/ (Baud Rate x Oversampling rate)
                       
Since I'm Working with a 100MHz master clock,

                       Divider(16x) = 100,000,000/115200 x 16 = 54.253
                       
A decimal divider. Which opens up error if we approximate either way. 55 clock cycles would be too fast and 54 would be too slow, bound to cause timing issues and small errors. The main reason of using 16x oversampling in the older times was because it was cheaper.
My approach was to just find an oversampling rate that evaluated the divider to an integer. The closest next oversampling rate was 28x,

                       Divider(28x) = 100,000,000/115200 x 28 = 31.000
                       
More precisely,

                       115200 x 28  = 3225600
                       3225600 x 31 = 99,993,600
Error,

          100,000,000 - 99,993,600  = 6400
                  6400/100,000,000  = 0.0064% error only
                       
Now that the oversampling rate is decided, the time has come to finally design the module itself. Forget 868, Instead use the theory of divider to sample once every 31 clock cycles and use a counter to sample 28 times and reset once the counter hits 27(counting starts at 0):
``` verilog
module oversampled_clk(
    input clk,
    input rst_trigger, // Added a Reset trigger for future use
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
```
And designing the counter:
``` verilog
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
```
using if (counter == 5'd14) allows mid sampling.

Now time to proceed to the Finite state machine. After making both TX and RX modules the one thing I can't ignore is the level triggered FSM designs breaking the entire module. Level triggers are annoyingly bad, causing frustrations in debugging phases and simulation checks. 

**Always make edge triggered design unless there is an explicit need for a level triggered module.**

The FSM was straightforward and just like the FSM of the TX. Aside from the level triggered issue I committed during the first designs the rest was simple:
``` verilog
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
```
## Future Scalability

1. Parameterizable Baud Rate :
The Current design is limited to baud rate 115200 and a 100 MHz master clock, However future improvements can be made to introduce parameterized baud rate generator and master clock frequency.

2. Configurable Data Length :
Currently, my design can only accomodate for 8 bits of data. However the design is done keeping the scalability to 5-9 bits depending on the needs.

3. Parity bit :
Currently, Parity bit is not included, however I plan to implement even, odd parity and an optional parity enable feature.

4. Integration with UART RX module :
Using the implemented UART RX to integrate TX and RX and build a full UART module.

5. System-Level Integration :
This UART module will eventually become part of larger systems such as a custom CPU, VGA terminal, FPGA operating terminal and many more.
