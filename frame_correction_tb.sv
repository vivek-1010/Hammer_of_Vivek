`timescale 1ns/1ps

module frame_correction_tb;

    parameter WIDTH  = 320;
    parameter HEIGHT = 240;

    // DUT signals
    logic clk;
    logic rst_n;

    logic in_valid;
    logic [7:0] pix_in;

    logic frame_start;
    logic frame_end;

    logic out_valid;
    logic [7:0] pix_out;
    logic [15:0] banding_metric;

    // Instantiate DUT
    frame_correction #(
        .WIDTH(WIDTH),
        .HEIGHT(HEIGHT)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(in_valid),
        .pix_in(pix_in),
        .frame_start(frame_start),
        .frame_end(frame_end),
        .out_valid(out_valid),
        .pix_out(pix_out),
        .banding_metric(banding_metric)
    );

    // Clock generation (10ns period)
    always #5 clk = ~clk;

    // Dump waveform
    initial begin
        $dumpfile("wave.vcd");
        $dumpvars(0, frame_correction_tb);
    end

    // Reset task
    task reset_dut;
        begin
            rst_n = 0;
            in_valid = 0;
            frame_start = 0;
            frame_end = 0;
            pix_in = 0;
            #20;
            rst_n = 1;
        end
    endtask

    // Frame generator
    task send_frame;
        int r, c;
        begin
            @(posedge clk);
            frame_start = 1;
            in_valid = 1;

            for (r = 0; r < HEIGHT; r = r + 1) begin
                for (c = 0; c < WIDTH; c = c + 1) begin

                    // Artificial banding pattern
                    pix_in = 8'd50 + r;

                    @(posedge clk);
                    frame_start = 0;
                end
            end

            frame_end = 1;
            @(posedge clk);

            frame_end = 0;
            in_valid = 0;
        end
    endtask

    // Main stimulus
    initial begin
        clk = 0;

        reset_dut();

        // First frame (compute stats)
        send_frame();

        // Small gap
        repeat(20) @(posedge clk);

        // Second frame (correction applied)
        send_frame();

        #1000;
        $finish;
    end

    // Monitor outputs
    always @(posedge clk) begin
        if(out_valid) begin
            $display("Time=%0t | IN=%0d OUT=%0d",
                     $time, pix_in, pix_out);
        end
    end

    // Print banding metric
    always @(posedge clk) begin
        if(frame_end) begin
            $display("Time=%0t | Banding Metric = %0d",
                     $time, banding_metric);
        end
    end

endmodule