`timescale 1ns / 1ps
// ^ Unidad de tiempo 1 ns, precision 1 ps.

//==============================================================================
// Testbench: tb_mux4
// Modulo bajo prueba (DUT): mux4
//
// OBJETIVO DE LA PRUEBA:
//   Verificar que el multiplexor de 4 entradas entrega la entrada indicada por
//   s[1:0]. Se usan las entradas del mux ALUSrcB del procesador:
//     d0 = WriteData (0x00000021), d1 = ImmExt (0xFFFFFFE4 = -28),
//     d2 = 4,                       d3 = 0.
//
// ESTIMULOS (en orden) Y RESULTADOS ESPERADOS:
//   X1. s = 00 -> y = 0x00000021  (WriteData: execute R / saltos B)
//   X2. s = 01 -> y = 0xFFFFFFE4  (ImmExt: MemAdr, Execute I)
//   X3. s = 10 -> y = 0x00000004  (constante 4: Fetch)
//   X4. s = 11 -> y = 0x00000000  (constante 0: Execute IJ)
//==============================================================================
module tb_mux4;

    reg  [31:0] d0, d1, d2, d3;   // las cuatro entradas
    reg  [1:0]  s;                // selector de 2 bits
    wire [31:0] y;                // salida

    integer errores = 0;

    mux4 #(32) dut (.d0(d0), .d1(d1), .d2(d2), .d3(d3), .s(s), .y(y));

    // Cambia solo el selector, espera y compara
    task probar(input [8*2-1:0] etiqueta, input [1:0] sel, input [31:0] esperado);
        begin
            s = sel;                       // aplicar selector
            #10;                           // esperar propagacion
            if (y === esperado)
                $display("[OK]    %s  s=%b  y = 0x%08h", etiqueta, s, y);
            else begin
                $display("[ERROR] %s  s=%b  y = 0x%08h, se esperaba 0x%08h",
                         etiqueta, s, y, esperado);
                errores = errores + 1;
            end
        end
    endtask

    initial begin
        // Entradas fijas durante toda la prueba
        d0 = 32'h0000_0021;                // WriteData
        d1 = 32'hFFFF_FFE4;                // ImmExt (-28)
        d2 = 32'h0000_0004;                // constante 4
        d3 = 32'h0000_0000;                // constante 0

        probar("X1", 2'b00, 32'h0000_0021);
        probar("X2", 2'b01, 32'hFFFF_FFE4);
        probar("X3", 2'b10, 32'h0000_0004);
        probar("X4", 2'b11, 32'h0000_0000);

        if (errores == 0) $display("PRUEBA EXITOSA: todos los casos pasaron.");
        else              $display("PRUEBA FALLIDA: %0d errores.", errores);
        $finish;
    end

endmodule
