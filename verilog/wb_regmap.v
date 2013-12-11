// Based on http://opencores.org/project,spi
module wb_regmap(
	// Wishbone signals
	wb_clk_i, wb_rst_i, wb_adr_i, wb_dat_i, wb_dat_o, wb_sel_i,	wb_cti_i,
	wb_we_i, wb_stb_i, wb_cyc_i, wb_ack_o, wb_err_o, wb_int_o,
	debug_out
);
// Wishbone slave signals
input wb_clk_i;
input wb_rst_i;
input [4:0] wb_adr_i;
input [15:0] wb_dat_i;
output [15:0] wb_dat_o;
input [1:0] wb_sel_i;
input [2:0] wb_cti_i;
input wb_we_i;
input wb_stb_i;
input wb_cyc_i;
output wb_ack_o;
output wb_err_o;
output wb_int_o;
output [15:0] debug_out;

assign debug_out = {fifo_rd_addr,fifo_wr,fifo_rd,wb_stb_i,wb_ack_o};

// This is used to force addressing errors on poor handshake implementation
wire [4:0] int_addr;
assign int_addr = (wb_cyc_i) ? wb_adr_i : 5'h1F;

// End of Transfer
wire eot;
assign eot = ((wb_cti_i == 3'b000) & wb_ack_o) | (wb_cti_i == 3'b111);

// Handshake - synchronous due to nature of block RAM
reg wb_ack_o;
always @(posedge wb_clk_i) begin
	// Set by STB and itself, cleared by EOT or RST
	wb_ack_o <= (wb_stb_i | wb_ack_o) & ~(eot | wb_rst_i);
end

// Interrupt and Error
reg wb_int_o;
reg wb_err_o;
always @(posedge wb_clk_i) begin
	if (wb_rst_i) begin
		wb_int_o <= 1'b0;
		wb_err_o <= 1'b0;
	end
end

// Register map
reg [4:0] rm_addr_in;
reg [15:0] reg_map [31:0];
reg [15:0] rm_data_in;
reg [15:0] rm_data_out;

// Latch data out on a read request
reg [15:0] rm_dat_o;
always @(posedge wb_clk_i) begin
	if (~wb_we_i) begin
		rm_dat_o <= rm_data_out;
	end
end

// Latch data in on a write request
always @(posedge wb_clk_i) begin
	if (wb_we_i) begin
		reg_map[int_addr] <= rm_data_in;
	end
end

// Write to registers multiplex
always @(int_addr or wb_dat_i) begin
	case (int_addr)
		0:	rm_data_in <= wb_dat_i;
		1:	rm_data_in <= wb_dat_i;
		2:	rm_data_in <= wb_dat_i;
		3:	rm_data_in <= wb_dat_i;
		4:	rm_data_in <= wb_dat_i;
		5:	rm_data_in <= wb_dat_i;
		6:	rm_data_in <= wb_dat_i;
		7:	rm_data_in <= wb_dat_i;
		16:	fifo_din <= wb_dat_i;
		default: rm_data_in <= 16'hAAAA;
	endcase
end

// Read from registers multiplex
always @(int_addr or reg_map) begin
	case (int_addr)
		0:	rm_data_out <= reg_map[int_addr];
		1:	rm_data_out <= reg_map[int_addr];
		2:	rm_data_out <= reg_map[int_addr];
		3:	rm_data_out <= reg_map[int_addr];
		4:	rm_data_out <= reg_map[int_addr];
		5:	rm_data_out <= reg_map[int_addr];
		6:	rm_data_out <= reg_map[int_addr];
		7:	rm_data_out <= reg_map[int_addr];
		8:	rm_data_out <= reg_map[int_addr];
		//16:	rm_data_out <= fifo_dout;
		default: rm_data_out <= 16'd12345;
	endcase
end

// Loop-back FIFO for testing
wire burst_mode;
assign burst_mode = ~(wb_cti_i == 3'b000);

wire fifo_sel;
assign fifo_sel = (int_addr == 5'h10) & wb_stb_i;
wire fifo_wr;
wire fifo_rd;
wire fifo_rd_look;
assign fifo_wr = burst_mode & fifo_sel & wb_ack_o & wb_we_i;
assign fifo_rd = burst_mode & fifo_sel & wb_ack_o & ~wb_we_i;

reg [15:0]		fifo_din;
wire [15:0]		fifo_dout;
reg	 [9:0]		fifo_wr_addr;
reg	 [9:0]		fifo_rd_addr;

// Bypass register map when accessing the FIFO
assign wb_dat_o = (fifo_rd) ? fifo_dout : rm_dat_o;

always @(posedge wb_clk_i) begin
	if (wb_rst_i) begin
		fifo_wr_addr <= 9'd0;
		fifo_rd_addr <= 9'd0;
	end else begin
		if (fifo_wr)
			fifo_wr_addr <= fifo_wr_addr + 9'd1;
		else
			fifo_wr_addr <= fifo_wr_addr;
		if ((wb_cti_i == 3'b001) & fifo_sel & ~wb_we_i)
			fifo_rd_addr <= fifo_rd_addr + 9'd1;
		else if ((wb_cti_i == 3'b111) & fifo_sel & wb_we_i)
			fifo_rd_addr <= fifo_rd_addr - 9'd1;
		else
			fifo_rd_addr <= fifo_rd_addr;
	end
end


dp_ram rm_fifo(
	// Write port
	.a_clk(wb_clk_i), .a_wr(fifo_wr), .a_addr(fifo_wr_addr),
	.a_din(fifo_din), .a_dout(),
	// Read port
	.b_clk(wb_clk_i), .b_wr(1'b0), .b_addr(fifo_rd_addr),
	.b_din(16'b0), .b_dout(fifo_dout)
);
	
endmodule
