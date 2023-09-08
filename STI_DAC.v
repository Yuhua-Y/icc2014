module STI_DAC(clk ,reset, load, pi_data, pi_length, pi_fill, pi_msb, pi_low, pi_end,
	       so_data, so_valid,
	       oem_finish, oem_dataout, oem_addr,
	       odd1_wr, odd2_wr, odd3_wr, odd4_wr, even1_wr, even2_wr, even3_wr, even4_wr);

input		clk, reset;
input		load, pi_msb, pi_low, pi_end; 
input	[15:0]	pi_data;
input	[1:0]	pi_length;
input		pi_fill;
output		so_data, so_valid;

output  oem_finish, odd1_wr, odd2_wr, odd3_wr, odd4_wr, even1_wr, even2_wr, even3_wr, even4_wr;
output [4:0] oem_addr;
output reg[7:0] oem_dataout;

//==============================================================================
reg [3:0]cur_st,nex_st;
reg [2:0]dac_cur_st,dac_nex_st;
parameter IDLE=4'd0,READ=4'd1,CAL=4'd2,OUT=4'd3;
parameter DAC_IDLE=3'd0,DAC_READ=3'd1,DAC_ODD=3'd2,DAC_EVEN=3'd3;

reg [15:0] in_data;
reg [31:0] out_data;
reg [7:0]dac_out_data;
reg [5:0]out_counter,out_sub;
reg [8:0]dac_counter;
reg [2:0]oem_out_counter;
reg cal_done,out_done,read_done;
wire odd,even;

assign so_valid=(cur_st==OUT)?1:0;
assign so_data=(cur_st==OUT)?out_data[out_counter]:0;
assign oem_addr=dac_counter[5:1];
assign odd=((dac_counter[3:0]==0)|(dac_counter[3:0]==4'h2)|(dac_counter[3:0]==4'h4)|(dac_counter[3:0]==4'h6)|(dac_counter[3:0]==4'h9)|(dac_counter[3:0]==4'hb)|(dac_counter[3:0]==4'hd)|(dac_counter[3:0]==4'hf));
assign even=((dac_counter[3:0]==4'h1)|(dac_counter[3:0]==4'h3)|(dac_counter[3:0]==4'h5)|(dac_counter[3:0]==4'h7)|(dac_counter[3:0]==4'h8)|(dac_counter[3:0]==4'ha)|(dac_counter[3:0]==4'hc)|(dac_counter[3:0]==4'he));

assign odd1_wr=((dac_cur_st==DAC_ODD)&(odd)&(dac_counter[7:6]==0))?1:0;
assign odd2_wr=((dac_cur_st==DAC_ODD)&(odd)&(dac_counter[7:6]==1))?1:0;
assign odd3_wr=((dac_cur_st==DAC_ODD)&(odd)&(dac_counter[7:6]==2))?1:0;
assign odd4_wr=((dac_cur_st==DAC_ODD)&(odd)&(dac_counter[7:6]==3))?1:0;
assign even1_wr=((dac_cur_st==DAC_EVEN)&(even)&(dac_counter[7:6]==0))?1:0;
assign even2_wr=((dac_cur_st==DAC_EVEN)&(even)&(dac_counter[7:6]==1))?1:0;
assign even3_wr=((dac_cur_st==DAC_EVEN)&(even)&(dac_counter[7:6]==2))?1:0;
assign even4_wr=((dac_cur_st==DAC_EVEN)&(even)&(dac_counter[7:6]==3))?1:0;
//==============================================================================
always @(posedge clk or posedge reset) begin
	if(reset)
		cur_st<=IDLE;
	else
		cur_st<=nex_st;
end

always @(*) begin
	case(cur_st)
		IDLE:nex_st=READ;
		READ:nex_st=(read_done)?CAL:READ;
		CAL:nex_st=(cal_done)?OUT:CAL;
		OUT:nex_st=(out_done)?READ:OUT;
		default:nex_st=IDLE;
	endcase	
end



//out_data
always @(posedge clk or posedge reset) begin
 if(reset)
  out_data<=0;
 else if(cur_st==CAL)begin
  case(pi_length)
   2'b00:begin//out 8bit
    if(pi_low)
     out_data[7:0]<=in_data[15:8];
    else
     out_data[7:0]<=in_data[7:0];
   end
   2'b01:begin//out 16bit
    out_data<={16'd0,in_data[15:0]};
   end
   2'b10:begin//out 24
    if(pi_fill)
     out_data<={in_data,8'd0};
    else
     out_data<={8'd0,in_data};
   end
   2'b11:begin//out 32
    if(pi_fill)
     out_data<={in_data,16'd0};
    else
     out_data<={16'd0,in_data};
   end
  endcase
 end
end

//read_done
always @(posedge clk or posedge reset) begin
	if(reset)
		read_done<=0;
	else if(cur_st==READ)
		read_done<=1;
	else
		read_done<=0;
end

//cal_done
always @(posedge clk or posedge reset) begin
	if(reset)
		cal_done<=0;
	else if(cur_st==CAL)
		cal_done<=1;
	else
		cal_done<=0;
end
//in_data
always @(posedge clk or posedge reset) begin
	if(reset)
		in_data<=0;
	else if(cur_st==READ)begin
		if(pi_end)
			in_data<=0;
		else
			in_data<=pi_data;
	end
end

//out_counter
always @(posedge clk or posedge reset) begin
	if(reset)
		out_counter<=0;
	else if(cur_st==READ)begin
		if(pi_msb)begin	
			case (pi_length)
				2'd0:out_counter<=6'd7;
				2'd1:out_counter<=6'd15;
				2'd2:out_counter<=6'd23;
				2'd3:out_counter<=6'd31;
			endcase
			end
		else
			out_counter<=0;
	end
	else if(cur_st==OUT)begin
		if(pi_msb)
			out_counter<=out_counter-1;
		else
			out_counter<=out_counter+1;
	end
end

//out_done
always @(posedge clk or posedge reset) begin
	if(reset)
		out_done<=0;
	else if(cur_st==OUT)begin
		if(pi_msb)begin
			if(out_counter==1)
				out_done<=1;
			else 
				out_done<=0;
		end
		else begin
			if((pi_length==0)&(out_counter==6))
				out_done<=1;
			else if ((pi_length==1)&(out_counter==14))
				out_done<=1;
			else if((pi_length==2)&(out_counter==22))
				out_done<=1;
			else if((pi_length==3)&(out_counter==30))
				out_done<=1;
			else
				out_done<=0;
		end
	end
	else 
		out_done<=0;
end


////////////////////////////////////////////////////////////////
/////dac
assign oem_finish=(dac_counter==9'd256)?1:0;

always @(posedge clk or posedge reset) begin
	if(reset)
		dac_cur_st<=DAC_IDLE;
	else
		dac_cur_st<=dac_nex_st;
end

always @(*) begin
	case(dac_cur_st)
		DAC_IDLE:dac_nex_st=DAC_READ;
		DAC_READ:dac_nex_st=(oem_out_counter!=0)?DAC_READ:(odd)?DAC_ODD:DAC_EVEN;
		DAC_ODD:dac_nex_st=DAC_READ;
		DAC_EVEN:dac_nex_st=DAC_READ;
		default:dac_nex_st=DAC_IDLE;
	endcase
end

//dac_counter
always @(posedge clk or posedge reset) begin
	if(reset)
		dac_counter<=0;
	else if((dac_cur_st==DAC_ODD)|(dac_cur_st==DAC_EVEN))begin
		dac_counter<=dac_counter+1;
	end
end

//oem_out_counter
always @(posedge clk or posedge reset) begin
	if(reset)
		oem_out_counter<=7;
	else if(so_valid)
		oem_out_counter<=oem_out_counter-1;
	else 
		oem_out_counter<=7;
end

//dac_out_data
always @(posedge clk or posedge reset) begin
	if(reset)
		oem_dataout<=0;
	else if(so_valid)
		oem_dataout[oem_out_counter]<=so_data;
end

endmodule
