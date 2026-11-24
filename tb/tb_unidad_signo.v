`timescale 1ns / 1ps
// ^ Unidad de tiempo 1 ns, precision 1 ps.

//==============================================================================
// Testbench: tb_unidad_signo
// Modulo bajo prueba (DUT): unidad_signo
//
// OBJETIVO DE LA PRUEBA:
//   Verificar el inmediato de los 5 formatos con instrucciones REALES del
//   programa, incluyendo inmediatos positivos y negativos.
//
// ESTIMULOS (en orden) Y RESULTADOS ESPERADOS:
//   Caso Instr       Instruccion        ImmSrc  ImmExt esperado
//   I1   0xFE010113  addi sp,sp,-32     000(I)  0xFFFFFFE0 (-32)
//   I2   0x7DF78793  addi a5,a5,2015    000(I)  0x000007DF (2015)
//   I3   0x00179793  slli a5,a5,1       000(I)  0x00000001 (shamt = 1)
//   I4   0xFEF42223  sw a5,-28(s0)      001(S)  0xFFFFFFE4 (-28)
//   I5   0x00112E23  sw ra,28(sp)       001(S)  0x0000001C (28)
//   I6   0x00079863  bne a5,zero,+16    010(B)  0x00000010 (+16: 0x38 -> 0x48)
//   I7   0xFCE7D0E3  bge a5,a4,-64      010(B)  0xFFFFFFC0 (-64: 0x74 -> 0x34)
//   I8   0x0000C7B7  lui a5,0xc         011(U)  0x0000C000 (inmediato U desplazado)
//   I9   0x03C0006F  jal zero,+60       100(J)  0x0000003C (+60: 0x30 -> 0x6C)
//   I10  0x01C0006F  jal zero,+28       100(J)  0x0000001C (+28: 0x44 -> 0x60)
//
//   Casos extra del formato U (lui), para probar bits altos y extremos:
//   U1   0x800007B7  lui a5,0x80000     011(U)  0x80000000 (solo bit 31)
//   U2   0xFFFFF7B7  lui a5,0xFFFFF     011(U)  0xFFFFF000 (los 20 bits en 1)
//   UR   64 instrucciones lui con los bits [31:7] aleatorios (semilla fija
//        20261123, repetible).      011(U)  Instr[31:12] seguido de 12 ceros
//        (se calcula como Instr[31:12] * 4096 y se compara).
//==============================================================================
module tb_unidad_signo;

    reg  [31:0] Instr;        // instruccion completa (se conectan los bits [31:7])
    reg  [2:0]  ImmSrc;       // formato
    wire [31:0] ImmExt;       // inmediato extendido (salida)

    integer errores = 0;
    integer semilla = 20261123;
    integer caso_u;
    reg [24:0] campos_u;

    // Solo se conectan los bits [31:7]: el opcode no participa en el inmediato
    unidad_signo dut (.Instr(Instr[31:7]), .ImmSrc(ImmSrc), .ImmExt(ImmExt));

    task probar(input [8*3-1:0] etiqueta, input [31:0] ins, input [2:0] src,
                input [31:0] esperado);
        begin
            Instr = ins; ImmSrc = src;      // estimulo
            #10;                            // propagacion
            if (ImmExt === esperado)
                // %0d con $signed imprime el valor decimal con signo
                $display("[OK]    %s  Instr = 0x%08h  ImmExt = 0x%08h (%0d)",
                         etiqueta, Instr, ImmExt, $signed(ImmExt));
            else begin
                $display("[ERROR] %s  Instr = 0x%08h  ImmExt = 0x%08h, se esperaba 0x%08h",
                         etiqueta, Instr, ImmExt, esperado);
                errores = errores + 1;
            end
        end
    endtask

    initial begin
        //     caso   instruccion   ImmSrc  esperado
        probar("I1",  32'hFE010113, 3'b000, 32'hFFFFFFE0);
        probar("I2",  32'h7DF78793, 3'b000, 32'h000007DF);
        probar("I3",  32'h00179793, 3'b000, 32'h00000001);
        probar("I4",  32'hFEF42223, 3'b001, 32'hFFFFFFE4);
        probar("I5",  32'h00112E23, 3'b001, 32'h0000001C);
        probar("I6",  32'h00079863, 3'b010, 32'h00000010);
        probar("I7",  32'hFCE7D0E3, 3'b010, 32'hFFFFFFC0);
        probar("I8",  32'h0000C7B7, 3'b011, 32'h0000C000);
        probar("I9",  32'h03C0006F, 3'b100, 32'h0000003C);
        probar("I10", 32'h01C0006F, 3'b100, 32'h0000001C);

        // Formato U: extremos y campos superiores/destinos pseudoaleatorios.
        probar("U1", 32'h800007B7, 3'b011, 32'h80000000);
        probar("U2", 32'hFFFFF7B7, 3'b011, 32'hFFFFF000);
        $display("Semilla inicial para los casos U: %0d", semilla);
        for (caso_u = 0; caso_u < 64; caso_u = caso_u + 1) begin
            campos_u = $random(semilla);
            probar("UR", {campos_u, 7'b0110111}, 3'b011,
                   campos_u[24:5] * 32'd4096);
        end

        if (errores == 0) $display("PRUEBA EXITOSA: todos los casos pasaron.");
        else              $display("PRUEBA FALLIDA: %0d errores.", errores);
        $finish;
    end

endmodule
