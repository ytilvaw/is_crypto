module m_encode (
		input wire              clk         , //clock signal
		input wire              reset       , //global reset signal
		input wire              load        , //load input signal
		input wire              start        , //load input signal
		input wire              m_in       , //a coefficient input (one coefficient at a time)

		output reg  [7:0]    m_out,  //message output (one bit a ta time)
		output reg               compute,  //message output (one bit a ta time)
		output reg               valid  //message output (one bit a ta time)
  );

   integer i;

    reg [7:0] m_out_reg[0:255];
    reg       m_in_reg[0:255];
    reg [7:0] load_count;
    reg [7:0] compute_count;
    reg [7:0] valid_count;
    
    assign reset = ~resetn;

    always@(posedge clk)
    begin
        if(reset == 1)
        begin
           for(i=0;i<256;i=i+1)
           begin
               m_out_reg[i] <= 383-i;
           end
        end
        else
        begin
            if(compute)
            begin
                if(m_in_reg[compute_count])
                begin
                    m_out_reg[compute_count] <= m_out_reg[compute_count] + 128;
                end
            end
        end
    end

	
    always@(posedge clk)
    begin
        if(reset == 1)
        begin
	    m_out <= 0;
	end
	else
	begin
	    if(valid)
	    begin
	    	m_out <= m_out_reg[valid_count];
	    end
	end
    end

    always@(posedge clk)
    begin
        if(reset == 1)
        begin
           for(i=0;i<256;i=i+1)
           begin
               m_in_reg[i] <= 0;
           end
        end
        else
        begin
            if(load)
            begin
                m_in_reg[load_count]     <= m_in;
            end 
        end
    end

    always @(posedge clk)
    begin
        if(reset)
        begin
            load_count      <= 0;
            compute_count   <= 0;
            valid_count     <= 0;
            compute         <= 0;
            valid           <= 0;
        end
        else 
        begin
            if(load)
            begin
                load_count      <= load_count+1;
            end

            if(start)
            begin
                compute         <= 1;
            end

            if(compute)
            begin
                compute_count   <= compute_count +1;
            end

            if(valid)
            begin
                valid_count   <= valid_count +1;
            end

            if(compute_count == 255)
            begin
                compute  <= 0;
		        valid    <= 1;
            end
           
            if(valid_count == 255)
            begin
		        valid    <= 0;
            end
        end
    end

endmodule
