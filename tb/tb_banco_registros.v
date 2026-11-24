`timescale 1ns / 1ps
// ^ Unidad de tiempo 1 ns, precision 1 ps.

//==============================================================================
// Testbench: tb_banco_registros
// Modulo bajo prueba (DUT): banco_registros
//
// OBJETIVO DE LA PRUEBA:
//   1. Despues del reset: x0 = 0, x2 (sp) = 0x400, el resto en 0.
//   2. Escritura sincrona: con WE3 = 1 se escribe en el flanco de subida.
//   3. Sin WE3 no se escribe.
//   4. x0 no se puede escribir: siempre se lee 0.
//   5. Las dos lecturas funcionan al mismo tiempo (combinacionales).
//
// ESTIMULOS (en orden) Y RESULTADOS ESPERADOS:
//   B0. reset; leer los 32 registros uno por uno (A1 = 0..31)
//                                       -> x2 = 0x00000400, todos los demas = 0
//   B1. reset; leer A1 = x2, A2 = x15  -> RD1 = 0x00000400, RD2 = 0x00000000
//   B2. escribir x15 (a5) = 0x0000C7DF con WE3 = 1; leer A1 = x15 y A2 = x15
//                                       -> RD1 = RD2 = 0x0000C7DF (dos lecturas
//                                          del mismo registro a la vez)
//   B3. intentar x14 (a4) = 0x00000001 con WE3 = 0; leer A2 = x14 -> 0x00000000
//   B4. escribir x8 (s0) = 0x00000400; leer A1 = x8, A2 = x15
//                                       -> RD1 = 0x00000400, RD2 = 0x0000C7DF
//   B5. intentar x0 = 0xFFFFFFFF con WE3 = 1; leer A1 = x0 -> 0x00000000
//==============================================================================
module tb_banco_registros;

    reg         clk, rst;         // reloj y reset
    reg  [4:0]  A1, A2, A3;       // numeros de registro (rs1, rs2, rd)
    reg  [31:0] WD3;              // dato a escribir
    reg         WE3;              // permiso de escritura (RegWrite)
    wire [31:0] RD1, RD2;         // datos leidos

    integer errores = 0;
    integer k, e0;                // indice del recorrido B0 y errores previos

    banco_registros #(.SP_INIT(32'h0000_0400)) dut (
        .clk(clk), .rst(rst), .A1(A1), .A2(A2), .A3(A3),
        .WD3(WD3), .WE3(WE3), .RD1(RD1), .RD2(RD2)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    // Compara las dos salidas de lectura
    task revisar(input [8*2-1:0] etiqueta, input [31:0] e1, input [31:0] e2);
        begin
            if (RD1 === e1 && RD2 === e2)
                $display("[OK]    %s  RD1(x%0d) = 0x%08h  RD2(x%0d) = 0x%08h",
                         etiqueta, A1, RD1, A2, RD2);
            else begin
                $display("[ERROR] %s  RD1 = 0x%08h RD2 = 0x%08h | esperado 0x%08h 0x%08h",
                         etiqueta, RD1, RD2, e1, e2);
                errores = errores + 1;
            end
        end
    endtask

    // Prepara una escritura en el flanco de bajada y espera el de subida
    task escribir(input [4:0] reg_dest, input [31:0] dato, input habilitar);
        begin
            @(negedge clk);
            A3 = reg_dest; WD3 = dato; WE3 = habilitar;
            @(posedge clk);                 // aqui se escribe (si WE3 = 1)
            #1 WE3 = 0;                     // quitar el permiso
        end
    endtask

    initial begin
        // B1: reset
        rst = 1; WE3 = 0; A1 = 5'd2; A2 = 5'd15; A3 = 5'd0; WD3 = 32'b0;
        #12 rst = 0;                        // soltar reset

        // B0: recorrer los 32 registros despues del reset
        e0 = errores;
        for (k = 0; k < 32; k = k + 1) begin
            A1 = k; #1;
            if (RD1 !== ((k == 2) ? 32'h0000_0400 : 32'h0000_0000)) begin
                $display("[ERROR] B0  x%0d = 0x%08h despues del reset", k, RD1);
                errores = errores + 1;
            end
        end
        if (errores == e0)
            $display("[OK]    B0  x2 = 0x00000400 y los otros 31 registros en 0");

        A1 = 5'd2;
        #1 revisar("B1", 32'h0000_0400, 32'h0000_0000);

        // B2: escribir a5 (x15)
        escribir(5'd15, 32'h0000_C7DF, 1'b1);
        A1 = 5'd15; #1 revisar("B2", 32'h0000_C7DF, 32'h0000_C7DF);   // A2 sigue en x15

        // B3: intento sin permiso en a4 (x14)
        escribir(5'd14, 32'h0000_0001, 1'b0);
        A2 = 5'd14; #1 revisar("B3", 32'h0000_C7DF, 32'h0000_0000);

        // B4: escribir s0 (x8) y leer dos registros a la vez
        escribir(5'd8, 32'h0000_0400, 1'b1);
        A1 = 5'd8; A2 = 5'd15; #1 revisar("B4", 32'h0000_0400, 32'h0000_C7DF);

        // B5: x0 no se escribe nunca
        escribir(5'd0, 32'hFFFF_FFFF, 1'b1);
        A1 = 5'd0; #1 revisar("B5", 32'h0000_0000, 32'h0000_C7DF);

        if (errores == 0) $display("PRUEBA EXITOSA: todos los casos pasaron.");
        else              $display("PRUEBA FALLIDA: %0d errores.", errores);
        $finish;
    end

endmodule
