module frame_correction #(
    parameter WIDTH  = 320,
    parameter HEIGHT = 240
)(
    input  logic        clk,
    input  logic        rst_n,

    input  logic        in_valid,
    input  logic [7:0]  pix_in,

    input  logic        frame_start,
    input  logic        frame_end,

    output logic        out_valid,
    output logic [7:0]  pix_out,
    output logic [15:0] banding_metric
);

logic [$clog2(WIDTH)-1:0]  col_cnt;
logic [$clog2(HEIGHT)-1:0] row_cnt;
logic [16:0] row_sum;                 // Row accumulation
logic [7:0]  row_mean [0:HEIGHT-1];   // Storage for row means
logic [7:0]  row_mean_calc;
logic row_done;
logic[24:0] frame_sum;
logic[7:0] global_mean;
logic signed [8:0] correction;
logic  signed [9:0] pix_corr;
logic [7:0] max_row_mean;
logic [7:0] min_row_mean;


assign row_done = in_valid && (col_cnt == WIDTH-1);


// Column counter
always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        col_cnt <= 0;

    else if(frame_start)
        col_cnt <= 0;

    else if(in_valid) begin
        if(col_cnt == WIDTH-1)
            col_cnt <= 0;
        else
            col_cnt <= col_cnt + 1;
    end
end


// Row counter
always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        row_cnt <= 0;

    else if(frame_start)
        row_cnt <= 0;

    else if(row_done) begin
        if(row_cnt == HEIGHT-1)
            row_cnt <= 0;
        else
            row_cnt <= row_cnt + 1;
    end
end


// Row pixel accumulation
always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        row_sum <= 0;

    else if(frame_start)
        row_sum <= 0;

    else if(in_valid) begin
        if(col_cnt == 0)
            row_sum <= pix_in;          // first pixel of row
        else
            row_sum <= row_sum + pix_in;
    end
end


// Row mean calculation
always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        row_mean_calc <= 0;

    else if(row_done)
        row_mean_calc <= row_sum / WIDTH;
end

// Store row mean
always_ff @(posedge clk) begin
    if(row_done)
        row_mean[row_cnt] <= row_mean_calc;
end

//Calculate frame sum for global mean
always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        frame_sum <= 0;

    else if(frame_start)
        frame_sum <= 0;

    else if(in_valid)
        frame_sum <= frame_sum + pix_in;
end

// Global mean calculation
always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        global_mean <= 0;

    else if(in_valid)
        global_mean <= frame_sum/(WIDTH * HEIGHT);
end

always_comb begin
    correction = $signed(global_mean) - $signed(row_mean[row_cnt]);
end

always_comb begin
    pix_corr = $signed(pix_in) + correction;
end

always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        pix_out   <= 0;
        out_valid <= 0;
    end
    else begin
        out_valid <= in_valid;

        if(pix_corr < 0)
            pix_out <= 8'd0;
        else if(pix_corr > 255)
            pix_out <= 8'd255;
        else
            pix_out <= pix_corr[7:0];
    end
end

// always_ff @(posedge clk or negedge rst_n) begin
//     if(!rst_n) begin
//         max_row_mean <= 0;
//         min_row_mean <= 8'hff;
//     end
//     else if(frame_start) begin
//         max_row_mean <= 0;
//         min_row_mean <= 8'hff;
//     end

//     else if(row_done) begin

//     if(row_mean_calc > max_row_mean)
//         max_row_mean <= row_mean_calc;

//     if(row_mean_calc < min_row_mean)
//         min_row_mean <= row_mean_calc;

//     end
// end

// Track max and min row mean
always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        max_row_mean <= 8'd0;
        min_row_mean <= 8'd255;
    end

    else if(frame_start) begin
        max_row_mean <= 8'd0;
        min_row_mean <= 8'd255;
    end

    // Update when a row is completed
    else if(row_done) begin
        if(row_mean_calc > max_row_mean)
            max_row_mean <= row_mean_calc;

        if(row_mean_calc < min_row_mean)
            min_row_mean <= row_mean_calc;
    end
end

//Creatin the banding metric
always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        banding_metric <= 16'd0;

    else if(frame_end)
        banding_metric <= max_row_mean - min_row_mean;
end

endmodule
