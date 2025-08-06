//////////////////////////////////////////////////////////////////////////////////
// Engineer: Michael Rosales 
// Module Name: Module N counter
//////////////////////////////////////////////////////////////////////////////////
module timer #(parameter int N = 2000) (
    input logic clk,
    input logic rst_n,
    input logic enable,
    output logic done 
);

localparam int NUM_BITS =  (N > 1)? $clog2(N) : 1;  // gives number of bits needed for specified value
                                                            // prevents any bad outputs for when time is 1
logic [NUM_BITS - 1 : 0] out;                               // gives bit range 

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        out <= 0;
    else if(enable) begin
        if (out == N - 1)
            out <= 0;
        else
            out <= out + 1;
    end
    else 
        out <= 0;
end

assign done = (out == N - 1);                       

endmodule