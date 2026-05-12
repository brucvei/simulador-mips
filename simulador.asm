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
opcode_store:  .word 0
ciclos:        .word 0        # contador de ciclos
text_size:     .word 0        # tamanho (em bytes) do arquivo carregado em text_seg
primeiro_arquivo: .word 1     # flag: 1 = é o primeiro arquivo (text), 0 = é o segundo (data)

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
	# Verificar se PC chegou ao final do arquivo
	la $t0, pc
	lw $t1, 0($t0)           # $t1 = PC atual
	la $t2, text_size
	lw $t3, 0($t2)           # $t3 = tamanho do arquivo
	bge $t1, $t3, exit_simulator  # Se PC >= tamanho, sair

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
	la $t0, pc
	sw $zero, 0($t0)

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
	beq $t0, $zero, atualiza_destino
	lb $t3, 0($t1)
	sb $t3, 0($t2)
	addi $t1, $t1, 1
	addi $t2, $t2, 1
	addi $t0, $t0, -1
	j copiar_loop

atualiza_destino:
	move $s0, $t2          # atualiza s0 para próxima cópia
	j ler_loop

fechar_arquivo:
	move $a0, $s1
	li $v0, 16
	syscall

	# Calcular e salvar tamanho = $s0 - $s2
	# MAS APENAS para o primeiro arquivo (text)
	subu $t0, $s0, $s2
	la $t1, primeiro_arquivo
	lw $t2, 0($t1)
	beqz $t2, carregar_sem_salvar  # Se não é o primeiro arquivo, não salva

	la $t1, text_size
	sw $t0, 0($t1)

	# Marcar que já carregou o primeiro arquivo
	la $t1, primeiro_arquivo
	sw $zero, 0($t1)

carregar_sem_salvar:
	j carregar_fim

erro_arquivo:
	li $v0, 4
	la $a0, msg_erro_arquivo
	syscall
	# Não salvar tamanho se erro
	# Marcar que carregou mesmo assim
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
	la $t2, text_seg
	addu $t2, $t2, $t1
	lw $t3, 0($t2)
	la $t4, ir
	sw $t3, 0($t4)

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
	srl $t1, $t1, 26
	la $t0, opcode_store
	sw $t1, 0($t0)

	lw $ra, 0($sp)
	addiu $sp, $sp, 4
	jr $ra

executar:
	addiu $sp, $sp, -4
	sw $ra, 0($sp)

	la $t0, opcode_store
	lw $t1, 0($t0)

	# TODO: Implementar sub, and, or, andi, ori, bne, sll, srl e syscall, é bom adicionar mais mas enfim.
	beq $t1, $zero, exec_add
	li $t2, 8
	beq $t1, $t2, exec_addi
	li $t2, 35
	beq $t1, $t2, exec_lw
	li $t2, 43
	beq $t1, $t2, exec_sw
	li $t2, 4
	beq $t1, $t2, exec_beq
	li $t2, 2
	beq $t1, $t2, exec_j

	# --- Checkpoint: Instrução Desconhecida ---
	li $v0, 4
	la $a0, msg_instrunk
	syscall
	j exec_done

exec_add:
	la $t0, ir
	lw $t1, 0($t0)
	andi $t2, $t1, 0x3F      # funct

	li $t3, 12               # syscall
	beq $t2, $t3, exec_exit

	li $t3, 32               # add
	bne $t2, $t3, exec_done

	srl $t4, $t1, 21         # rs
	andi $t4, $t4, 0x1F
	srl $t5, $t1, 16         # rt
	andi $t5, $t5, 0x1F
	srl $t6, $t1, 11         # rd
	andi $t6, $t6, 0x1F

	# --- Checkpoint: ADD ---
	li $v0, 4
	la $a0, msg_add
	syscall
	li $v0, 1
	move $a0, $t6
	syscall
	li $v0, 4
	la $a0, msg_equals
	syscall

	la $t7, reg_file
	sll $t8, $t4, 2
	addu $t8, $t7, $t8
	lw $t9, 0($t8)
	sll $t4, $t5, 2
	addu $t4, $t7, $t4
	lw $t5, 0($t4)
	addu $t9, $t9, $t5
	sll $t6, $t6, 2
	addu $t6, $t7, $t6
	sw $t9, 0($t6)

	# Imprimir resultado
	li $v0, 34
	move $a0, $t9
	syscall
	li $v0, 4
	la $a0, msg_fim_linha
	syscall
	j exec_done

exec_exit:
	# --- Checkpoint: SYSCALL ---
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
	sll $t3, $t3, 2
	addu $t3, $t5, $t3
	sw $t6, 0($t3)

	# Imprimir resultado
	li $v0, 34
	move $a0, $t6
	syscall
	li $v0, 4
	la $a0, msg_fim_linha
	syscall
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
	sra $t4, $t4, 16

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
	lw $t6, 0($t2)

	la $t7, data_seg
	addu $t6, $t7, $t6
	addu $t6, $t6, $t4
	lw $t8, 0($t6)

	sll $t3, $t3, 2
	addu $t3, $t5, $t3
	sw $t8, 0($t3)

	# Imprimir resultado
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
	sra $t4, $t4, 16

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
	sll $t2, $t2, 2
	addu $t2, $t5, $t2
	lw $t6, 0($t2)

	la $t7, data_seg
	addu $t6, $t7, $t6
	addu $t6, $t6, $t4

	sll $t3, $t3, 2
	addu $t3, $t5, $t3
	lw $t8, 0($t3)
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
	lw $t6, 0($t2)
	sll $t3, $t3, 2
	addu $t3, $t5, $t3
	lw $t7, 0($t3)
	bne $t6, $t7, exec_done

	la $t8, pc
	lw $t9, 0($t8)
	sll $t4, $t4, 2
	addu $t9, $t9, $t4
	sw $t9, 0($t8)
	li $v0, 4
	la $a0, msg_fim_linha
	syscall
	j exec_done

exec_j:
	# --- Checkpoint: J ---
	li $v0, 4
	la $a0, msg_j
	syscall

	la $t0, ir
	lw $t1, 0($t0)
	andi $t2, $t1, 0x03FFFFFF
	sll $t2, $t2, 2
	la $t3, pc
	sw $t2, 0($t3)

	li $v0, 4
	la $a0, msg_fim_linha
	syscall
	j exec_done

exec_done:
	lw $ra, 0($sp)
	addiu $sp, $sp, 4
	jr $ra
