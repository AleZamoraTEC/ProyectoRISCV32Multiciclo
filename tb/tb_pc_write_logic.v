`timescale 1ns / 1ps
// ^ Unidad de tiempo 1 ns, precision 1 ps.

//==============================================================================
// Testbench: tb_pc_write_logic
// Modulo bajo prueba (DUT): pc_write_logic
//
// OBJETIVO DE LA PRUEBA:
//   1. PCWrite = 1 siempre que PCUpdate = 1 (Fetch, JAL, JALR).
//   2. En BRANCH (Branch = 1), PCWrite depende de funct3 y las banderas:
//      bne salta si Z = 0; bge salta si N == V. Tambien se prueban beq y blt.
//   3. Sin PCUpdate ni Branch, PCWrite = 0.
//   4. PCNext es Result con el bit 0 en 0 (mascara de jalr).
//
// ESTIMULOS (en orden) Y RESULTADOS ESPERADOS:
//   Caso PCUpd Branch f3   Z N V  Result      PCWrite PCNext       Situacion
//   P1   1     0      000  0 0 0  0x00000004  1       0x00000004   Fetch (PC+4)
//   P2   0     0      000  0 0 0  0x00000099  0       0x00000098   Decode: no escribe
//   P3   0     1      001  1 0 0  0x00000048  0       0x00000048   bne, i = 0: no salta
//   P4   0     1      001  0 0 0  0x00000048  1       0x00000048   bne, i = 1: salta
//   P5   0     1      101  1 0 0  0x00000034  1       0x00000034   bge 1>=1: salta
//   P6   0     1      101  0 1 0  0x00000034  0       0x00000034   bge 1>=2: no salta
//   P7   0     1      101  0 0 1  0x00000034  0       0x00000034   bge con overflow: no salta
//   P8   0     1      000  1 0 0  0x00000020  1       0x00000020   beq iguales: salta
//   P9   0     1      100  0 1 0  0x00000020  1       0x00000020   blt menor: salta
//   P10  1     0      000  0 0 0  0x00000101  1       0x00000100   jalr con destino impar
//==============================================================================
module tb_pc_write_logic;

    reg         PCUpdate, Branch;         // senales de la FSM
    reg  [2:0]  funct3;                   // tipo de salto
    reg         Zero, Negative, Overflow; // banderas de la ALU
    reg  [31:0] Result;                   // nueva direccion
    wire        PCWrite;                  // salida: permiso del PC
    wire [31:0] PCNext;                   // salida: direccion con mascara

    integer errores = 0;

    pc_write_logic dut (.PCUpdate(PCUpdate), .Branch(Branch), .funct3(funct3),
                        .Zero(Zero), .Negative(Negative), .Overflow(Overflow),
                        .Result(Result), .PCWrite(PCWrite), .PCNext(PCNext));

    task probar(input [8*3-1:0] etiqueta, input pu, input br, input [2:0] f3,
                input z, input n, input v, input [31:0] res,
                input pw_esp, input [31:0] next_esp);
        begin
            PCUpdate = pu; Branch = br; funct3 = f3;              // estimulo
            Zero = z; Negative = n; Overflow = v; Result = res;
            #10;                                                  // propagacion
            if (PCWrite === pw_esp && PCNext === next_esp)
                $display("[OK]    %s  PCWrite = %b  PCNext = 0x%08h", etiqueta, PCWrite, PCNext);
            else begin
                $display("[ERROR] %s  PCWrite = %b PCNext = 0x%08h | esperado %b 0x%08h",
                         etiqueta, PCWrite, PCNext, pw_esp, next_esp);
                errores = errores + 1;
            end
        end
    endtask

    initial begin
        //     caso   PU BR f3      Z  N  V  Result        PW  PCNext
        probar("P1",  1, 0, 3'b000, 0, 0, 0, 32'h00000004, 1, 32'h00000004);
        probar("P2",  0, 0, 3'b000, 0, 0, 0, 32'h00000099, 0, 32'h00000098);
        probar("P3",  0, 1, 3'b001, 1, 0, 0, 32'h00000048, 0, 32'h00000048);
        probar("P4",  0, 1, 3'b001, 0, 0, 0, 32'h00000048, 1, 32'h00000048);
        probar("P5",  0, 1, 3'b101, 1, 0, 0, 32'h00000034, 1, 32'h00000034);
        probar("P6",  0, 1, 3'b101, 0, 1, 0, 32'h00000034, 0, 32'h00000034);
        probar("P7",  0, 1, 3'b101, 0, 0, 1, 32'h00000034, 0, 32'h00000034);
        probar("P8",  0, 1, 3'b000, 1, 0, 0, 32'h00000020, 1, 32'h00000020);
        probar("P9",  0, 1, 3'b100, 0, 1, 0, 32'h00000020, 1, 32'h00000020);
        probar("P10", 1, 0, 3'b000, 0, 0, 0, 32'h00000101, 1, 32'h00000100);

        if (errores == 0) $display("PRUEBA EXITOSA: todos los casos pasaron.");
        else              $display("PRUEBA FALLIDA: %0d errores.", errores);
        $finish;
    end

endmodule
