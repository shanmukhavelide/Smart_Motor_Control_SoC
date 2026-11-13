`timescale 1ns/1ps

module seg7_core (
    input  logic        clk_i,
    input  logic        rst_ni,

    input  logic [31:0] seg_data_i,
    input  logic        en_i,
    input  logic        seg_active_low_i,
    input  logic        an_active_low_i,
    input  logic [7:0]  digit_mask_i,
    input  logic [7:0]  dp_i,
    input  logic [15:0] refresh_div_i,

    output logic [7:0]  seg_o,
    output logic [7:0]  an_o
);

    logic [2:0]  digit_idx_q;
    logic [15:0] refresh_cnt_q;

    function automatic logic [2:0] next_enabled_digit(
        input logic [2:0] curr,
        input logic [7:0] mask
    );
        logic [3:0] k;
        logic [2:0] cand;
        logic       found;
        begin
            next_enabled_digit = curr;
            found = 1'b0;
            for (k = 4'd1; k <= 4'd8; k = k + 4'd1) begin
                cand = curr + k[2:0];
                if (!found && mask[cand]) begin
                    next_enabled_digit = cand;
                    found = 1'b1;
                end
            end
        end
    endfunction

    // Round-robin digit scan advancing every SEG_REFRESH_DIV clocks
    always_ff @(posedge clk_i) begin
        if (!rst_ni) begin
            digit_idx_q   <= 3'd0;
            refresh_cnt_q <= 16'd0;
        end else if (!en_i || (digit_mask_i == 8'h00)) begin
            digit_idx_q   <= 3'd0;
            refresh_cnt_q <= 16'd0;
        end else if (!digit_mask_i[digit_idx_q]) begin
            digit_idx_q   <= next_enabled_digit(digit_idx_q, digit_mask_i);
            refresh_cnt_q <= 16'd0;
        end else if ((refresh_div_i <= 16'd1) || (refresh_cnt_q >= (refresh_div_i - 16'd1))) begin
            digit_idx_q   <= next_enabled_digit(digit_idx_q, digit_mask_i);
            refresh_cnt_q <= 16'd0;
        end else begin
            refresh_cnt_q <= refresh_cnt_q + 16'd1;
        end
    end

    logic [3:0] cur_nibble;
    logic       cur_dp;
    logic [6:0] seg_7;
    logic [7:0] seg_int;
    logic [7:0] an_int;

    always @(*) begin
        case (digit_idx_q)
            3'd0: begin cur_nibble = seg_data_i[3:0];   cur_dp = dp_i[0]; end
            3'd1: begin cur_nibble = seg_data_i[7:4];   cur_dp = dp_i[1]; end
            3'd2: begin cur_nibble = seg_data_i[11:8];  cur_dp = dp_i[2]; end
            3'd3: begin cur_nibble = seg_data_i[15:12]; cur_dp = dp_i[3]; end
            3'd4: begin cur_nibble = seg_data_i[19:16]; cur_dp = dp_i[4]; end
            3'd5: begin cur_nibble = seg_data_i[23:20]; cur_dp = dp_i[5]; end
            3'd6: begin cur_nibble = seg_data_i[27:24]; cur_dp = dp_i[6]; end
            3'd7: begin cur_nibble = seg_data_i[31:28]; cur_dp = dp_i[7]; end
        endcase

        // Active-high 7-segment hex lookup: {g,f,e,d,c,b,a}
        case (cur_nibble)
            4'h0: seg_7 = 7'h3F;
            4'h1: seg_7 = 7'h06;
            4'h2: seg_7 = 7'h5B;
            4'h3: seg_7 = 7'h4F;
            4'h4: seg_7 = 7'h66;
            4'h5: seg_7 = 7'h6D;
            4'h6: seg_7 = 7'h7D;
            4'h7: seg_7 = 7'h07;
            4'h8: seg_7 = 7'h7F;
            4'h9: seg_7 = 7'h6F;
            4'hA: seg_7 = 7'h77;
            4'hB: seg_7 = 7'h7C;
            4'hC: seg_7 = 7'h39;
            4'hD: seg_7 = 7'h5E;
            4'hE: seg_7 = 7'h79;
            4'hF: seg_7 = 7'h71;
        endcase

        if (!en_i || !digit_mask_i[digit_idx_q]) begin
            seg_int = 8'h00;
            an_int  = 8'h00;
        end else begin
            seg_int = {cur_dp, seg_7};
            an_int  = (8'h01 << digit_idx_q);
        end
    end

    assign seg_o = seg_active_low_i ? ~seg_int : seg_int;
    assign an_o  = an_active_low_i  ? ~an_int  : an_int;

endmodule
