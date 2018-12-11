module m_encode (
		input wire              clk         , //clock signal
		input wire              reset       , //global reset signal
		input wire              load        , //load input signal
		input wire              start        , //load input signal
		input wire              m_in       , //a coefficient input (one coefficient at a time)

		output wire  [0:2047]    m_out,  //message output (one bit a ta time)
		output reg               compute  //message output (one bit a ta time)
  );

    integer i;

    reg [7:0] m_reg[0:255];
    reg       m_in_reg[0:255];
    reg [7:0] load_count;
    reg [7:0] compute_count;
    
    always@(posedge clk)
    begin
        if(reset == 1)
        begin
           for(i=0;i<256;i=i+1)
           begin
               m_reg[i] <= 383-i;
           end
        end
        else
        begin
            if(compute)
            begin
                if(m_in_reg[compute_count])
                begin
                    m_reg[compute_count] <= m_reg[compute_count] + 128;
                end
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
            compute         <= 0;
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


            if(compute_count == 255)
            begin
                compute  <= 0;
            end
           
        end
    end

assign m_out[0:2047] = {m_reg[0],
			m_reg[1],
			m_reg[2],
			m_reg[3],
			m_reg[4],
			m_reg[5],
			m_reg[6],
			m_reg[7],
			m_reg[8],
			m_reg[9],
			m_reg[10],
			m_reg[11],
			m_reg[12],
			m_reg[13],
			m_reg[14],
			m_reg[15],
			m_reg[16],
			m_reg[17],
			m_reg[18],
			m_reg[19],
			m_reg[20],
			m_reg[21],
			m_reg[22],
			m_reg[23],
			m_reg[24],
			m_reg[25],
			m_reg[26],
			m_reg[27],
			m_reg[28],
			m_reg[29],
			m_reg[30],
			m_reg[31],
			m_reg[32],
			m_reg[33],
			m_reg[34],
			m_reg[35],
			m_reg[36],
			m_reg[37],
			m_reg[38],
			m_reg[39],
			m_reg[40],
			m_reg[41],
			m_reg[42],
			m_reg[43],
			m_reg[44],
			m_reg[45],
			m_reg[46],
			m_reg[47],
			m_reg[48],
			m_reg[49],
			m_reg[50],
			m_reg[51],
			m_reg[52],
			m_reg[53],
			m_reg[54],
			m_reg[55],
			m_reg[56],
			m_reg[57],
			m_reg[58],
			m_reg[59],
			m_reg[60],
			m_reg[61],
			m_reg[62],
			m_reg[63],
			m_reg[64],
			m_reg[65],
			m_reg[66],
			m_reg[67],
			m_reg[68],
			m_reg[69],
			m_reg[70],
			m_reg[71],
			m_reg[72],
			m_reg[73],
			m_reg[74],
			m_reg[75],
			m_reg[76],
			m_reg[77],
			m_reg[78],
			m_reg[79],
			m_reg[80],
			m_reg[81],
			m_reg[82],
			m_reg[83],
			m_reg[84],
			m_reg[85],
			m_reg[86],
			m_reg[87],
			m_reg[88],
			m_reg[89],
			m_reg[90],
			m_reg[91],
			m_reg[92],
			m_reg[93],
			m_reg[94],
			m_reg[95],
			m_reg[96],
			m_reg[97],
			m_reg[98],
			m_reg[99],
			m_reg[100],
			m_reg[101],
			m_reg[102],
			m_reg[103],
			m_reg[104],
			m_reg[105],
			m_reg[106],
			m_reg[107],
			m_reg[108],
			m_reg[109],
			m_reg[110],
			m_reg[111],
			m_reg[112],
			m_reg[113],
			m_reg[114],
			m_reg[115],
			m_reg[116],
			m_reg[117],
			m_reg[118],
			m_reg[119],
			m_reg[120],
			m_reg[121],
			m_reg[122],
			m_reg[123],
			m_reg[124],
			m_reg[125],
			m_reg[126],
			m_reg[127],
			m_reg[128],
			m_reg[129],
			m_reg[130],
			m_reg[131],
			m_reg[132],
			m_reg[133],
			m_reg[134],
			m_reg[135],
			m_reg[136],
			m_reg[137],
			m_reg[138],
			m_reg[139],
			m_reg[140],
			m_reg[141],
			m_reg[142],
			m_reg[143],
			m_reg[144],
			m_reg[145],
			m_reg[146],
			m_reg[147],
			m_reg[148],
			m_reg[149],
			m_reg[150],
			m_reg[151],
			m_reg[152],
			m_reg[153],
			m_reg[154],
			m_reg[155],
			m_reg[156],
			m_reg[157],
			m_reg[158],
			m_reg[159],
			m_reg[160],
			m_reg[161],
			m_reg[162],
			m_reg[163],
			m_reg[164],
			m_reg[165],
			m_reg[166],
			m_reg[167],
			m_reg[168],
			m_reg[169],
			m_reg[170],
			m_reg[171],
			m_reg[172],
			m_reg[173],
			m_reg[174],
			m_reg[175],
			m_reg[176],
			m_reg[177],
			m_reg[178],
			m_reg[179],
			m_reg[180],
			m_reg[181],
			m_reg[182],
			m_reg[183],
			m_reg[184],
			m_reg[185],
			m_reg[186],
			m_reg[187],
			m_reg[188],
			m_reg[189],
			m_reg[190],
			m_reg[191],
			m_reg[192],
			m_reg[193],
			m_reg[194],
			m_reg[195],
			m_reg[196],
			m_reg[197],
			m_reg[198],
			m_reg[199],
			m_reg[200],
			m_reg[201],
			m_reg[202],
			m_reg[203],
			m_reg[204],
			m_reg[205],
			m_reg[206],
			m_reg[207],
			m_reg[208],
			m_reg[209],
			m_reg[210],
			m_reg[211],
			m_reg[212],
			m_reg[213],
			m_reg[214],
			m_reg[215],
			m_reg[216],
			m_reg[217],
			m_reg[218],
			m_reg[219],
			m_reg[220],
			m_reg[221],
			m_reg[222],
			m_reg[223],
			m_reg[224],
			m_reg[225],
			m_reg[226],
			m_reg[227],
			m_reg[228],
			m_reg[229],
			m_reg[230],
			m_reg[231],
			m_reg[232],
			m_reg[233],
			m_reg[234],
			m_reg[235],
			m_reg[236],
			m_reg[237],
			m_reg[238],
			m_reg[239],
			m_reg[240],
			m_reg[241],
			m_reg[242],
			m_reg[243],
			m_reg[244],
			m_reg[245],
			m_reg[246],
			m_reg[247],
			m_reg[248],
			m_reg[249],
			m_reg[250],
			m_reg[251],
			m_reg[252],
			m_reg[253],
			m_reg[254],
			m_reg[255]};
endmodule
