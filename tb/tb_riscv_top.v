`timescale 1ns / 1ps
// ^ Unidad de tiempo 1 ns, precision 1 ps.

//==============================================================================
// Testbench: tb_riscv_top
// Modulo bajo prueba (DUT): riscv_top (procesador completo)
//
// REQUISITO: programa.mem agregado como simulation source en Vivado.
//
// OBJETIVO DE LA PRUEBA:
//   Ejecutar el programa del proyecto (pm_ev_grupos_6_estudiantes.c, 36
//   instrucciones) en el procesador completo, que solo tiene clk y rst, y
//   verificar el estado final de la memoria de datos con un dump.
//
// ESTIMULOS:
//   1. rst = 1 durante 1 ciclo y luego rst = 0.
//   2. Reloj libre hasta que el programa termina. Fin = el ret (jalr) devuelve
//      el PC a 0x00 (ra = 0) y la FSM vuelve a FETCH. Limite de seguridad:
//      1000 ciclos.
//   3. Se escribe el dump de la memoria en dump_memoria.txt.
//
// RESULTADOS ESPERADOS (sp inicial = 0x400, pila de main en 0x3E0-0x3FF):
//   Direccion  Valor        Variable
//   0x3E0      0x62000000   a = 'b' (byte en 0x3E3)
//   0x3E4      0x0000C7DF   r
//   0x3E8      0x00000002   i
//   0x3EC      0x00000002   b
//   Y en los registros al terminar: sp = 0x400 (se libero la pila).
//==============================================================================
module tb_riscv_top;

    reg clk;                    // las DOS unicas entradas del procesador
    reg rst;

    integer ciclos = 0;         // cuenta ciclos de reloj
    integer instrucciones = 0;  // cuenta instrucciones (veces que pasa por DECODE)
    integer errores = 0;
    integer escrituras_lui = 0;

    // Procesador completo: solo clk y rst
    riscv_top #(.MEM_FILE("programa.mem")) dut (.clk(clk), .rst(rst));

    initial clk = 0;
    always #5 clk = ~clk;       // reloj de 10 ns

    //--------------------------------------------------------------------------
    // Monitor: imprime cada instruccion cuando llega a DECODE.
    // dut.u_control.estado es un acceso JERARQUICO: entra al modulo dut, luego
    // a la instancia u_control, y lee su senal estado. Solo es valido en
    // simulacion; sirve para observar sin agregar puertos al procesador.
    //--------------------------------------------------------------------------
    always @(posedge clk) begin
        if (!rst && dut.u_control.estado == 4'd1)      // estado DECODE
            $display("  t=%0t ns  PC=0x%02h  Instr=0x%08h", $time,
                     dut.OldPC[7:0], dut.Instr);
    end

    // LUIWB escribe a5 en el flanco, antes de que el ADDI siguiente lo modifique.
    always @(posedge clk) begin
        if (!rst && dut.u_control.estado == 4'd8 && dut.OldPC == 32'h10) begin
            #1;
            escrituras_lui = escrituras_lui + 1;
            if (dut.u_regs.x[15] === 32'h0000_C000)
                $display("[OK]    LUI escribio a5 = 0x0000C000");
            else begin
                $display("[ERROR] LUI escribio a5 = 0x%08h", dut.u_regs.x[15]);
                errores = errores + 1;
            end
        end
    end

    // Revisa una palabra de memoria leyendo el arreglo interno del DUT
    task revisar(input [31:0] dir, input [31:0] esperado, input [8*12-1:0] nombre);
        begin
            if (dut.u_mem.RAM[dir[9:2]] === esperado)
                $display("[OK]    Mem[0x%03h] = 0x%08h  (%s)", dir[9:0],
                         dut.u_mem.RAM[dir[9:2]], nombre);
            else begin
                $display("[ERROR] Mem[0x%03h] = 0x%08h, se esperaba 0x%08h  (%s)",
                         dir[9:0], dut.u_mem.RAM[dir[9:2]], esperado, nombre);
                errores = errores + 1;
            end
        end
    endtask

    initial begin
        // 1. Reset
        rst = 1;
        @(posedge clk); #1 rst = 0;

        // 2. Correr hasta que el ret vuelva a 0x00 (despues de haber arrancado)
        while (!(ciclos > 5 && dut.u_control.estado == 4'd0 && dut.PC == 32'h0)
               && ciclos < 1000) begin
            @(posedge clk); #1;
            ciclos = ciclos + 1;
            if (dut.u_control.estado == 4'd1) instrucciones = instrucciones + 1;
        end
        $display("Programa terminado: %0d instrucciones (incluido el ret) en %0d ciclos.",
                 instrucciones, ciclos);

        if (instrucciones != 47 || ciclos != 193 || escrituras_lui != 1) begin
            $display("[ERROR] Se esperaban 47 instrucciones, 193 ciclos y un LUI.");
            errores = errores + 1;
        end

        // 3. Dump de memoria a archivo
        dut.u_mem.dump("dump_memoria.txt");
        $display("Dump escrito en dump_memoria.txt");

        // 4. Verificacion de las variables
        revisar(32'h3E0, 32'h6200_0000, "a = 'b'");
        revisar(32'h3E4, 32'h0000_C7DF, "r");
        revisar(32'h3E8, 32'h0000_0002, "i");
        revisar(32'h3EC, 32'h0000_0002, "b");
        if (dut.u_regs.x[2] === 32'h0000_0400)
            $display("[OK]    sp = 0x%08h (pila liberada)", dut.u_regs.x[2]);
        else begin
            $display("[ERROR] sp = 0x%08h, se esperaba 0x00000400", dut.u_regs.x[2]);
            errores = errores + 1;
        end

        if (errores == 0) $display("PRUEBA EXITOSA: el programa corrio correctamente.");
        else              $display("PRUEBA FALLIDA: %0d errores.", errores);
        $finish;
    end

endmodule
