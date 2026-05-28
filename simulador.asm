.data
# --- Configurações / constantes ---
.eqv MEM_SIZE_BYTES, 4096
.eqv WORD_SIZE, 4
.eqv NUM_REGS, 32

# Segmentos de memória
text_seg:      .space MEM_SIZE_BYTES
data_seg:      .space MEM_SIZE_BYTES
stack_seg:     .space MEM_SIZE_BYTES

# Banco de registradores (32 x 4 bytes)
reg_file:      .space 128

# Registradores internos
pc:            .word 0
ir:            .word 0
ciclos:        .word 0        # contador de ciclos
text_size:     .word 0        # tamanho (em bytes) do arquivo carregado em text_seg
primeiro_arquivo: .word 1     # flag: 1 = é o primeiro arquivo (text), 0 = é o segundo (data)

# Variáveis para campos da instrução corrente (adicionadas conforme especificação)
campo_opcode:  .word 0
campo_rs:      .word 0
campo_rt:      .word 0
campo_rd:      .word 0
campo_shamt:   .word 0
campo_funct:   .word 0
campo_imm:     .word 0
campo_addr:    .word 0

# Buffer temporário para leitura de arquivo
temp_buffer:    .space 1024

# Nomes dos arquivos de entrada
# IMPORTANTE: Colocar os arquivos na pasta raiz de trabalho do MARS, não em subpasta
text_filename:  .asciiz "ex-000-073.bin"
data_filename:  .asciiz "ex-000-073.dat"

# --- Strings de Debug ---
msg_inicio:     .asciiz "=== SIMULADOR MIPS INICIADO ===\n"
msg_arquivos:   .asciiz "Aquivos carregados. Iniciando execucao...\n"
msg_ciclo:      .asciiz "--- CICLO "
msg_pc:         .asciiz " | PC: "
msg_ir:         .asciiz " | IR: "
msg_opcode:     .asciiz " | OPCODE: "
msg_fim_linha:  .asciiz "\n"
msg_add:        .asciiz "[ADD] $"
msg_addi:       .asciiz "[ADDI] $"
msg_lw:         .asciiz "[LW] $"
msg_sw:         .asciiz "[SW] $"
msg_beq:        .asciiz "[BEQ] "
msg_j:          .asciiz "[J] "
msg_syscall:    .asciiz "[SYSCALL] Encerrando...\n"
msg_equals:     .asciiz " = 0x"
msg_instrunk:   .asciiz "[INSTRUCAO DESCONHECIDA]\n"
msg_fim_arquivo: .asciiz "\n=== FIM DO ARQUIVO ===\"\n"
msg_tamanho:    .asciiz "Tamanho do arquivo: "
msg_bytes:      .asciiz " bytes\n"
msg_erro_arquivo: .asciiz "ERRO: Falha ao abrir arquivo!\n"
msg_debug_texto: .asciiz "Arquivo TEXT carregado\n"
msg_debug_dados: .asciiz "Arquivo DATA carregado\n"
msg_carregando_texto: .asciiz "Carregando arquivo TEXT (instruções)...\n"
msg_carregando_dados: .asciiz "Carregando arquivo DATA (dados)...\n"


.text
.globl main

main:
	addiu $sp, $sp, -8
	sw $ra, 4($sp)
	sw $fp, 0($sp)

	# --- Checkpoint: Início do Simulador ---
	li $v0, 4
	la $a0, msg_inicio
	syscall

	jal inicializar

	# Carregar arquivo TEXT (instruções)
	li $v0, 4
	la $a0, msg_carregando_texto
	syscall

	la $a0, text_filename
	la $a1, text_seg
	jal carregar_arquivo_binario

	# Checkpoint: Arquivo TEXT carregado
	li $v0, 4
	la $a0, msg_debug_texto
	syscall

	# Carregar arquivo DATA (dados)
	li $v0, 4
	la $a0, msg_carregando_dados
	syscall

	la $a0, data_filename
	la $a1, data_seg
	jal carregar_arquivo_binario

	# Checkpoint: Arquivo DATA carregado
	li $v0, 4
	la $a0, msg_debug_dados
	syscall

	# --- Checkpoint: Arquivos Carregados ---
	li $v0, 4
	la $a0, msg_arquivos
	syscall

	# --- Checkpoint: Imprimir tamanho do arquivo carregado ---
	li $v0, 4
	la $a0, msg_tamanho
	syscall
	li $v0, 1
	la $t0, text_size
	lw $a0, 0($t0)
	syscall
	li $v0, 4
	la $a0, msg_bytes
	syscall

main_loop:
    # Verificar limite de ciclos (proteção contra loop infinito)
	la $t0, ciclos
	lw $t1, 0($t0)
	li $t2, 10000
	bge $t1, $t2, exit_simulator

	# Verificar limite usando offset do PC
	la $t0, pc
	lw $t1, 0($t0)
	la $t4, text_size
	lw $t5, 0($t4)
	bge $t1, $t5, exit_simulator

	# Incrementar contador de ciclos
	la $t0, ciclos
	lw $t1, 0($t0)
	addi $t1, $t1, 1
	sw $t1, 0($t0)

	# --- Checkpoint: Imprimir Ciclo, PC e IR ---
	li $v0, 4
	la $a0, msg_ciclo
	syscall
	li $v0, 1
	move $a0, $t1            # Imprimir ciclo (já em $t1)
	syscall
	li $v0, 4
	la $a0, msg_pc
	syscall
	li $v0, 34
	la $t0, pc
	lw $a0, 0($t0)
	syscall
	li $v0, 4
	la $a0, msg_ir
	syscall
	li $v0, 34
	la $t0, ir
	lw $a0, 0($t0)
	syscall
	li $v0, 4
	la $a0, msg_fim_linha
	syscall

	jal fetch
	jal decode
	jal executar
	j main_loop

exit_simulator:
	# --- Checkpoint: Fim do Arquivo ---
	li $v0, 4
	la $a0, msg_fim_arquivo
	syscall
	li $v0, 10
	syscall

	lw $ra, 4($sp)
	lw $fp, 0($sp)
	addiu $sp, $sp, 8
	jr $ra

inicializar:
	addiu $sp, $sp, -4
	sw $ra, 0($sp)

	la $t0, reg_file
	li $t1, 32           # NUM_REGS = 32 (literal)
	li $t2, 0
zerar_regs_loop:
	beq $t2, $t1, zerar_regs_done
	sw $zero, 0($t0)
	addi $t0, $t0, 4     # WORD_SIZE = 4 (literal)
	addi $t2, $t2, 1
	j zerar_regs_loop
zerar_regs_done:
	# PC = 0 (offset simples, não endereço absoluto)
	li $t0, 0
	la $t1, pc
	sw $t0, 0($t1)

    # Inicializar $sp simulado = 0x7FFFEFFC
	lui $t0, 0x7FFF
	ori $t0, $t0, 0xEFFC
	la $t1, reg_file
	sw $t0, 116($t1)         # reg[29] × 4 = 116

	lw $ra, 0($sp)
	addiu $sp, $sp, 4
	jr $ra

carregar_arquivo_binario:
	# a0 = filename, a1 = base destino, a2 = endereço para salvar tamanho (opcional)
	# Syscalls de arquivo: 13=open, 14=read, 16=close
	# Compatível com MARS 4.5+
	addiu $sp, $sp, -16
	sw $ra, 12($sp)
	sw $s0, 8($sp)
	sw $s1, 4($sp)
	sw $s2, 0($sp)

	move $s0, $a1            # $s0 = base de destino
	move $s2, $a1            # $s2 = cópia da base para calcular tamanho depois

	li $v0, 13
	li $a1, 0
	li $a2, 0
	syscall
	bltz $v0, erro_arquivo
	move $s1, $v0

ler_loop:
	move $a0, $s1
	la $a1, temp_buffer
	li $a2, 1024
	li $v0, 14
	syscall
	blez $v0, fechar_arquivo

	move $t0, $v0          # bytes lidos
	la $t1, temp_buffer
	move $t2, $s0          # destino atual
copiar_loop:
	li $t3, 4
	blt $t0, $t3, copiar_resto

	# Lê 4 bytes na ordem little-endian
	lb $t3, 0($t1)             # B0 (byte menos significativo)
	lb $t4, 1($t1)             # B1
	lb $t5, 2($t1)             # B2
	lb $t6, 3($t1)             # B3 (byte mais significativo)

	# Monta a word em big-endian: B3<<24 | B2<<16 | B1<<8 | B0
	andi $t3, $t3, 0xFF
	andi $t4, $t4, 0xFF
	andi $t5, $t5, 0xFF
	andi $t6, $t6, 0xFF

	sll $t6, $t6, 24
	sll $t5, $t5, 16
	sll $t4, $t4, 8
	or  $t6, $t6, $t5
	or  $t6, $t6, $t4
	or  $t6, $t6, $t3          # $t6 = word reordenada

	sw  $t6, 0($t2)            # escreve word no destino

	addi $t1, $t1, 4
	addi $t2, $t2, 4
	addi $t0, $t0, -4
	j copiar_loop

copiar_resto:
	# copia bytes restantes (< 4) sem inversão
	beq $t0, $zero, atualiza_destino
	lb $t3, 0($t1)
	sb $t3, 0($t2)
	addi $t1, $t1, 1
	addi $t2, $t2, 1
	addi $t0, $t0, -1
	j copiar_resto

atualiza_destino:
	move $s0, $t2
	j ler_loop

fechar_arquivo:
	move $a0, $s1
	li $v0, 16
	syscall

	subu $t0, $s0, $s2
	la $t1, primeiro_arquivo
	lw $t2, 0($t1)
	beqz $t2, carregar_sem_salvar

	la $t1, text_size
	sw $t0, 0($t1)
	la $t1, primeiro_arquivo
	sw $zero, 0($t1)

carregar_sem_salvar:
	j carregar_fim

erro_arquivo:
	li $v0, 4
	la $a0, msg_erro_arquivo
	syscall
	la $t1, primeiro_arquivo
	sw $zero, 0($t1)

carregar_fim:
	lw $s2, 0($sp)
	lw $s1, 4($sp)
	lw $s0, 8($sp)
	lw $ra, 12($sp)
	addiu $sp, $sp, 16
	jr $ra

# --- Procedimentos de Memória ---

# verifica_endereco: verifica se um endereço pertence a um segmento
# a0 = endereço, a1 = tipo de segmento (0=text, 1=data, 2=stack)
# retorna: v0 = 1 se válido, 0 se inválido
verifica_endereco:
	addiu $sp, $sp, -4
	sw $ra, 0($sp)

	la $t0, text_seg
	la $t1, data_seg
	la $t2, stack_seg

	beq $a1, 0, verifica_text
	beq $a1, 1, verifica_data
	beq $a1, 2, verifica_stack
	li $v0, 0
	j verifica_fim

verifica_text:
	# verifica se a0 está entre text_seg e text_seg + 4096
	blt $a0, $t0, endereco_invalido
	addi $t3, $t0, 4096
	bge $a0, $t3, endereco_invalido
	li $v0, 1
	j verifica_fim

verifica_data:
	blt $a0, $t1, endereco_invalido
	addi $t3, $t1, 4096
	bge $a0, $t3, endereco_invalido
	li $v0, 1
	j verifica_fim

verifica_stack:
	blt $a0, $t2, endereco_invalido
	addi $t3, $t2, 4096
	bge $a0, $t3, endereco_invalido
	li $v0, 1
	j verifica_fim

endereco_invalido:
	li $v0, 0

verifica_fim:
	lw $ra, 0($sp)
	addiu $sp, $sp, 4
	jr $ra

# memoria_leitura: lê uma palavra (32 bits) da memória
# a0 = endereço
# retorna: v0 = palavra lida
memoria_leitura:
	addiu $sp, $sp, -4
	sw $ra, 0($sp)

	lw $v0, 0($a0)

	lw $ra, 0($sp)
	addiu $sp, $sp, 4
	jr $ra

# memoria_escrita: escreve uma palavra (32 bits) na memória
# a0 = endereço, a1 = valor
memoria_escrita:
	addiu $sp, $sp, -4
	sw $ra, 0($sp)

	sw $a1, 0($a0)

	lw $ra, 0($sp)
	addiu $sp, $sp, 4
	jr $ra

fetch:
	addiu $sp, $sp, -4
	sw $ra, 0($sp)

	la $t0, pc
	lw $t1, 0($t0)
	# t1 é offset simples (0 a 4096)
	la $t3, text_seg
	addu $t3, $t3, $t1          # endereço real no MARS = text_seg + offset
	lw $t4, 0($t3)
	la $t5, ir
	sw $t4, 0($t5)

	# Incrementa PC em 4
	addi $t1, $t1, 4
	sw $t1, 0($t0)

	lw $ra, 0($sp)
	addiu $sp, $sp, 4
	jr $ra

decode:
	addiu $sp, $sp, -4
	sw $ra, 0($sp)

	la $t0, ir
	lw $t1, 0($t0)

	# opcode = bits 31-26
	srl $t2, $t1, 26
	la $t0, campo_opcode
	sw $t2, 0($t0)

	# rs = bits 25-21
	srl $t2, $t1, 21
	andi $t2, $t2, 0x1F
	la $t0, campo_rs
	sw $t2, 0($t0)

	# rt = bits 20-16
	srl $t2, $t1, 16
	andi $t2, $t2, 0x1F
	la $t0, campo_rt
	sw $t2, 0($t0)

	# rd = bits 15-11
	srl $t2, $t1, 11
	andi $t2, $t2, 0x1F
	la $t0, campo_rd
	sw $t2, 0($t0)

	# shamt = bits 10-6
	srl $t2, $t1, 6
	andi $t2, $t2, 0x1F
	la $t0, campo_shamt
	sw $t2, 0($t0)

	# funct = bits 5-0
	andi $t2, $t1, 0x3F
	la $t0, campo_funct
	sw $t2, 0($t0)

	# immediate = bits 15-0 (com extensão de sinal)
	andi $t2, $t1, 0xFFFF
	sll $t2, $t2, 16
	sra $t2, $t2, 16
	la $t0, campo_imm
	sw $t2, 0($t0)

	# address = bits 25-0 (J-type)
	andi $t2, $t1, 0x03FFFFFF
	la $t0, campo_addr
	sw $t2, 0($t0)

	lw $ra, 0($sp)
	addiu $sp, $sp, 4
	jr $ra

executar:
	addiu $sp, $sp, -4
	sw $ra, 0($sp)

	la $t0, campo_opcode
	lw $t1, 0($t0)

    # Tipo R
	beq $t1, $zero, exec_tipo_r

	# addi
	li $t2, 8
	beq $t1, $t2, exec_addi

	# andi
	li $t2, 12
	beq $t1, $t2, exec_andi

	# ori
	li $t2, 13
	beq $t1, $t2, exec_ori

	# lw
	li $t2, 35
	beq $t1, $t2, exec_lw

	# sw
	li $t2, 43
	beq $t1, $t2, exec_sw

	# beq
	li $t2, 4
	beq $t1, $t2, exec_beq

	# bne
	li $t2, 5
	beq $t1, $t2, exec_bne

	# j
	li $t2, 2
	beq $t1, $t2, exec_j

	# --- Checkpoint: Instrução Desconhecida ---
	li $v0, 4
	la $a0, msg_instrunk
	syscall
	j exec_done

exec_tipo_r:
	la $t0, ir
	lw $t1, 0($t0)

	andi $t2, $t1, 0x3F   # funct

	# add
	li $t3, 32
	beq $t2, $t3, exec_add

	# sub
	li $t3, 34
	beq $t2, $t3, exec_sub

	# and
	li $t3, 36
	beq $t2, $t3, exec_and

	# or
	li $t3, 37
	beq $t2, $t3, exec_or

	# sll
	li $t3, 0
	beq $t2, $t3, exec_sll

	# srl
	li $t3, 2
	beq $t2, $t3, exec_srl

	# syscall
	li $t3, 12
	beq $t2, $t3, exec_syscall

	j exec_done

exec_add:
	la $t0, ir
	lw $t1, 0($t0)

	srl $t2, $t1, 21
	andi $t2, $t2, 0x1F      # rs

	srl $t3, $t1, 16
	andi $t3, $t3, 0x1F      # rt

	srl $t4, $t1, 11
	andi $t4, $t4, 0x1F      # rd

	la $t5, reg_file

	sll $t6, $t2, 2
	addu $t6, $t5, $t6
	lw $t7, 0($t6)           # valor de reg[rs]

	sll $t6, $t3, 2
	addu $t6, $t5, $t6
	lw $t8, 0($t6)           # valor de reg[rt]

	addu $t9, $t7, $t8       # rd = rs + rt

	beqz $t4, exec_done      # protege $zero: não escreve em reg[0]

	sll $t6, $t4, 2
	addu $t6, $t5, $t6
	sw $t9, 0($t6)           # reg[rd] = resultado

	j exec_done

exec_sub:
	la $t0, ir
	lw $t1, 0($t0)

	srl $t2, $t1, 21
	andi $t2, $t2, 0x1F

	srl $t3, $t1, 16
	andi $t3, $t3, 0x1F

	srl $t4, $t1, 11
	andi $t4, $t4, 0x1F

	la $t5, reg_file

	sll $t6, $t2, 2
	addu $t6, $t5, $t6
	lw $t7, 0($t6)

	sll $t6, $t3, 2
	addu $t6, $t5, $t6
	lw $t8, 0($t6)

	subu $t9, $t7, $t8
    
	beqz $t4, exec_done 
	sll $t6, $t4, 2
	addu $t6, $t5, $t6
	sw $t9, 0($t6)

	j exec_done

exec_and:
	la $t0, ir
	lw $t1, 0($t0)

	srl $t2, $t1, 21
	andi $t2, $t2, 0x1F

	srl $t3, $t1, 16
	andi $t3, $t3, 0x1F

	srl $t4, $t1, 11
	andi $t4, $t4, 0x1F

	la $t5, reg_file

	sll $t6, $t2, 2
	addu $t6, $t5, $t6
	lw $t7, 0($t6)

	sll $t6, $t3, 2
	addu $t6, $t5, $t6
	lw $t8, 0($t6)

	and $t9, $t7, $t8
    
	beqz $t4, exec_done 
	sll $t6, $t4, 2
	addu $t6, $t5, $t6
	sw $t9, 0($t6)

	j exec_done

exec_or:
	la $t0, ir
	lw $t1, 0($t0)

	srl $t2, $t1, 21
	andi $t2, $t2, 0x1F

	srl $t3, $t1, 16
	andi $t3, $t3, 0x1F

	srl $t4, $t1, 11
	andi $t4, $t4, 0x1F

	la $t5, reg_file

	sll $t6, $t2, 2
	addu $t6, $t5, $t6
	lw $t7, 0($t6)

	sll $t6, $t3, 2
	addu $t6, $t5, $t6
	lw $t8, 0($t6)

	or $t9, $t7, $t8
    
	beqz $t4, exec_done 
	sll $t6, $t4, 2
	addu $t6, $t5, $t6
	sw $t9, 0($t6)

	j exec_done

exec_sll:
	la $t5, reg_file

	la $t0, campo_rt
	lw $t2, 0($t0)
	sll $t6, $t2, 2
	addu $t6, $t5, $t6
	lw $t7, 0($t6)           # reg[rt]

	la $t0, campo_shamt
	lw $t4, 0($t0)           # shamt (imediato de 5 bits)

	# Executa shift: não podemos usar sll com registrador diretamente,
	# então usamos sllv que aceita o shamt em registrador
	sllv $t8, $t7, $t4

	la $t0, campo_rd
	lw $t3, 0($t0)
	beqz $t3, exec_done
	sll $t6, $t3, 2
	addu $t6, $t5, $t6
	sw $t8, 0($t6)
	j exec_done

exec_srl:
	la $t5, reg_file

	la $t0, campo_rt
	lw $t2, 0($t0)
	sll $t6, $t2, 2
	addu $t6, $t5, $t6
	lw $t7, 0($t6)

	la $t0, campo_shamt
	lw $t4, 0($t0)

	srlv $t8, $t7, $t4

	la $t0, campo_rd
	lw $t3, 0($t0)
	beqz $t3, exec_done
	sll $t6, $t3, 2
	addu $t6, $t5, $t6
	sw $t8, 0($t6)
	j exec_done

exec_andi:
	la $t0, ir
	lw $t1, 0($t0)

	srl $t2, $t1, 21
	andi $t2, $t2, 0x1F

	srl $t3, $t1, 16
	andi $t3, $t3, 0x1F

	andi $t4, $t1, 0xFFFF

	la $t5, reg_file

	sll $t6, $t2, 2
	addu $t6, $t5, $t6
	lw $t7, 0($t6)

	and $t8, $t7, $t4
    
	srl $t3, $t1, 16
	andi $t3, $t3, 0x1F
	beqz $t3, exec_done 
	sll $t6, $t3, 2
	addu $t6, $t5, $t6
	sw $t8, 0($t6)

	j exec_done

exec_ori:
	la $t0, ir
	lw $t1, 0($t0)

	srl $t2, $t1, 21
	andi $t2, $t2, 0x1F

	srl $t3, $t1, 16
	andi $t3, $t3, 0x1F

	andi $t4, $t1, 0xFFFF

	la $t5, reg_file

	sll $t6, $t2, 2
	addu $t6, $t5, $t6
	lw $t7, 0($t6)

	or $t8, $t7, $t4
    
	srl $t3, $t1, 16
	andi $t3, $t3, 0x1F
	beqz $t3, exec_done 
	sll $t6, $t3, 2
	addu $t6, $t5, $t6
	sw $t8, 0($t6)

	j exec_done

exec_syscall:
	# Lê reg[2] ($v0 simulado) do reg_file
	la $t0, reg_file
	lw $t1, 8($t0)           # reg[2] * 4 = offset 8

	# exit (código 1)
	li $t2, 1
	beq $t1, $t2, syscall_exit

	# exit2 (código 10) — o mais comum em MIPS
	li $t2, 10
	beq $t1, $t2, syscall_exit

	li $t2, 17
	beq $t1, $t2, syscall_exit

	# Serviço não implementado: ignora e continua
	j exec_done

syscall_exit:
	li $v0, 4
	la $a0, msg_syscall
	syscall
	li $v0, 10
	syscall

exec_addi:
	la $t0, ir
	lw $t1, 0($t0)
	srl $t2, $t1, 21
	andi $t2, $t2, 0x1F     # rs
	srl $t3, $t1, 16
	andi $t3, $t3, 0x1F     # rt
	andi $t4, $t1, 0xFFFF
	sll $t4, $t4, 16
	sra $t4, $t4, 16

	# --- Checkpoint: ADDI ---
	li $v0, 4
	la $a0, msg_addi
	syscall
	li $v0, 1
	move $a0, $t3
	syscall
	li $v0, 4
	la $a0, msg_equals
	syscall

	la $t5, reg_file
	sll $t2, $t2, 2
	addu $t2, $t5, $t2
	lw $t6, 0($t2)
	addu $t6, $t6, $t4
    
    # Imprimir resultado
	li $v0, 34
	move $a0, $t6
	syscall
	li $v0, 4
	la $a0, msg_fim_linha
	syscall

	srl $t3, $t1, 16
	andi $t3, $t3, 0x1F
	beqz $t3, exec_done 
	sll $t3, $t3, 2
	addu $t3, $t5, $t3
	sw $t6, 0($t3)
	j exec_done

exec_lw:
	la $t0, ir
	lw $t1, 0($t0)
	srl $t2, $t1, 21
	andi $t2, $t2, 0x1F     # rs
	srl $t3, $t1, 16
	andi $t3, $t3, 0x1F     # rt
	andi $t4, $t1, 0xFFFF
	sll $t4, $t4, 16
	sra $t4, $t4, 16        # Immediate estendido com sinal

	# --- Checkpoint: LW ---
	li $v0, 4
	la $a0, msg_lw
	syscall
	li $v0, 1
	move $a0, $t3
	syscall
	li $v0, 4
	la $a0, msg_equals
	syscall

	la $t5, reg_file
	sll $t2, $t2, 2
	addu $t2, $t5, $t2
	lw $t6, 0($t2)          # $t6 = valor de reg[rs] (offset em data_seg)

	# $t6 é offset simples, calcular endereço=data_seg+offset+imm
	la $t7, data_seg
	addu $t6, $t7, $t6       # Endereço real no MARS = data_seg + offset
	addu $t6, $t6, $t4       # Endereço final = Endereço real + Immediate (offset)
	lw $t8, 0($t6)          # Lê a word da memória simulada

	beqz $t3, lw_print      # Se rt == 0, não salva no registrador (protege $zero)
	sll $t3, $t3, 2
	addu $t3, $t5, $t3
	sw $t8, 0($t3)          # reg[rt] = valor lido da memória

lw_print:
	# Imprimir resultado lido
	li $v0, 34
	move $a0, $t8
	syscall
	li $v0, 4
	la $a0, msg_fim_linha
	syscall
	j exec_done

exec_sw:
	la $t0, ir
	lw $t1, 0($t0)
	srl $t2, $t1, 21
	andi $t2, $t2, 0x1F     # rs
	srl $t3, $t1, 16
	andi $t3, $t3, 0x1F     # rt
	andi $t4, $t1, 0xFFFF
	sll $t4, $t4, 16
	sra $t4, $t4, 16        # Immediate estendido com sinal

	# --- Checkpoint: SW ---
	li $v0, 4
	la $a0, msg_sw
	syscall
	li $v0, 1
	move $a0, $t3
	syscall
	li $v0, 4
	la $a0, msg_fim_linha
	syscall

	la $t5, reg_file
	
	# Pegar o valor que está dentro de reg[rt] para GUARDAR na memória
	sll $t8, $t3, 2
	addu $t8, $t5, $t8
	lw $t8, 0($t8)          # $t8 = valor de reg[rt]

	# Calcular endereço de destino na memória
	sll $t2, $t2, 2
	addu $t2, $t5, $t2
	lw $t6, 0($t2)          # $t6 = valor de reg[rs] (offset em data_seg)

	# $t6 é offset simples, calcular endereço=data_seg+offset+imm
	la $t7, data_seg
	addu $t6, $t7, $t6       # Endereço real no MARS = data_seg + offset
	addu $t6, $t6, $t4       # Endereço final na memória simulada = + immediate

	sw $t8, 0($t6)      
	j exec_done

exec_beq:
	la $t0, ir
	lw $t1, 0($t0)
	srl $t2, $t1, 21
	andi $t2, $t2, 0x1F     # rs
	srl $t3, $t1, 16
	andi $t3, $t3, 0x1F     # rt
	andi $t4, $t1, 0xFFFF
	sll $t4, $t4, 16
	sra $t4, $t4, 16        # offset com sinal

	# --- Checkpoint: BEQ ---
	li $v0, 4
	la $a0, msg_beq
	syscall

	la $t5, reg_file
	sll $t2, $t2, 2
	addu $t2, $t5, $t2
	lw $t6, 0($t2)          # reg[rs]
	
	sll $t3, $t3, 2
	addu $t3, $t5, $t3
	lw $t7, 0($t3)          # reg[rt]
	
	bne $t6, $t7, beq_nao_salta

	# Se for igual, salta: PC = PC + (offset * 4)
	la $t8, pc
	lw $t9, 0($t8)
	sll $t4, $t4, 2
	addu $t9, $t9, $t4
	sw $t9, 0($t8)

beq_nao_salta:
	li $v0, 4
	la $a0, msg_fim_linha
	syscall
	j exec_done

exec_bne:
	la $t0, ir
	lw $t1, 0($t0)
	srl $t2, $t1, 21
	andi $t2, $t2, 0x1F
	srl $t3, $t1, 16
	andi $t3, $t3, 0x1F
	andi $t4, $t1, 0xFFFF
	sll $t4, $t4, 16
	sra $t4, $t4, 16

	la $t5, reg_file
	sll $t6, $t2, 2
	addu $t6, $t5, $t6
	lw $t7, 0($t6)          # reg[rs]

	sll $t6, $t3, 2
	addu $t6, $t5, $t6
	lw $t8, 0($t6)          # reg[rt]

	beq $t7, $t8, exec_done # Se forem iguais, não salta e sai

	# Se for diferente, salta
	la $t9, pc
	lw $t0, 0($t9)
	sll $t4, $t4, 2
	addu $t0, $t0, $t4
	sw $t0, 0($t9)

	j exec_done

exec_j:
	# --- Checkpoint: J ---
	li $v0, 4
	la $a0, msg_j
	syscall

	# J-type: novo PC = (address << 2)
	la $t0, campo_addr
	lw $t2, 0($t0)
	sll $t2, $t2, 2          # address << 2

	la $t0, pc
	sw $t2, 0($t0)           # novo PC = target

	li $v0, 4
	la $a0, msg_fim_linha
	syscall
	j exec_done

exec_done:
	lw $ra, 0($sp)
	addiu $sp, $sp, 4
	jr $ra