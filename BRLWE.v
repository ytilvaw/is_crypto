///////////////////////////////////////////////////////////////////////////////////////
// Company             : UEC
// Engineer            : 
// 
// Create Date         : July/29/2014 
// Module Name         : aes128_table_ecb
// Project Name        : sakura_g_aes128
// Target Devices      : xc6slx75-2csg484
// Tool versions       : 13.4
// Description         : 
//
// Dependencies        : 
//
// Version             : 1.0
// Last Uodate         : July/29/2014
// Additional Comments : 
///////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) Satoh LaboratoryÅCUEC

`timescale 1 ns/10 ps


module BRLWE (
		clk, 
		resetn,
		load,   
		m_in,
      	start,		
		m_out,
		valid
);

input clk;
input resetn;
input load;
input start;
input m_in;
output reg m_out;
output reg valid;
reg d_valid;
wire int_rst;

//////////////////////////////////////

//        YOUR CODE HERE            //

//////////////////////////////////////


   integer i;

    reg [7:0] m_out_reg[0:256];
    reg [7:0] load_count;
    reg [8:0] valid_count;
    
    assign reset = ~resetn;

    always@(posedge clk)
    begin
        if(reset || int_rst)
        begin
           for(i=0;i<256;i=i+1)
           begin
               m_out_reg[i] <= 383-i;
           end
           m_out_reg[256] <= 0;
        end
        else
        begin
            if(load)
            begin
                if(m_in)
                begin
                    m_out_reg[load_count]     <= m_out_reg[load_count] + 128;
                end
            end 
        end
    end


    always @(posedge clk)
    begin
        if(reset || int_rst)
        begin
            m_out <= 0;
        end
        else
        begin
            if((valid) || (load_count == 255))
            begin
                if(valid_count < 128)
                begin
                    if(m_out_reg[valid_count] > 128)
                    begin
                        m_out <= 1;
                    end
                    else
                    begin
                        m_out <= 0;
                    end
                end
                else
                begin
                    if(m_out_reg[valid_count] > 128)
                    begin
                        m_out <= 0;
                    end
                    else
                    begin
                        m_out <= 1;
                    end
                end
            end
        end
    end

    
    always @(posedge clk)
    begin
        if(reset || int_rst)
        begin
            load_count      <= 0;
            valid_count     <= 0;
            valid           <= 0;
            d_valid           <= 0;
        end
        else 
        begin
            d_valid         <= valid;
            if(load)
            begin
                load_count      <= load_count+1;
            end

            if(valid )
            begin
                valid_count   <= valid_count +1;
            end

            if(load_count == 255)
            begin
		        valid    <= 1;
		        valid_count    <= 1;
            end
           
            if(valid_count == 256)
            begin
		        valid    <= 0;
            end
        end
    end

    assign int_rst = (!valid & d_valid);

endmodule
