module ProgramCounter
(
    clk_i,  // System clock
    rst_n,  // All reset
    load_i, // Next PC address
    count_o // PC address for now
);
//*****************************************************************************
    // I/O port declaration
    input  wire          clk_i;   // System clock
    input  wire          rst_n;   // All reset
    input  wire [32-1:0] load_i;  // Next PC address
    output reg  [32-1:0] count_o; // PC address for now
//*****************************************************************************
// Block : PC data out
    always @(posedge clk_i or negedge rst_n) 
    begin
        if(~rst_n)
            count_o <= 0;
        else
            count_o <= load_i;
    end
//*****************************************************************************
endmodule
