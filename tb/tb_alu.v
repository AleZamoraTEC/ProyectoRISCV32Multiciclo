`timescale 1ns / 1ps
//==============================================================================
// Testbench: tb_alu
// Modulo bajo prueba (DUT): alu
// Proyecto: Microarquitectura multiciclo RV32I - MT-7003, II Semestre 2026
//
// OBJETIVO DE LA PRUEBA:
//   Verificar cada operacion de la ALU con los MISMOS valores que aparecen al
//   ejecutar el programa del proyecto, y verificar las banderas Zero,
//   Negative y Overflow que usan los saltos bne y bge.
//
// ESTIMULOS (en orden) Y RESULTADOS ESPERADOS:
//   Caso  Operacion  SrcA        SrcB        ALUResult   Z N V  Origen en el programa
//   T1    ADD        0x00000000  0x00000004  0x00000004  0 0 0  Fetch: PC + 4
//   T2    ADD        0x00000400  0xFFFFFFE0  0x000003E0  0 0 0  addi sp,sp,-32
//   T3    ADD        0x0000C000  0x000007DF  0x0000C7DF  0 0 0  addi a5,a5,2015 (r)
//   T4    SLL        0x00000021  0x00000001  0x00000042  0 0 0  slli: 33 << 1 = 66
//   T5    AND        0x00000042  0x0000000F  0x00000002  0 0 0  andi: 66 & 0xF = 2
//   T6    SUB        0x00000000  0x00000000  0x00000000  1 0 0  bne con i = 0 (no salta)
//   T7    SUB        0x00000001  0x00000000  0x00000001  0 0 0  bne con i = 1 (salta)
//   T8    SUB        0x00000001  0x00000001  0x00000000  1 0 0  bge 1 >= 1 (salta)
//   T9    SUB        0x00000001  0x00000002  0xFFFFFFFF  0 1 0  bge 1 >= 2 (no salta)
//   T10   SUB        0x80000000  0x00000001  0x7FFFFFFF  0 0 1  desbordamiento en resta
//   T11   ADD        0x7FFFFFFF  0x00000001  0x80000000  0 1 1  desbordamiento en suma
//   T12   OR         0x000000F0  0x0000000F  0x000000FF  0 0 0  operacion OR
//   T13   SLT        0xFFFFFFFE  0x00000001  0x00000001  0 0 0  -2 < 1 con signo
//
//   Para bge: el salto se toma si (Negative == Overflow) despues de A - B.
//   T8: N=0, V=0 -> iguales -> salta.  T9: N=1, V=0 -> distintos -> no salta.
//   T10: A = -2147483648, B = 1. A < B, y aunque N=0 hay V=1 -> no salta (correcto).
//==============================================================================
module tb_alu;

    // Entradas de la ALU: reg porque el testbench les asigna valores.
    reg  [31:0] SrcA;
    reg  [31:0] SrcB;
    reg  [3:0]  ALUControl;

    // Salidas de la ALU: wire porque solo se observan.
    wire [31:0] ALUResult;
    wire        Zero, Negative, Overflow;

    integer errores = 0;   // contador de casos fallidos

    // Mismos codigos que en alu.v
    localparam [3:0] OP_AND = 4'b0000, OP_OR  = 4'b0001, OP_ADD = 4'b0010,
                     OP_SUB = 4'b0110, OP_SLT = 4'b0111, OP_SLL = 4'b1111;

    // Instancia del modulo bajo prueba, conectado por nombre
    alu dut (
        .SrcA      (SrcA),
        .SrcB      (SrcB),
        .ALUControl(ALUControl),
        .ALUResult (ALUResult),
        .Zero      (Zero),
        .Negative  (Negative),
        .Overflow  (Overflow)
    );

    // Tarea que aplica un caso completo:
    //   1. pone las entradas,
    //   2. espera 10 ns (la ALU es combinacional; solo hay que dar tiempo a
    //      que el simulador propague los cambios, no hay reloj),
    //   3. compara el resultado y las tres banderas con lo esperado.
    task probar(input [8*3-1:0] etiqueta,   // nombre del caso (hasta 3 letras)
                input [3:0]     op,         // operacion
                input [31:0]    a, b,       // operandos
                input [31:0]    res_esp,    // resultado esperado
                input           z_esp, n_esp, v_esp);  // banderas esperadas
        begin
            SrcA = a; SrcB = b; ALUControl = op;
            #10;
            if (ALUResult === res_esp && Zero === z_esp &&
                Negative === n_esp && Overflow === v_esp)
                $display("[OK]    %s  Res = 0x%08h  Z=%b N=%b V=%b",
                         etiqueta, ALUResult, Zero, Negative, Overflow);
            else begin
                $display("[ERROR] %s  Res = 0x%08h Z=%b N=%b V=%b | esperado 0x%08h Z=%b N=%b V=%b",
                         etiqueta, ALUResult, Zero, Negative, Overflow,
                         res_esp, z_esp, n_esp, v_esp);
                errores = errores + 1;
            end
        end
    endtask

    initial begin
        //      caso   op      SrcA          SrcB          esperado      Z  N  V
        probar("T1",  OP_ADD, 32'h00000000, 32'h00000004, 32'h00000004, 0, 0, 0);
        probar("T2",  OP_ADD, 32'h00000400, 32'hFFFFFFE0, 32'h000003E0, 0, 0, 0);
        probar("T3",  OP_ADD, 32'h0000C000, 32'h000007DF, 32'h0000C7DF, 0, 0, 0);
        probar("T4",  OP_SLL, 32'h00000021, 32'h00000001, 32'h00000042, 0, 0, 0);
        probar("T5",  OP_AND, 32'h00000042, 32'h0000000F, 32'h00000002, 0, 0, 0);
        probar("T6",  OP_SUB, 32'h00000000, 32'h00000000, 32'h00000000, 1, 0, 0);
        probar("T7",  OP_SUB, 32'h00000001, 32'h00000000, 32'h00000001, 0, 0, 0);
        probar("T8",  OP_SUB, 32'h00000001, 32'h00000001, 32'h00000000, 1, 0, 0);
        probar("T9",  OP_SUB, 32'h00000001, 32'h00000002, 32'hFFFFFFFF, 0, 1, 0);
        probar("T10", OP_SUB, 32'h80000000, 32'h00000001, 32'h7FFFFFFF, 0, 0, 1);
        probar("T11", OP_ADD, 32'h7FFFFFFF, 32'h00000001, 32'h80000000, 0, 1, 1);
        probar("T12", OP_OR,  32'h000000F0, 32'h0000000F, 32'h000000FF, 0, 0, 0);
        probar("T13", OP_SLT, 32'hFFFFFFFE, 32'h00000001, 32'h00000001, 0, 0, 0);

        if (errores == 0) $display("PRUEBA EXITOSA: todos los casos pasaron.");
        else              $display("PRUEBA FALLIDA: %0d errores.", errores);
        $finish;
    end

endmodule
