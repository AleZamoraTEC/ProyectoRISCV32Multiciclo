`timescale 1ns / 1ps
// ^ Unidad de tiempo 1 ns, precision 1 ps.

//==============================================================================
// Testbench: tb_prep_store
// Modulo bajo prueba (DUT): prep_store
//
// OBJETIVO DE LA PRUEBA:
//   Verificar que se arma correctamente el dato y los permisos por byte:
//     - sw: palabra completa, WE = 1111.
//     - sb: el byte bajo de rs2 se coloca en la posicion Adr[1:0] y solo ese
//       byte se habilita.
//     - Sin MemWrite, WE = 0000 en ambos casos.
//
// ESTIMULOS (en orden) Y RESULTADOS ESPERADOS:
//   Caso funct3 Adr MemW WriteData    WD esperado   WE esperado  Origen
//   S1   010    00  1    0x0000C7DF   0x0000C7DF    1111         sw a5,-28(s0) (r)
//   S2   000    11  1    0x00000063   0x63000000    1000         sb a5,-29(s0) (a='c')
//   S3   000    00  1    0x12345662   0x00000062    0001         sb en byte 0
//   S4   000    01  1    0x12345662   0x00006200    0010         sb en byte 1
//   S5   000    10  1    0x12345662   0x00620000    0100         sb en byte 2
//   S6   010    00  0    0x0000C7DF   0x0000C7DF    0000         sw sin permiso
//   S7   000    11  0    0x00000063   0x63000000    0000         sb sin permiso
//==============================================================================
module tb_prep_store;

    reg  [31:0] WriteData;    // dato de rs2
    reg  [1:0]  Adr;          // bits bajos de la direccion
    reg  [2:0]  funct3;       // 010 = sw, 000 = sb
    reg         MemWrite;     // permiso global
    wire [31:0] WD;           // dato acomodado (salida)
    wire [3:0]  WE;           // permisos por byte (salida)

    integer errores = 0;

    prep_store dut (.WriteData(WriteData), .Adr(Adr), .funct3(funct3),
                    .MemWrite(MemWrite), .WD(WD), .WE(WE));

    // Aplica un caso y compara ambas salidas
    task probar(input [8*2-1:0] etiqueta, input [2:0] f3, input [1:0] a,
                input mw, input [31:0] dato, input [31:0] wd_esp, input [3:0] we_esp);
        begin
            funct3 = f3; Adr = a; MemWrite = mw; WriteData = dato;   // estimulo
            #10;                                                     // propagacion
            if (WD === wd_esp && WE === we_esp)
                $display("[OK]    %s  WD = 0x%08h  WE = %b", etiqueta, WD, WE);
            else begin
                $display("[ERROR] %s  WD = 0x%08h WE = %b | esperado 0x%08h %b",
                         etiqueta, WD, WE, wd_esp, we_esp);
                errores = errores + 1;
            end
        end
    endtask

    initial begin
        //     caso  f3      Adr    MemW dato          WD esperado   WE esperado
        probar("S1", 3'b010, 2'b00, 1,   32'h0000C7DF, 32'h0000C7DF, 4'b1111);
        probar("S2", 3'b000, 2'b11, 1,   32'h00000063, 32'h63000000, 4'b1000);
        probar("S3", 3'b000, 2'b00, 1,   32'h12345662, 32'h00000062, 4'b0001);
        probar("S4", 3'b000, 2'b01, 1,   32'h12345662, 32'h00006200, 4'b0010);
        probar("S5", 3'b000, 2'b10, 1,   32'h12345662, 32'h00620000, 4'b0100);
        probar("S6", 3'b010, 2'b00, 0,   32'h0000C7DF, 32'h0000C7DF, 4'b0000);
        probar("S7", 3'b000, 2'b11, 0,   32'h00000063, 32'h63000000, 4'b0000);

        if (errores == 0) $display("PRUEBA EXITOSA: todos los casos pasaron.");
        else              $display("PRUEBA FALLIDA: %0d errores.", errores);
        $finish;
    end

endmodule
