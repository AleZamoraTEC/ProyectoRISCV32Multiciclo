`timescale 1ns / 1ps
// ^ Unidad de tiempo 1 ns, precision 1 ps.

//==============================================================================
// Testbench: tb_decodificador
// Modulo bajo prueba (DUT): decodificador
//
// OBJETIVO DE LA PRUEBA:
//   Verificar que los campos de la instruccion se separan correctamente y que
//   ImmSrc corresponde al formato de cada opcode. Se usa una instruccion real
//   del programa por cada formato.
//
// ESTIMULOS (en orden) Y RESULTADOS ESPERADOS:
//   Caso Instr       Instruccion       opcode   rd rs1 rs2 f3  f7b5 ImmSrc
//   D1   0xFE010113  addi sp,sp,-32    0010011  2  2   -   000 1    000 (I)
//   D2   0xFE842783  lw a5,-24(s0)     0000011  15 8   -   010 1    000 (I)
//   D3   0xFEF401A3  sb a5,-29(s0)     0100011  -  8   15  000 1    001 (S)
//   D4   0xFCE7D0E3  bge a5,a4,...     1100011  -  15  14  101 1    010 (B)
//   D5   0x0000C7B7  lui a5,0xc        0110111  15 -   -   -   0    011 (U)
//   D6   0x03C0006F  jal zero,...      1101111  0  -   -   -   0    100 (J)
//   D7   0x00008067  jalr zero,0(ra)   1100111  0  1   0   000 0    000 (I)
//   ("-" = el campo no tiene significado en ese formato; no se revisa)
//   Nota D1: f7b5 = 1 en una addi. Por eso el decodificador ALU no debe usarlo
//   para decidir SUB en instrucciones tipo I.
//==============================================================================
module tb_decodificador;

    reg  [31:0] Instr;                       // instruccion de entrada
    wire [6:0]  opcode;                      // salidas del decodificador
    wire [4:0]  rd, rs1, rs2;
    wire [2:0]  funct3, ImmSrc;
    wire        funct7b5;

    integer errores = 0;

    decodificador dut (.Instr(Instr), .opcode(opcode), .rd(rd), .funct3(funct3),
                       .rs1(rs1), .rs2(rs2), .funct7b5(funct7b5), .ImmSrc(ImmSrc));

    // Compara opcode, rd, rs1, rs2, funct3, funct7b5 e ImmSrc.
    // Los campos que no aplican se pasan con el valor que realmente tiene la
    // instruccion en esos bits, para revisar que la extraccion sea correcta.
    task probar(input [8*2-1:0] etiqueta, input [31:0] ins,
                input [6:0] op, input [4:0] e_rd, input [4:0] e_rs1, input [4:0] e_rs2,
                input [2:0] e_f3, input e_f7, input [2:0] e_imm);
        begin
            Instr = ins; #10;                                 // estimulo y propagacion
            if (opcode === op && rd === e_rd && rs1 === e_rs1 && rs2 === e_rs2 &&
                funct3 === e_f3 && funct7b5 === e_f7 && ImmSrc === e_imm)
                $display("[OK]    %s  op=%b rd=%0d rs1=%0d rs2=%0d f3=%b f7b5=%b ImmSrc=%b",
                         etiqueta, opcode, rd, rs1, rs2, funct3, funct7b5, ImmSrc);
            else begin
                $display("[ERROR] %s  op=%b rd=%0d rs1=%0d rs2=%0d f3=%b f7b5=%b ImmSrc=%b",
                         etiqueta, opcode, rd, rs1, rs2, funct3, funct7b5, ImmSrc);
                errores = errores + 1;
            end
        end
    endtask

    initial begin
        //     caso  instruccion   opcode       rd  rs1 rs2 f3      f7 ImmSrc
        probar("D1", 32'hFE010113, 7'b0010011,  2,  2,  0, 3'b000, 1, 3'b000);
        probar("D2", 32'hFE842783, 7'b0000011, 15,  8,  8, 3'b010, 1, 3'b000);
        probar("D3", 32'hFEF401A3, 7'b0100011,  3,  8, 15, 3'b000, 1, 3'b001);
        probar("D4", 32'hFCE7D0E3, 7'b1100011,  1, 15, 14, 3'b101, 1, 3'b010);
        probar("D5", 32'h0000C7B7, 7'b0110111, 15,  1,  0, 3'b100, 0, 3'b011);
        probar("D6", 32'h03C0006F, 7'b1101111,  0,  0, 28, 3'b000, 0, 3'b100);
        probar("D7", 32'h00008067, 7'b1100111,  0,  1,  0, 3'b000, 0, 3'b000);

        if (errores == 0) $display("PRUEBA EXITOSA: todos los casos pasaron.");
        else              $display("PRUEBA FALLIDA: %0d errores.", errores);
        $finish;
    end

endmodule
