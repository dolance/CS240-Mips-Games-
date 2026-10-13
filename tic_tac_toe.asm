# CS 240 - MIPS Tic-Tac-Toe Game

.data 0x10010000
framebuffer: .space 4096         # 32 x 32 cells, 4 bytes per cell
board:       .byte 0,0,0,0,0,0,0,0,0  # 0 empty, 1 X, 2 O
win_lines:   .byte 0,1,2, 3,4,5, 6,7,8
             .byte 0,3,6, 1,4,7, 2,5,8
             .byte 0,4,8, 2,4,6

intro:       .asciiz "\nUse the MMIO Keyboard tool to press 1-9.\n1 2 3\n4 5 6\n7 8 9\nX is blue, O is red. Press R to restart, Q to quit.\n"
prompt_x:    .asciiz "\nPlayer X: choose a square (1-9): "
prompt_o:    .asciiz "\nPlayer O: choose a square (1-9): "
invalid_msg: .asciiz "\nInvalid key! Use numbers 1-9.\n"
occupied_msg: .asciiz "\nThat square is taken. Try another.\n"
x_wins_msg:  .asciiz "\nPlayer X wins!\n"
o_wins_msg:  .asciiz "\nPlayer O wins!\n"
tie_msg:     .asciiz "\nTie game! All nine squares are filled.\n"
end_msg:     .asciiz "Press R to play again, or Q to quit.\n"
restart_msg: .asciiz "\nStarting a new game!\n"
bye_msg:     .asciiz "\nThanks for playing!\n"

.text
.globl main

main:
    li $v0, 4
    la $a0, intro
    syscall

new_game:
    li $s0, 1                     # Current player: 1 X, 2 O
    li $s1, 0                     # Number of valid turns played
    jal reset_game               # Clear board and redraw the grid

turn_loop:
    li $v0, 4
    la $a0, prompt_x
    li $t0, 1
    beq $s0, $t0, print_prompt
    la $a0, prompt_o
print_prompt:
    syscall

    jal read_key                 # Read one key from MMIO ($v0)

    li $t0, 113                  # 'q'
    beq $v0, $t0, quit
    li $t0, 114                  # 'r'
    beq $v0, $t0, restart

    li $t0, 49                   # ASCII '1'
    blt $v0, $t0, bad_key
    li $t0, 57                   # ASCII '9'
    bgt $v0, $t0, bad_key

    addiu $s2, $v0, -49          # '1'..'9' -> board indexes 0..8
    move $a0, $s2
    jal place_move               # $v0 = 1 if square was empty
    beqz $v0, occupied

    move $a0, $s2
    jal draw_move                # Paint the X or O onto the display
    addiu $s1, $s1, 1
    jal check_winner             # $v0 = 1 X, 2 O, 0 no winner
    bnez $v0, winner_found

    li $t0, 9
    beq $s1, $t0, tie_found

    li $t0, 3
    subu $s0, $t0, $s0           # Switch 1 <-> 2
    j turn_loop

bad_key:
    li $v0, 4
    la $a0, invalid_msg
    syscall
    j turn_loop

occupied:
    li $v0, 4
    la $a0, occupied_msg
    syscall
    j turn_loop

winner_found:
    li $v0, 4
    la $a0, x_wins_msg
    li $t0, 1
    beq $s0, $t0, print_result
    la $a0, o_wins_msg
    j print_result

tie_found:
    li $v0, 4
    la $a0, tie_msg
print_result:
    syscall
    li $v0, 4
    la $a0, end_msg
    syscall

finished_loop:
    jal read_key
    li $t0, 113
    beq $v0, $t0, quit
    li $t0, 114
    beq $v0, $t0, restart
    j finished_loop

restart:
    li $v0, 4
    la $a0, restart_msg
    syscall
    j new_game

quit:
    li $v0, 4
    la $a0, bye_msg
    syscall
    li $v0, 10
    syscall

# read_key: wait for MMIO keyboard; return ASCII
# key in $v0 (uppercase letters become lowercase).

read_key:
    li $t0, 0xFFFF0000
read_key_wait:
    lw $t1, 0($t0)               # Keyboard control register
    andi $t1, $t1, 1             # Bit 0 = ready
    beqz $t1, read_key_wait
    lw $v0, 4($t0)               # Keyboard data register
    andi $v0, $v0, 0xFF
    ori $v0, $v0, 0x20           # Convert R/Q to r/q
    jr $ra

# reset_game: clear array and draw empty 3x3 grid.
# Calls draw_grid, so it saves return address.

reset_game:
    addiu $sp, $sp, -8
    sw $ra, 4($sp)
    la $t0, board
    li $t1, 9
reset_loop:
    sb $zero, 0($t0)
    addiu $t0, $t0, 1
    addiu $t1, $t1, -1
    bnez $t1, reset_loop
    jal draw_grid
    lw $ra, 4($sp)
    addiu $sp, $sp, 8
    jr $ra

# place_move: $a0=index 0..8; $v0=1 success, 0 taken.
# Board stores $s0 (1 X / 2 O) in chosen square.

place_move:
    la $t0, board
    addu $t0, $t0, $a0
    lbu $t1, 0($t0)
    bnez $t1, place_failed
    sb $s0, 0($t0)
    li $v0, 1
    jr $ra
place_failed:
    move $v0, $zero
    jr $ra

# check_winner: test 8 possible winning triples.
# Returns $v0=0 none, 1 X, 2 O.

check_winner:
    la $t0, win_lines
    la $t1, board
    li $t2, 8
check_line:
    lbu $t3, 0($t0)
    addu $t4, $t1, $t3
    lbu $t5, 0($t4)
    beqz $t5, next_line         # Can't win with an empty cell

    lbu $t3, 1($t0)
    addu $t4, $t1, $t3
    lbu $t6, 0($t4)
    bne $t5, $t6, next_line

    lbu $t3, 2($t0)
    addu $t4, $t1, $t3
    lbu $t6, 0($t4)
    bne $t5, $t6, next_line

    move $v0, $t5                # Found three matching pieces
    jr $ra
next_line:
    addiu $t0, $t0, 3
    addiu $t2, $t2, -1
    bnez $t2, check_line
    move $v0, $zero
    jr $ra

# draw_grid: fill a 32x32 bitmap with white cells.
# Black lines go across rows/columns 10 and 21.

draw_grid:
    la $t0, framebuffer
    li $t1, 0                     # y = 0
row_loop:
    li $t2, 0                     # x = 0
column_loop:
    li $t3, 10
    beq $t1, $t3, grid_black
    beq $t2, $t3, grid_black
    li $t3, 21
    beq $t1, $t3, grid_black
    beq $t2, $t3, grid_black
    li $t4, 0x00FFFFFF           # White background
    j grid_store
grid_black:
    li $t4, 0x00000000           # Black grid line
grid_store:
    sw $t4, 0($t0)
    addiu $t0, $t0, 4
    addiu $t2, $t2, 1
    slti $t5, $t2, 32
    bnez $t5, column_loop
    addiu $t1, $t1, 1
    slti $t5, $t1, 32
    bnez $t5, row_loop
    jr $ra

# draw_move: draw 6x6 X or O in selected board cell.
# $a0 = index 0..8, $s0 = player (1=X / 2=O).
# Draws X in blue or O in red.

draw_move:
    li $t0, 3
    div $a0, $t0
    mflo $t1                      # board row = index / 3
    mfhi $t2                      # board column = index % 3
    li $t0, 11
    mul $t3, $t2, $t0
    addiu $t3, $t3, 2             # x starts at 2, 13, 24
    mul $t4, $t1, $t0
    addiu $t4, $t4, 2             # y starts at 2, 13, 24

    li $t5, 0                    # local y, 0..5
move_row_loop:
    li $t6, 0                    # local x, 0..5
move_column_loop:
    li $t0, 1
    bne $s0, $t0, check_o

    # X: color diagonal x=y or x+y=5.
    beq $t5, $t6, paint_move
    addu $t7, $t5, $t6
    li $t8, 5
    beq $t7, $t8, paint_move
    j skip_pixel

check_o:
    # O: color the outer boundary of a 6x6 square.
    beqz $t5, paint_move
    li $t7, 5
    beq $t5, $t7, paint_move
    beqz $t6, paint_move
    beq $t6, $t7, paint_move
    j skip_pixel

paint_move:
    addu $t7, $t4, $t5           # absolute y
    sll $t7, $t7, 5              # y * 32
    addu $t7, $t7, $t3           # + starting x
    addu $t7, $t7, $t6           # + local x
    sll $t7, $t7, 2              # * 4 bytes / pixel
    la $t8, framebuffer
    addu $t8, $t8, $t7
    li $t9, 0x000066CC           # Blue X
    li $t0, 1
    beq $s0, $t0, store_move
    li $t9, 0x00E53935           # Red O
store_move:
    sw $t9, 0($t8)

skip_pixel:
    addiu $t6, $t6, 1
    slti $t7, $t6, 6
    bnez $t7, move_column_loop
    addiu $t5, $t5, 1
    slti $t7, $t5, 6
    bnez $t7, move_row_loop
    jr $ra
