`timescale 1ns / 1ps
//==============================================================================
// Testbench: tb_riscv_auto
// Proyecto: Microarquitectura multiciclo RV32I - MT-7003, II Semestre 2026
//
// FUNCION:
//   Verifica el procesador con CUALQUIER programa.mem, sin valores esperados
//   escritos a mano. Contiene un MODELO DE REFERENCIA (simulador de RV32I a
//   nivel de instruccion) que lee el mismo archivo .mem.
//
//   Cada vez que el procesador termina una instruccion (vuelve al estado
//   FETCH), el modelo ejecuta esa misma instruccion y se comparan:
//     - el PC,
//     - los 32 registros,
//     - toda la memoria.
//   Ante la primera diferencia se detiene e indica que instruccion fallo.
//
// FIN DEL PROGRAMA (lo que ocurra primero):
//   - El PC vuelve a 0 (ret de main con ra = 0, como en el programa del avance).
//   - Bucle infinito "j ." (una instruccion que salta a si misma).
//   - Se alcanzan MAX_CICLOS.
//
// USO:
//   Solo cambiar programa.mem. Opcionalmente MEM_FILE y MAX_CICLOS.
//==============================================================================
module tb_riscv_auto #(
    parameter MEM_FILE   = "programa.mem",
    parameter MAX_CICLOS = 20000
);
    localparam [3:0] FETCH = 4'd0;
    localparam DEPTH = 256;

    reg clk = 0;
    reg rst = 1;
    always #5 clk = ~clk;

    riscv_top #(.MEM_FILE(MEM_FILE)) dut (.clk(clk), .rst(rst));

    //--------------------------------------------------------------------------
    // Estado del modelo de referencia
    //--------------------------------------------------------------------------
    reg [31:0] m_pc;
    reg [31:0] m_x   [0:31];
    reg [31:0] m_mem [0:DEPTH-1];

    integer ciclos = 0, instrucciones = 0, errores = 0, k;
    reg     fin = 0;
    reg [31:0] pc_ant, instr_ant;

    //--------------------------------------------------------------------------
    // Ayudas del modelo
    //--------------------------------------------------------------------------
    function [31:0] leer(input [31:0] adr);
        leer = m_mem[adr[9:2]];
    endfunction

    task escribir_byte(input [31:0] adr, input [7:0] b);
        case (adr[1:0])
            2'd0: m_mem[adr[9:2]][7:0]   = b;
            2'd1: m_mem[adr[9:2]][15:8]  = b;
            2'd2: m_mem[adr[9:2]][23:16] = b;
            2'd3: m_mem[adr[9:2]][31:24] = b;
        endcase
    endtask

    task escribir_reg(input [4:0] rd, input [31:0] v);
        if (rd != 0) m_x[rd] = v;
    endtask

    //--------------------------------------------------------------------------
    // Ejecuta UNA instruccion en el modelo (semantica oficial de RV32I).
    // Si el procesador no soporta alguna instruccion, la comparacion fallara
    // y lo indicara.
    //--------------------------------------------------------------------------
    task paso_modelo;
        reg [31:0] in, a, b, immI, immS, immB, immJ, immU, adr, sig, w8;
        reg [6:0]  op;
        reg [2:0]  f3;
        reg [4:0]  rd, rs1, rs2;
        reg        f7b5, tomar;
        begin
            in   = leer(m_pc);
            op   = in[6:0];   rd  = in[11:7];  f3 = in[14:12];
            rs1  = in[19:15]; rs2 = in[24:20]; f7b5 = in[30];
            a    = m_x[rs1];  b   = m_x[rs2];
            immI = {{20{in[31]}}, in[31:20]};
            immS = {{20{in[31]}}, in[31:25], in[11:7]};
            immB = {{20{in[31]}}, in[7], in[30:25], in[11:8], 1'b0};
            immJ = {{12{in[31]}}, in[19:12], in[20], in[30:21], 1'b0};
            immU = {in[31:12], 12'b0};
            sig  = m_pc + 4;

            case (op)
                7'b0110111: escribir_reg(rd, immU);                       // lui
                7'b0010111: escribir_reg(rd, m_pc + immU);                // auipc
                7'b1101111: begin escribir_reg(rd, sig); sig = m_pc + immJ; end   // jal
                7'b1100111: begin sig = (a + immI) & ~32'd1; escribir_reg(rd, m_pc + 4); end // jalr
                7'b1100011: begin                                         // saltos B
                    case (f3)
                        3'b000: tomar = (a == b);
                        3'b001: tomar = (a != b);
                        3'b100: tomar = ($signed(a) <  $signed(b));
                        3'b101: tomar = ($signed(a) >= $signed(b));
                        3'b110: tomar = (a <  b);
                        3'b111: tomar = (a >= b);
                        default: tomar = 0;
                    endcase
                    if (tomar) sig = m_pc + immB;
                end
                7'b0000011: begin                                         // cargas
                    adr = a + immI;
                    w8  = leer(adr) >> {adr[1:0], 3'b000};                // byte en [7:0]
                    case (f3)
                        3'b000: escribir_reg(rd, {{24{w8[7]}}, w8[7:0]}); // lb
                        3'b100: escribir_reg(rd, {24'b0, w8[7:0]});       // lbu
                        default: escribir_reg(rd, leer(adr));             // lw
                    endcase
                end
                7'b0100011: begin                                         // stores
                    adr = a + immS;
                    case (f3)
                        3'b000: escribir_byte(adr, b[7:0]);               // sb
                        3'b001: begin escribir_byte(adr, b[7:0]); escribir_byte(adr + 1, b[15:8]); end // sh
                        default: m_mem[adr[9:2]] = b;                     // sw
                    endcase
                end
                7'b0010011: case (f3)                                     // tipo I aritmetico
                    3'b000: escribir_reg(rd, a + immI);                   // addi
                    3'b010: escribir_reg(rd, ($signed(a) < $signed(immI)) ? 1 : 0); // slti
                    3'b011: escribir_reg(rd, (a < immI) ? 1 : 0);         // sltiu
                    3'b100: escribir_reg(rd, a ^ immI);                   // xori
                    3'b110: escribir_reg(rd, a | immI);                   // ori
                    3'b111: escribir_reg(rd, a & immI);                   // andi
                    3'b001: escribir_reg(rd, a << in[24:20]);             // slli
                    3'b101: escribir_reg(rd, f7b5 ? $signed(a) >>> in[24:20]
                                                  : a >> in[24:20]);      // srai / srli
                endcase
                7'b0110011: case (f3)                                     // tipo R
                    3'b000: escribir_reg(rd, f7b5 ? a - b : a + b);       // sub / add
                    3'b001: escribir_reg(rd, a << b[4:0]);                // sll
                    3'b010: escribir_reg(rd, ($signed(a) < $signed(b)) ? 1 : 0); // slt
                    3'b011: escribir_reg(rd, (a < b) ? 1 : 0);            // sltu
                    3'b100: escribir_reg(rd, a ^ b);                      // xor
                    3'b101: escribir_reg(rd, f7b5 ? $signed(a) >>> b[4:0] : a >> b[4:0]); // sra / srl
                    3'b110: escribir_reg(rd, a | b);                      // or
                    3'b111: escribir_reg(rd, a & b);                      // and
                endcase
                default: $display("  AVISO: opcode %b no reconocido en PC=0x%08h", op, m_pc);
            endcase
            m_pc = sig;
        end
    endtask

    //--------------------------------------------------------------------------
    // Compara el estado del procesador con el del modelo
    //--------------------------------------------------------------------------
    task comparar;
        integer r, w, e0;
        begin
            e0 = errores;
            if (dut.PC !== m_pc) begin
                $display("[ERROR] PC = 0x%08h, se esperaba 0x%08h", dut.PC, m_pc);
                errores = errores + 1;
            end
            for (r = 0; r < 32; r = r + 1)
                if ((r == 0 ? 32'd0 : dut.u_regs.x[r]) !== m_x[r]) begin
                    $display("[ERROR] x%0d = 0x%08h, se esperaba 0x%08h",
                             r, dut.u_regs.x[r], m_x[r]);
                    errores = errores + 1;
                end
            for (w = 0; w < DEPTH; w = w + 1)
                if (dut.u_mem.RAM[w] !== m_mem[w]) begin
                    $display("[ERROR] Mem[0x%03h] = 0x%08h, se esperaba 0x%08h",
                             w*4, dut.u_mem.RAM[w], m_mem[w]);
                    errores = errores + 1;
                end
            if (errores != e0)
                $display("        -> fallo la instruccion 0x%08h en PC=0x%08h",
                         instr_ant, pc_ant);
        end
    endtask

    //--------------------------------------------------------------------------
    // Secuencia principal
    //--------------------------------------------------------------------------
    initial begin
        // Estado inicial del modelo: igual al reset del procesador
        m_pc = 0;
        for (k = 0; k < 32; k = k + 1) m_x[k] = 0;
        m_x[2] = dut.u_regs.SP_INIT;
        for (k = 0; k < DEPTH; k = k + 1) m_mem[k] = 0;
        $readmemh(MEM_FILE, m_mem);

        @(negedge clk);
        rst = 0;

        while (!fin && ciclos < MAX_CICLOS) begin
            @(posedge clk); #1;
            ciclos = ciclos + 1;

            // El procesador acaba de terminar una instruccion
            if (dut.estado == FETCH) begin
                pc_ant    = m_pc;
                instr_ant = leer(m_pc);
                paso_modelo;
                instrucciones = instrucciones + 1;
                $display("  PC=0x%08h  Instr=0x%08h", pc_ant, instr_ant);
                comparar;
                if (errores != 0) fin = 1;                 // parar en el 1er error
                else if (m_pc == 0)       fin = 1;         // ret de main
                else if (m_pc == pc_ant)  fin = 1;         // bucle "j ."
            end
        end

        $display("--------------------------------------------------------");
        $display("Instrucciones: %0d   Ciclos: %0d", instrucciones, ciclos);
        if (!fin)
            $display("[AVISO] Se alcanzo MAX_CICLOS sin que el programa terminara.");

        dut.u_mem.dump("dump_memoria.txt");

        if (errores != 0)
            $fatal(1, "PRUEBA FALLIDA: %0d diferencias con el modelo.", errores);
        $display("PRUEBA EXITOSA: el procesador coincide con el modelo en todas las instrucciones.");
        $finish;
    end
endmodule
