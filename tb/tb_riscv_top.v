`timescale 1ns / 1ps

// Ajustar solo estas dos expectativas al cambiar programa.mem.
module tb_riscv_top #(
    parameter [31:0] B_INICIAL = 33,
    parameter [31:0] DIR_R = 32'h3E4
);
    localparam [3:0] FETCH = 0, DECODE = 1, MEMWRITE = 5, LUIWB = 8, JALR = 12;
    localparam [31:0] DIR_B = 32'h3EC;
    localparam [31:0] B_FINAL = (B_INICIAL << 1) & 32'hF;

    reg clk = 0;
    reg rst = 1;
    integer ciclos = 0;
    integer instrucciones = 0;
    integer errores = 0;
    integer escrituras_lui = 0;
    reg retorno = 0;
    reg escribio_b = 0;

    // Visores de RAM para el .wcfg. r_mem sigue la direccion configurada.
    wire [7:0] a_mem = dut.u_mem.RAM[248][31:24];
    wire [31:0] r_mem = dut.u_mem.RAM[DIR_R[9:2]];
    wire [31:0] i_mem = dut.u_mem.RAM[250];
    wire [31:0] b_mem = dut.u_mem.RAM[DIR_B[9:2]];

    riscv_top dut (.clk(clk), .rst(rst));

    always #5 clk = ~clk;

    task revisar(input [31:0] obtenido, input [31:0] esperado, input [8*20-1:0] nombre);
        begin
            if (obtenido === esperado)
                $display("[OK]    %0s = 0x%08h", nombre, obtenido);
            else begin
                $display("[ERROR] %0s = 0x%08h, se esperaba 0x%08h",
                         nombre, obtenido, esperado);
                errores = errores + 1;
            end
        end
    endtask

    initial begin
        $timeformat(-9, 0, " ns", 0);
        if (DIR_R >= 1024 || DIR_R[1:0] != 0)
            $fatal(1, "DIR_R debe ser una direccion de palabra alineada dentro de RAM.");

        @(negedge clk);
        rst = 0;

        while (!retorno && ciclos < 1000) begin
            @(posedge clk);
            // El estado y los controles corresponden al ciclo que cierra aqui.
            if (dut.estado == DECODE) begin
                instrucciones = instrucciones + 1;
                $display("  t=%0t  PC=0x%08h  Instr=0x%08h", $time, dut.OldPC, dut.Instr);
            end
            if (!escribio_b && dut.estado == MEMWRITE && dut.Adr == DIR_B) begin
                escribio_b = 1;
                revisar({28'b0, dut.WE}, 32'hF, "WE inicial de b");
                revisar(dut.WD, B_INICIAL, "b inicial");
            end
            if (dut.estado == LUIWB && dut.OldPC == 32'h10) begin
                escrituras_lui = escrituras_lui + 1;
                #1 revisar(dut.u_regs.x[15], 32'h0000_C000, "a5 despues de LUI");
            end else if (dut.estado == JALR && dut.Instr == 32'h0000_8067 &&
                         dut.PCWrite && dut.PCNext == 0) begin
                #1 retorno = dut.estado == FETCH && dut.PC == 0;
            end else begin
                #1;
            end
            ciclos = ciclos + 1;
        end

        if (!retorno)
            $fatal(1, "No retorno a PC=0 en %0d ciclos.", ciclos);
        $display("Programa terminado: %0d instrucciones en %0d ciclos.", instrucciones, ciclos);

        revisar(ciclos, 193, "ciclos");
        revisar(instrucciones, 47, "instrucciones");
        revisar(escrituras_lui, 1, "escrituras LUI");
        revisar({31'b0, escribio_b}, 1, "inicializacion de b");

        dut.u_mem.dump("dump_memoria.txt");
        revisar({24'b0, a_mem}, 32'h62, "a final");
        revisar(r_mem, 32'h0000_C7DF, "r final");
        revisar(i_mem, 2, "i final");
        revisar(b_mem, B_FINAL, "b final");
        revisar(dut.u_regs.x[2], 32'h400, "sp restaurado");
        revisar(dut.u_regs.x[10], 0, "retorno de main");
        revisar(dut.u_regs.x[0], 0, "x0");

        if (errores != 0)
            $fatal(1, "PRUEBA FALLIDA: %0d errores.", errores);
        $display("PRUEBA EXITOSA: el programa corrio correctamente.");
       $finish;
    end
endmodule
