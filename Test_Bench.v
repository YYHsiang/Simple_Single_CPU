// Simulation MARCOS
`timescale 1ns/1ps
`define CYCLE_TIME 10
`define END_COUNT  100
`define SDFFILE "./ALU_syn.sdf"
`ifdef TB1
    `define INSTR_PATH "CA_LAB2_test.txt"
`endif
`ifdef TB2
    `define INSTR_PATH "../asmcode/fibo_iteration.bin"
`endif
//*****************************************************************************
module TestBench;
//*****************************************************************************
    ///////////////////////////////////////////////////////////////////////////
    // Parameters Declaration
    ///////////////////////////////////////////////////////////////////////////
    // Operation codes
    localparam OPC_OP     = 5'b01100; // Operation
    localparam OPC_OP_IMM = 5'b00100; // Operation Immediate
    localparam OPC_LOAD   = 5'b00000; // Load
    localparam OPC_STORE  = 5'b01000; // Store
    localparam OPC_BRANCH = 5'b11000; // Branch
    localparam OPC_JAL    = 5'b11011; // Jal
    localparam OPC_JALR   = 5'b11001; // Jalr
    localparam OPC_LUI    = 5'b01101; // Lui
    localparam OPC_AUIPC  = 5'b00101; // Auipc

    // Function codes
    // Arithmetic Operation
    localparam F3_ADDSUB = 3'b000; // Addition / Subtration
    localparam F3_SLT    = 3'b010; // Set less than (signed)
    localparam F3_SLTU   = 3'b011; // Set less than (unsigned)
    localparam F3_XOR    = 3'b100; // Exclusive OR
    localparam F3_OR     = 3'b110; // OR logic
    localparam F3_AND    = 3'b111; // AND logic
    localparam F3_SLL    = 3'b001; // Logic shift left
    localparam F3_SR     = 3'b101; // Shift right (Logic / Arithmetic)
    // Branch
    localparam F3_BEQ  = 3'b000;
    localparam F3_BNE  = 3'b001;
    localparam F3_BLT  = 3'b100;
    localparam F3_BGE  = 3'b101;
    localparam F3_BLTU = 3'b110;
    localparam F3_BGEU = 3'b111;

    ///////////////////////////////////////////////////////////////////////////
    // Testbench I/O and signal definitions
    ///////////////////////////////////////////////////////////////////////////

    //Internal Signals
    reg         clk;
    reg         rst;
    integer     count;
    integer     end_count;

    //Other register declaration
    wire    [31:0] memory        [0: 31];
    reg     [31:0] register_file [0: 31];
    reg     [ 7:0] mem_block     [0:127];
	reg     [31:0] instr;
    reg     [31:0] pc, pc_tmp;
    reg     [31:0] addr, data;
    reg     [ 6:0] opcode;
    reg     [ 2:0] funct3;
    reg     [ 6:0] funct7;
    reg     [ 4:0] rs1, rs2, rd;
    reg     [19:0] sign_ext_20, imm_20;
    reg     [11:0] sign_ext_12, imm_12;
    integer idx;
    genvar  block;

    // Generate tested module
    Simple_Single_CPU cpu
    (
        .clk_i(clk),
        .rst_n(rst)
    );

    // Memory mapping
    generate
        for(block = 0; block < 32; block = block + 1'b1)
        begin : MEM_mapping
            assign  memory[block] = {mem_block[3 + 4*block], mem_block[2 + 4*block], mem_block[1 + 4*block], mem_block[0 + 4*block]};
        end
    endgenerate

	///////////////////////////////////////////////////////////////////////////
    // Testbench behavior
    ///////////////////////////////////////////////////////////////////////////
    // Global clock generate
    always #(`CYCLE_TIME/2) clk = ~clk;	

    // Setting RegFile and Memory initial data
    initial begin
        // Update instruction and function field
        for(idx = 0;idx < 32; idx = idx + 1)begin
            register_file[idx] = 32'd0;
        end
        register_file[29]= 32'd128; //Stack pointer
        
        for(idx=0; idx < 128; idx = idx + 1)begin
            mem_block[idx] = 8'b0;
        end
    end

    initial begin
		$fsdbDumpfile("Simple_Single_CPU.fsdb");
		$fsdbDumpvars;
		$fsdbDumpMDA;
	end

    // Testbench begin
    initial
    begin
        `ifdef TB1
            $readmemb(`INSTR_PATH, cpu.IM.memory);
        `endif
        `ifdef TB2
            $readmemh(`INSTR_PATH, cpu.IM.memory);
        `endif
        // Initialize
        // System
        clk = 1'b0;
        rst = 1'b0;
        count = 0;
        
        // Module
        pc     = 32'd0;
        pc_tmp = 32'd0;
        instr  = 32'd0;
        rs1    =  5'd0;
        rs2    =  5'd0;
        rd     =  5'd0;
        addr   = 32'd0;
        data   = 32'd0;
        opcode = 7'b0000000;
        funct3 = 3'b000;
        funct7 = 7'b0000000;
        imm_12 = 12'd0;
        imm_20 = 20'd0;
        sign_ext_12 = 12'd0;
        sign_ext_20 = 20'd0;

        // Reset done
        @(negedge clk);

        // Start normal mode
        rst = 1'b1;
        pc = cpu.PC.count_o; // Get PC value
        
        // Do until all instruction finished
        while(count != `END_COUNT)begin
            instr = cpu.IM.memory[cpu.PC.count_o >> 2]; // Get instruction
            pc_tmp = pc;     // Present PC value
            pc = pc + 32'd4; // Step PC for 4
            opcode = instr[6:0];
            case(opcode[6:2])
                OPC_OP:
                    begin
                        rs1    = instr[19:15];
                        rs2    = instr[24:20];
                        rd     = instr[11: 7];
                        funct3 = instr[14:12];
                        funct7 = instr[31:25];
                        case(funct3)
                            F3_ADDSUB:
                                begin
                                    if (funct7[5] && opcode[5]) // There is no SUBI
                                        register_file[rd] = $signed(register_file[rs1]) - $signed(register_file[rs2]);
                                    else
                                        register_file[rd] = $signed(register_file[rs1]) + $signed(register_file[rs2]);
                                end
                            F3_AND:
                                begin
                                    register_file[rd] = register_file[rs1] & register_file[rs2] ;
                                end
                            F3_OR:
                                begin
                                    register_file[rd] = register_file[rs1] | register_file[rs2] ;
                                end
                            F3_XOR:
                                begin
                                    register_file[rd] = register_file[rs1] ^ register_file[rs2] ;
                                end
                            F3_SLT:
                                begin
                                    register_file[rd] = ($signed(register_file[rs1]) < $signed(register_file[rs2])) ?(32'd1):(32'd0) ;
                                end
                            F3_SLTU:
                                begin
                                    register_file[rd] = (register_file[rs1] < register_file[rs2]) ? (32'd1): (32'd0);
                                end
                            F3_SLL:
                                begin
                                    register_file[rd] = register_file[rs2] << register_file[rs1];
                                end
                            F3_SR:
                                begin
                                    if(funct7[5])
                                        register_file[rd] = $signed(register_file[rs2]) >>> register_file[rs1];
                                    else
                                        register_file[rd] = register_file[rs2] >> register_file[rs1];
                                end
                            default:
                                begin
                                    $display("ERROR: Invalid function code!!\nSimulation stop.");
                                    #(`CYCLE_TIME*1);
                                    $stop;
                                end
                        endcase
                    end
                OPC_OP_IMM:
                    begin
                        rs1    = instr[19:15];
                        rd     = instr[11: 7];
                        funct3 = instr[14:12];
                        imm_12 = instr[31:20];
                        sign_ext_20 = {20{instr[31]}};
                        case(funct3)
                            F3_ADDSUB: // ADDI
                                begin
                                    register_file[rd] = $signed(register_file[rs1]) + $signed({sign_ext_20, imm_12});
                                end
                            F3_AND:    // ANDI
                                begin
                                    register_file[rd] = register_file[rs1] & {sign_ext_20, imm_12};
                                end
                            F3_OR:     // ORI
                                begin
                                    register_file[rd] = register_file[rs1] | {sign_ext_20, imm_12};
                                end
                            F3_SLT:    // SLTI
                                begin
                                    register_file[rd] = ($signed(register_file[rs1]) < $signed({sign_ext_20, imm_12})) ?(32'd1):(32'd0);
                                end
                            F3_SLTU:   // SLTIU
                                begin
                                    register_file[rd] = (register_file[rs1] < {sign_ext_20, imm_12}) ?(32'd1):(32'd0);
                                end
                            F3_SLL:    // SLLI
                                begin
                                    register_file[rd] = register_file[rs2] << {sign_ext_20, imm_12};
                                end
                            F3_SR:    // SRLI
                                begin
                                    if(funct7[5])
                                        register_file[rd] = $signed(register_file[rs2]) >>> {sign_ext_20, imm_12};
                                    else
                                        register_file[rd] = register_file[rs2] >> {sign_ext_20, imm_12};
                                end
                            default:
                                begin
                                    $display("ERROR: Invalid function code!!\nSimulation stopped.");
                                    #(`CYCLE_TIME*1);
                                    $stop;
                                end
                        endcase
                    end
                OPC_BRANCH:
                    begin
                        rs1    = instr[19:15];
                        rs2    = instr[24:20];
                        funct3 = instr[14:12];
                        imm_12 = {instr[7], instr[30:25], instr[11:8], 1'b0};
                        sign_ext_20 = {20{instr[31]}};
                        case(funct3)
                            F3_BEQ:
                                begin
                                    if(register_file[rs1] == register_file[rs2])
                                        pc = pc_tmp + {sign_ext_20, imm_12};
                                end
                            F3_BNE:
                                begin
                                    if(register_file[rs1] != register_file[rs2])
                                        pc = pc_tmp + {sign_ext_20, imm_12};
                                end
                            F3_BLT:
                                begin
                                    if($signed(register_file[rs1]) < $signed(register_file[rs2]))
                                        pc = pc_tmp + {sign_ext_20, imm_12};
                                end
                            F3_BGE:
                                begin
                                    if($signed(register_file[rs1]) >= $signed(register_file[rs2]))
                                        pc = pc_tmp + {sign_ext_20, imm_12};
                                end
                            F3_BLTU:
                                begin
                                    if(register_file[rs1] < register_file[rs2])
                                        pc = pc_tmp + {sign_ext_20, imm_12};
                                end
                            F3_BGEU:
                                begin
                                    if(register_file[rs1] >= register_file[rs2])
                                        pc = pc_tmp + {sign_ext_20, imm_12};
                                end
                        endcase
                    end
                OPC_LOAD:
                    begin
                        rs1 = instr[19:15];
                        rd  = instr[11: 7];
                        imm_12 = instr[31:20];
                        sign_ext_20 = {20{instr[31]}};
                        addr = register_file[rs1] + {sign_ext_20, imm_12};
                        register_file[rd] = {mem_block[addr+3], mem_block[addr+2], mem_block[addr+1], mem_block[addr]};
                    end
                OPC_STORE:
                    begin
                        rs1 = instr[19:15];
                        rs2 = instr[24:20];
                        imm_12 = {instr[31:25], instr[11:7]};
                        sign_ext_20 = {20{instr[31]}};
                        addr = register_file[rs1] + {sign_ext_20, imm_12};
                        data = register_file[rs2];
                        mem_block[addr+3] <= data[31:24];
                        mem_block[addr+2] <= data[23:16];
                        mem_block[addr+1] <= data[15:8];
                        mem_block[addr]   <= data[7:0];
                    end
                OPC_JAL:
                    begin
                        rd  = instr[11:7];
                        imm_20 = {instr[19:12], instr[20], instr[30:21], 1'b0};
                        sign_ext_12 = {12{instr[31]}};
                        register_file[rd] = pc_tmp + 4;
                        pc = pc_tmp + {sign_ext_12, imm_20};
                    end
                OPC_JALR:
                    begin
                        rs1 = instr[19:15];
                        rd  = instr[11: 7];
                        imm_12 = instr[31:20];
                        sign_ext_20 = {20{instr[31]}};
                        pc = register_file[rs1] + {sign_ext_20, imm_12};
                        register_file[rd] = pc_tmp + 4;
                    end
                OPC_LUI:
                    begin
                        rd = instr[11: 7];
                        imm_20 = {instr[31:12]};
                        register_file[rd] = {imm_20, 12'd0};
                    end
                OPC_AUIPC:
                    begin
                        rd = instr[11: 7];
                        imm_20 = {instr[31:12]};
                        register_file[rd] = pc_tmp + {imm_20, 12'd0};
                    end
                default:
                    begin
                        $display("ERROR: Invalid op code!!\nSimulation stopped.");
                        #(`CYCLE_TIME*1);
                        $stop;
                    end
            endcase
            register_file[0] = 32'd0; // register[0](x0) is always zero

            @(negedge clk);
            // after the pc of design is updated
            // compare the pc value that are 	
            if(cpu.PC.count_o !== pc)begin
                case(opcode[6:2])
                    OPC_BRANCH:
                        begin
                            case(funct3)
                                F3_BEQ:  $display("ERROR: BEQ  instruction fail");
                                F3_BNE:  $display("ERROR: BNE  instruction fail");
                                F3_BLT:  $display("ERROR: BLT  instruction fail");
                                F3_BGE:  $display("ERROR: BGE  instruction fail");
                                F3_BLTU: $display("ERROR: BLTU instruction fail");
                                F3_BGEU: $display("ERROR: BGEU instruction fail");
                            endcase
                        end
                    OPC_JAL:
                        begin
                            $display("ERROR: JAL instruction fail");
                        end
                    OPC_JALR:
                        begin
                            $display("ERROR: JALR instruction fail");
                        end
                    OPC_AUIPC:
                        begin
                            $display("ERROR: AUIPC instruction fail");
                        end
                    default:
                        begin
                            $display("ERROR: Your next PC points to wrong address");
                        end
                endcase
                $display("The correct pc address is %d",pc);
                $display("Your pc address is %d",cpu.PC.count_o);
                $stop;
            end
            
            // Check the register &  memory file
            // It should be the same with the register file in the design
            for (idx = 0; idx < 32; idx = idx + 1)
            begin
                if (cpu.RF.register[idx] !== register_file[idx] || cpu.DM.memory[idx] !== memory[idx])
                begin
                    case(opcode[6:2])
                        OPC_OP:
                            begin
                                case(funct3)
                                    F3_ADDSUB:
                                        begin
                                            if (funct7[5] && opcode[5])
                                                $display("ERROR: SUB instruction fail");
                                            else
                                                $display("ERROR: ADD instruction fail");
                                        end
                                    F3_AND:  $display("ERROR: AND instruction fail");
                                    F3_OR:   $display("ERROR: OR  instruction fail");
                                    F3_XOR:  $display("ERROR: XOR instruction fail");
                                    F3_SLT:  $display("ERROR: SLT instruction fail");
                                    F3_SLTU: $display("ERROR: SLT instruction fail");
                                    F3_SLL:  $display("ERROR: SLL instruction fail");
                                    F3_SR:
                                        begin
                                            if(funct7[5])
                                                $display("ERROR: SAL instruction fail");
                                            else
                                                $display("ERROR: SRL instruction fail");
                                        end
                                endcase
                            end
                        OPC_OP_IMM: 
                            begin
                                case(funct3)
                                    F3_ADDSUB: $display("ERROR: ADDI instruction fail");
                                    F3_AND:    $display("ERROR: ANDI instruction fail");
                                    F3_OR:     $display("ERROR: ORI  instruction fail");
                                    F3_XOR:    $display("ERROR: XORI instruction fail");
                                    F3_SLT:    $display("ERROR: SLTI instruction fail");
                                    F3_SLTU:   $display("ERROR: SLIU instruction fail");
                                    F3_SLL:    $display("ERROR: SLLI instruction fail");
                                    F3_SR:
                                        begin
                                            if(funct7[5])
                                                $display("ERROR: SALI instruction fail");
                                            else
                                                $display("ERROR: SRLI instruction fail");
                                        end
                                endcase
                            end
                        OPC_BRANCH:
                        begin
                            case(funct3)
                                F3_BEQ:  $display("ERROR: BEQ  instruction fail");
                                F3_BNE:  $display("ERROR: BNE  instruction fail");
                                F3_BLT:  $display("ERROR: BLT  instruction fail");
                                F3_BGE:  $display("ERROR: BGE  instruction fail");
                                F3_BLTU: $display("ERROR: BLTU instruction fail");
                                F3_BGEU: $display("ERROR: BGEU instruction fail");
                            endcase
                        end
                        OPC_LOAD:  $display("ERROR: LW    instruction fail");
                        OPC_STORE: $display("ERROR: SW    instruction fail");
                        OPC_JAL:   $display("ERROR: JAL   instruction fail");
                        OPC_JALR:  $display("ERROR: JALR  instruction fail");
                        OPC_LUI:   $display("ERROR: LUI   instruction fail");
                        OPC_AUIPC: $display("ERROR: AUIPC instruction fail");
                    endcase

                    // Register check
                    if (cpu.RF.register[idx] !== register_file[idx])
                    begin
                        $display("Register %d contains wrong answer",idx);
                        $display("The correct value is %d ",register_file[idx]);
                        $display("Your wrong value is %d ",cpu.RF.register[idx]);
                    end
                    
                    // Memory check
                    if (cpu.DM.memory[idx] !== memory[idx])
                    begin
                        $display("Memory %d contains wrong answer",idx);
                        $display("The correct value is %d ",memory[idx]);
                        $display("Your wrong value is %d ",cpu.DM.memory[idx]);
                    end
                    $stop;
                end
            end
            if(cpu.IM.memory[pc >> 2] == 32'd0)
            begin
                count = `END_COUNT;
                #(`CYCLE_TIME*2);
            end
            else count = count + 1;
        end
        $display("============================================");
        $display("======== ==== ============= ==== ===========");
        $display("========  ==  =============  ==  ===========");
        $display("========      ==   ===   ==      ===========");
        $display("=========    ==== ===== ====    ============");
        $display("==========  ===           ===  =============");
        $display("===========  ==           ==  ==============");
        $display("============================================");
        $display("Congratulation.  You pass  TA's pattern  ");
        
                $display("Register======================================================");
                $display("r0=%d, r1=%d, r2=%d, r3=%d,\n\
r4=%d, r5=%d, r6=%d, r7=%d,\n\
r8=%d, r9=%d, r10=%d, r11=%d,\n\
r12=%d, r13=%d, r14=%d, r15=%d,\n\
r16=%d, r17=%d, r18=%d, r19=%d,\n\
r20=%d, r21=%d, r22=%d, r23=%d,\n\
r24=%d, r25=%d, r26=%d, r27=%d,\n\
r28=%d, r29=%d, r30=%d, r31=%d,\n",
                cpu.RF.register[0], cpu.RF.register[1], cpu.RF.register[2], cpu.RF.register[3], cpu.RF.register[4], 
                cpu.RF.register[5], cpu.RF.register[6], cpu.RF.register[7], cpu.RF.register[8], cpu.RF.register[9], 
                cpu.RF.register[10],cpu.RF.register[11], cpu.RF.register[12], cpu.RF.register[13], cpu.RF.register[14],
                cpu.RF.register[15], cpu.RF.register[16], cpu.RF.register[17], cpu.RF.register[18], cpu.RF.register[19], 
                cpu.RF.register[20], cpu.RF.register[21], cpu.RF.register[22], cpu.RF.register[23], cpu.RF.register[24], 
                cpu.RF.register[25],cpu.RF.register[26], cpu.RF.register[27], cpu.RF.register[28], cpu.RF.register[29],
                cpu.RF.register[30],cpu.RF.register[31]);
                $display("Data Memory========================================================");
                $display("m0=%d, m1=%d, m2=%d, m3=%d,\n\
m4=%d, m5=%d, m6=%d, m7=%d,\n\
m8=%d, m9=%d, m10=%d, m11=%d,\n\
m12=%d, m13=%d, m14=%d, m15=%d,\n\
m16=%d, m17=%d, m18=%d, m19=%d,\n\
m20=%d, m21=%d, m22=%d, m23=%d,\n\
m24=%d, m25=%d, m26=%d, m27=%d,\n\
m28=%d, m29=%d, m30=%d, m31=%d,\n",
                cpu.DM.memory[0], cpu.DM.memory[1], cpu.DM.memory[2], cpu.DM.memory[3], cpu.DM.memory[4], 
                cpu.DM.memory[5], cpu.DM.memory[6], cpu.DM.memory[7], cpu.DM.memory[8], cpu.DM.memory[9], 
                cpu.DM.memory[10],cpu.DM.memory[11], cpu.DM.memory[12], cpu.DM.memory[13], cpu.DM.memory[14],
                cpu.DM.memory[15], cpu.DM.memory[16], cpu.DM.memory[17], cpu.DM.memory[18], cpu.DM.memory[19], 
                cpu.DM.memory[20], cpu.DM.memory[21], cpu.DM.memory[22], cpu.DM.memory[23], cpu.DM.memory[24], 
                cpu.DM.memory[25],cpu.DM.memory[26], cpu.DM.memory[27], cpu.DM.memory[28], cpu.DM.memory[29],
                cpu.DM.memory[30],cpu.DM.memory[31]); 
                /*$display("Instruction Memory========================================================");
                $display("m0=%d, m1=%d, m2=%d, m3=%d,\n\
m4=%d, m5=%d, m6=%d, m7=%d,\n\
m8=%d, m9=%d, m10=%d, m11=%d,\n\
m12=%d, m13=%d, m14=%d, m15=%d,\n\
m16=%d, m17=%d, m18=%d, m19=%d,\n\
m20=%d, m21=%d, m22=%d, m23=%d,\n\
m24=%d, m25=%d, m26=%d, m27=%d,\n\
m28=%d, m29=%d, m30=%d, m31=%d,\n",
                cpu.IM.memory[0], cpu.IM.memory[1], cpu.IM.memory[2], cpu.IM.memory[3], cpu.IM.memory[4], 
                cpu.IM.memory[5], cpu.IM.memory[6], cpu.IM.memory[7], cpu.IM.memory[8], cpu.IM.memory[9], 
                cpu.IM.memory[10],cpu.IM.memory[11], cpu.IM.memory[12], cpu.IM.memory[13], cpu.IM.memory[14],
                cpu.IM.memory[15], cpu.IM.memory[16], cpu.IM.memory[17], cpu.IM.memory[18], cpu.IM.memory[19], 
                cpu.IM.memory[20], cpu.IM.memory[21], cpu.IM.memory[22], cpu.IM.memory[23], cpu.IM.memory[24], 
                cpu.IM.memory[25],cpu.IM.memory[26], cpu.IM.memory[27], cpu.IM.memory[28], cpu.IM.memory[29],
                cpu.IM.memory[30],cpu.IM.memory[31]);*/
        $stop;
    end
//*****************************************************************************
endmodule
