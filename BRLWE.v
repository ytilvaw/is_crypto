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
	output wire [2047:0] m_out;
	output reg valid;

//////////////////////////////////////

//        YOUR CODE HERE            //

//////////////////////////////////////

    integer i;

    reg [7:0] m_out_reg[0:255];
    reg       m_in_reg[0:255];
    reg [7:0] load_count;
    reg [7:0] compute_count;
	 reg 		  compute;
    
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


assign	m_out[2047:0]	= 	{m_out_reg[255],
				m_out_reg[254],
				m_out_reg[253],
				m_out_reg[252],
				m_out_reg[251],
				m_out_reg[250],
				m_out_reg[249],
				m_out_reg[248],
				m_out_reg[247],
				m_out_reg[246],
				m_out_reg[245],
				m_out_reg[244],
				m_out_reg[243],
				m_out_reg[242],
				m_out_reg[241],
				m_out_reg[240],
				m_out_reg[239],
				m_out_reg[238],
				m_out_reg[237],
				m_out_reg[236],
				m_out_reg[235],
				m_out_reg[234],
				m_out_reg[233],
				m_out_reg[232],
				m_out_reg[231],
				m_out_reg[230],
				m_out_reg[229],
				m_out_reg[228],
				m_out_reg[227],
				m_out_reg[226],
				m_out_reg[225],
				m_out_reg[224],
				m_out_reg[223],
				m_out_reg[222],
				m_out_reg[221],
				m_out_reg[220],
				m_out_reg[219],
				m_out_reg[218],
				m_out_reg[217],
				m_out_reg[216],
				m_out_reg[215],
				m_out_reg[214],
				m_out_reg[213],
				m_out_reg[212],
				m_out_reg[211],
				m_out_reg[210],
				m_out_reg[209],
				m_out_reg[208],
				m_out_reg[207],
				m_out_reg[206],
				m_out_reg[205],
				m_out_reg[204],
				m_out_reg[203],
				m_out_reg[202],
				m_out_reg[201],
				m_out_reg[200],
				m_out_reg[199],
				m_out_reg[198],
				m_out_reg[197],
				m_out_reg[196],
				m_out_reg[195],
				m_out_reg[194],
				m_out_reg[193],
				m_out_reg[192],
				m_out_reg[191],
				m_out_reg[190],
				m_out_reg[189],
				m_out_reg[188],
				m_out_reg[187],
				m_out_reg[186],
				m_out_reg[185],
				m_out_reg[184],
				m_out_reg[183],
				m_out_reg[182],
				m_out_reg[181],
				m_out_reg[180],
				m_out_reg[179],
				m_out_reg[178],
				m_out_reg[177],
				m_out_reg[176],
				m_out_reg[175],
				m_out_reg[174],
				m_out_reg[173],
				m_out_reg[172],
				m_out_reg[171],
				m_out_reg[170],
				m_out_reg[169],
				m_out_reg[168],
				m_out_reg[167],
				m_out_reg[166],
				m_out_reg[165],
				m_out_reg[164],
				m_out_reg[163],
				m_out_reg[162],
				m_out_reg[161],
				m_out_reg[160],
				m_out_reg[159],
				m_out_reg[158],
				m_out_reg[157],
				m_out_reg[156],
				m_out_reg[155],
				m_out_reg[154],
				m_out_reg[153],
				m_out_reg[152],
				m_out_reg[151],
				m_out_reg[150],
				m_out_reg[149],
				m_out_reg[148],
				m_out_reg[147],
				m_out_reg[146],
				m_out_reg[145],
				m_out_reg[144],
				m_out_reg[143],
				m_out_reg[142],
				m_out_reg[141],
				m_out_reg[140],
				m_out_reg[139],
				m_out_reg[138],
				m_out_reg[137],
				m_out_reg[136],
				m_out_reg[135],
				m_out_reg[134],
				m_out_reg[133],
				m_out_reg[132],
				m_out_reg[131],
				m_out_reg[130],
				m_out_reg[129],
				m_out_reg[128],
				m_out_reg[127],
				m_out_reg[126],
				m_out_reg[125],
				m_out_reg[124],
				m_out_reg[123],
				m_out_reg[122],
				m_out_reg[121],
				m_out_reg[120],
				m_out_reg[119],
				m_out_reg[118],
				m_out_reg[117],
				m_out_reg[116],
				m_out_reg[115],
				m_out_reg[114],
				m_out_reg[113],
				m_out_reg[112],
				m_out_reg[111],
				m_out_reg[110],
				m_out_reg[109],
				m_out_reg[108],
				m_out_reg[107],
				m_out_reg[106],
				m_out_reg[105],
				m_out_reg[104],
				m_out_reg[103],
				m_out_reg[102],
				m_out_reg[101],
				m_out_reg[100],
				m_out_reg[99],
				m_out_reg[98],
				m_out_reg[97],
				m_out_reg[96],
				m_out_reg[95],
				m_out_reg[94],
				m_out_reg[93],
				m_out_reg[92],
				m_out_reg[91],
				m_out_reg[90],
				m_out_reg[89],
				m_out_reg[88],
				m_out_reg[87],
				m_out_reg[86],
				m_out_reg[85],
				m_out_reg[84],
				m_out_reg[83],
				m_out_reg[82],
				m_out_reg[81],
				m_out_reg[80],
				m_out_reg[79],
				m_out_reg[78],
				m_out_reg[77],
				m_out_reg[76],
				m_out_reg[75],
				m_out_reg[74],
				m_out_reg[73],
				m_out_reg[72],
				m_out_reg[71],
				m_out_reg[70],
				m_out_reg[69],
				m_out_reg[68],
				m_out_reg[67],
				m_out_reg[66],
				m_out_reg[65],
				m_out_reg[64],
				m_out_reg[63],
				m_out_reg[62],
				m_out_reg[61],
				m_out_reg[60],
				m_out_reg[59],
				m_out_reg[58],
				m_out_reg[57],
				m_out_reg[56],
				m_out_reg[55],
				m_out_reg[54],
				m_out_reg[53],
				m_out_reg[52],
				m_out_reg[51],
				m_out_reg[50],
				m_out_reg[49],
				m_out_reg[48],
				m_out_reg[47],
				m_out_reg[46],
				m_out_reg[45],
				m_out_reg[44],
				m_out_reg[43],
				m_out_reg[42],
				m_out_reg[41],
				m_out_reg[40],
				m_out_reg[39],
				m_out_reg[38],
				m_out_reg[37],
				m_out_reg[36],
				m_out_reg[35],
				m_out_reg[34],
				m_out_reg[33],
				m_out_reg[32],
				m_out_reg[31],
				m_out_reg[30],
				m_out_reg[29],
				m_out_reg[28],
				m_out_reg[27],
				m_out_reg[26],
				m_out_reg[25],
				m_out_reg[24],
				m_out_reg[23],
				m_out_reg[22],
				m_out_reg[21],
				m_out_reg[20],
				m_out_reg[19],
				m_out_reg[18],
				m_out_reg[17],
				m_out_reg[16],
				m_out_reg[15],
				m_out_reg[14],
				m_out_reg[13],
				m_out_reg[12],
				m_out_reg[11],
				m_out_reg[10],
				m_out_reg[9],
				m_out_reg[8],
				m_out_reg[7],
				m_out_reg[6],
				m_out_reg[5],
				m_out_reg[4],
				m_out_reg[3],
				m_out_reg[2],
				m_out_reg[1],
				m_out_reg[0]};
 
endmodule
