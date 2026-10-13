# CS 240 - Custom Game: Tetris (MARS MIPS)
# Bitmap Display:
#   Unit width = 4, Unit height = 4
#   Display width = 256, Display height = 256
#   Base address = 0x10010000 (static data)
# Settings: delayed branching OFF, run at maximum speed.
# A/D = left/right; W = clockwise rotate; S = soft drop
# SPACE = hard drop; C = hold/swap; R = new game; Q = quit
# Falling speed is constant (650 ms per row).

.data 0x10010000
framebuffer: .space 16384                # 64 x 64 logical pixels, 4 bytes each

board:       .space 200                 # 10 columns x 20 rows, 0=empty, 1-7=piece
.align 2
current_type: .word 0                  # piece types 0..6
next_type:    .word 0
hold_type:    .word -1                  # -1 means hold slot is empty
hold_used:    .word 0                   # one hold allowed per falling piece
piece_x:      .word 3
piece_y:      .word 0
piece_rot:    .word 0                  # 0..3, clockwise
score:        .word 0
lines_total:  .word 0
best_score:   .word 0                  # best score since launching program
bag_index:    .word 7                  # 7 means the bag needs reshuffling
bag:          .space 28                # seven shuffled words, 0..6
game_over:    .word 0                  # 0=playing, 1=ended
last_fall:    .word 0                  # millisecond timestamp
last_input:   .word 0                  # last handled gameplay key
last_render:  .word 0                  # last screen update
redraw_pending: .word 0                  # deferred frame needed

# For each tetromino: 4 rotation masks; bit (row*4 + col) is occupied.
# I, O, T, S, Z, J, L
patterns:
    .word 0x00F0, 0x4444, 0x0F00, 0x2222    # I
    .word 0x0066, 0x0066, 0x0066, 0x0066    # O
    .word 0x0072, 0x04C4, 0x4E00, 0x2320    # T
    .word 0x0036, 0x08C4, 0x6C00, 0x2310    # S
    .word 0x0063, 0x04C8, 0xC600, 0x1320    # Z
    .word 0x0071, 0x044C, 0x8E00, 0x3220    # J
    .word 0x0074, 0x0C44, 0x2E00, 0x2230    # L

# 0 = blank; 1..7 = the seven tetromino colors.
palette:
    .word 0x00172131  # empty cell
    .word 0x0000D9F7  # I: cyan
    .word 0x00FFD83D  # O: yellow
    .word 0x00BD72F7  # T: purple
    .word 0x0056D96F  # S: green
    .word 0x00F15B62  # Z: red
    .word 0x004D8DF5  # J: blue
    .word 0x00FF9E45  # L: orange
    .word 0x004A5C77  # ghost: dim blue-gray

wall_kicks: .word 0, -1, 1, -2, 2

# Each upcoming shape gets a tiny pixel offset so its occupied
# blocks are visually centered inside the 12x12 preview area.
# Values are X,Y logical-pixel offsets for rotation 0.
# I, O, T, S, Z, J, L
preview_offsets:
    .word 0, 1   # I: 4 wide by 1 tall
    .word 0, 3   # O: 2 wide by 2 tall (already centered in X)
    .word 1, 3   # T
    .word 1, 3   # S
    .word 1, 3   # Z
    .word 1, 3   # J
    .word 1, 3   # L

# 3x5 bitmap digits. For each row, bits 2,1,0 are left,middle,right.
digits:
    .byte 7,5,5,5,7     # 0
    .byte 2,6,2,2,7     # 1
    .byte 7,1,7,4,7     # 2
    .byte 7,1,7,1,7     # 3
    .byte 5,5,7,1,1     # 4
    .byte 7,4,7,1,7     # 5
    .byte 7,4,7,5,7     # 6
    .byte 7,1,1,1,1     # 7
    .byte 7,5,7,5,7     # 8
    .byte 7,5,7,1,7     # 9

# Uppercase letters, each character has five 3-bit rows.
letters:
    .byte 2,5,7,5,5     # A
    .byte 6,5,6,5,6     # B
    .byte 7,4,4,4,7     # C
    .byte 6,5,5,5,6     # D
    .byte 7,4,6,4,7     # E
    .byte 7,4,6,4,4     # F
    .byte 7,4,5,5,7     # G
    .byte 5,5,7,5,5     # H
    .byte 7,2,2,2,7     # I
    .byte 1,1,1,5,7     # J
    .byte 5,5,6,5,5     # K
    .byte 4,4,4,4,7     # L
    .byte 5,7,7,5,5     # M
    .byte 5,7,7,7,5     # N
    .byte 7,5,5,5,7     # O
    .byte 6,5,6,4,4     # P
    .byte 7,5,5,7,3     # Q
    .byte 6,5,6,5,5     # R
    .byte 7,4,7,1,7     # S
    .byte 7,2,2,2,2     # T
    .byte 5,5,5,5,7     # U
    .byte 5,5,5,5,2     # V
    .byte 5,5,7,7,5     # W
    .byte 5,5,2,5,5     # X
    .byte 5,5,2,2,2     # Y
    .byte 7,1,2,4,7     # Z

hold_title:  .asciiz "HOLD"
next_title:  .asciiz "NEXT"
score_title: .asciiz "SCORE"
best_title:  .asciiz "BEST"
game_title:  .asciiz "GAME"
over_title:  .asciiz "OVER"

intro:       .asciiz "\nTETRIS (MIPS)\nA/D: move | W: rotate | S: down | SPACE: drop\nC: hold/swap | R: restart | Q: quit\n"
new_msg:     .asciiz "\nNew game! Score = 0\n"
clear_msg:   .asciiz "Lines cleared: "
score_msg:   .asciiz " | Score = "
end_msg:     .asciiz "\nGAME OVER! Final score = "
end_hint:    .asciiz "\nPress R to restart or Q to quit.\n"
newline:     .asciiz "\n"

.text
.globl main
main:
    li $v0, 4
    la $a0, intro
    syscall
    # Seed the random generator once with the current time.
    li $v0, 30
    syscall
    move $a1, $a0
    li $a0, 0
    li $v0, 40
    syscall
    jal restart_game

main_loop:
    jal poll_keyboard
    lw $t0, game_over
    bnez $t0, main_idle

    # Time-based gravity; keys are still polled between falling steps.
    li $v0, 30                       # MARS: current time in milliseconds
    syscall                          # low 32 bits returned in $a0
    lw $t0, last_fall
    subu $t1, $a0, $t0
    sltiu $t2, $t1, 650
    bnez $t2, main_idle
    sw $a0, last_fall

    li $a0, 0                        # dx = 0
    li $a1, 1                        # dy = +1
    jal try_move
    bnez $v0, gravity_draw
    jal lock_piece                   # landed: save piece, clear lines, spawn
    j main_idle

gravity_draw:
    jal render

main_idle:
    # Finish deferred drawing once the next frame is due.
    lw $t0, redraw_pending
    beqz $t0, idle_sleep
    jal render
idle_sleep:
    li $v0, 32                       # MARS sleep, prevents busy-spin
    li $a0, 15
    syscall
    j main_loop

# poll_keyboard: MMIO keyboard has a ready bit at 0xffff0000.
# Only one key is processed per polling pass.
poll_keyboard:
    addiu $sp, $sp, -8
    sw $ra, 4($sp)
    li $t0, 0xFFFF0000
    lw $t1, 0($t0)
    andi $t1, $t1, 1
    beqz $t1, keyboard_done
    lw $t2, 4($t0)
    andi $t2, $t2, 0xFF
    ori $t2, $t2, 0x20               # convert uppercase letter to lowercase

    li $t3, 113                      # q
    beq $t2, $t3, quit
    li $t3, 114                      # r
    beq $t2, $t3, key_restart

    lw $t3, game_over
    bnez $t3, keyboard_done

    # Limit repeated gameplay inputs to about 25 per second.
    li $v0, 30
    syscall
    lw $t4, last_input
    subu $t5, $a0, $t4
    sltiu $t6, $t5, 40
    bnez $t6, keyboard_done
    sw $a0, last_input

    li $t3, 97                       # a
    beq $t2, $t3, key_left
    li $t3, 100                      # d
    beq $t2, $t3, key_right
    li $t3, 119                      # w
    beq $t2, $t3, key_rotate
    li $t3, 115                      # s
    beq $t2, $t3, key_down
    li $t3, 99                       # c
    beq $t2, $t3, key_hold
    li $t3, 32                       # space
    beq $t2, $t3, key_hard_drop
    j keyboard_done                  # invalid keys do not change the game

key_restart:
    jal restart_game
    j keyboard_done
key_left:
    li $a0, -1
    li $a1, 0
    jal try_move
    jal render
    j keyboard_done
key_right:
    li $a0, 1
    li $a1, 0
    jal try_move
    jal render
    j keyboard_done
key_rotate:
    jal try_rotate
    jal render
    j keyboard_done
key_down:
    li $a0, 0
    li $a1, 1
    jal try_move
    bnez $v0, down_valid
    jal lock_piece
    j keyboard_done
down_valid:
    jal render
    j keyboard_done
# Holding is allowed once until this piece is locked.
key_hold:
    lw $t0, hold_used
    bnez $t0, keyboard_done
    lw $t0, hold_type
    bgez $t0, hold_swap

    # First hold stores the piece and consumes the next piece.
    lw $t1, current_type
    sw $t1, hold_type
    jal spawn_piece
    li $t0, 1
    sw $t0, hold_used
    jal render
    jal render_panel
    j keyboard_done

hold_swap:
    # Swapping does not consume another piece from the bag.
    lw $t1, current_type
    sw $t0, current_type
    sw $t1, hold_type
    li $t0, 1
    sw $t0, hold_used
    jal reset_active_piece
    jal render
    jal render_panel
    j keyboard_done

key_hard_drop:
hard_drop_loop:
    li $a0, 0
    li $a1, 1
    jal try_move
    bnez $v0, hard_drop_loop
    jal lock_piece

keyboard_done:
    lw $ra, 4($sp)
    addiu $sp, $sp, 8
    jr $ra

quit:
    li $v0, 10
    syscall

# next_from_bag returns the next piece in a shuffled seven-piece set.
next_from_bag:
    addiu $sp, $sp, -8
    sw $ra, 4($sp)
    lw $t0, bag_index
    slti $t1, $t0, 7
    bnez $t1, take_bag_piece
    jal shuffle_bag

take_bag_piece:
    lw $t0, bag_index
    sll $t1, $t0, 2
    la $t2, bag
    addu $t2, $t2, $t1
    lw $v0, 0($t2)
    addiu $t0, $t0, 1
    sw $t0, bag_index
    lw $ra, 4($sp)
    addiu $sp, $sp, 8
    jr $ra

# Fisher-Yates shuffle ensures every group of seven uses all shapes.
shuffle_bag:
    addiu $sp, $sp, -20
    sw $ra, 16($sp)
    sw $s0, 0($sp)
    sw $s1, 4($sp)
    sw $s2, 8($sp)
    li $s0, 0
    la $s1, bag

bag_fill_loop:
    sll $t0, $s0, 2
    addu $t0, $t0, $s1
    sw $s0, 0($t0)
    addiu $s0, $s0, 1
    slti $t1, $s0, 7
    bnez $t1, bag_fill_loop

    li $s0, 6
bag_shuffle_loop:
    beqz $s0, bag_shuffled
    li $v0, 42
    li $a0, 0
    addiu $a1, $s0, 1
    syscall                         # random j in 0..i
    move $s2, $a0
    sll $t0, $s0, 2
    addu $t0, $t0, $s1
    sll $t1, $s2, 2
    addu $t1, $t1, $s1
    lw $t2, 0($t0)
    lw $t3, 0($t1)
    sw $t3, 0($t0)
    sw $t2, 0($t1)
    addiu $s0, $s0, -1
    j bag_shuffle_loop

bag_shuffled:
    sw $zero, bag_index
    lw $s0, 0($sp)
    lw $s1, 4($sp)
    lw $s2, 8($sp)
    lw $ra, 16($sp)
    addiu $sp, $sp, 20
    jr $ra

# restart_game: reset board/state and begin with new random pieces.
restart_game:
    addiu $sp, $sp, -8
    sw $ra, 4($sp)
    la $t0, board
    li $t1, 200
restart_clear:
    sb $zero, 0($t0)
    addiu $t0, $t0, 1
    addiu $t1, $t1, -1
    bnez $t1, restart_clear
    sw $zero, score
    sw $zero, lines_total
    sw $zero, game_over
    sw $zero, hold_used
    sw $zero, last_input
    sw $zero, last_render
    sw $zero, redraw_pending
    li $t0, -1
    sw $t0, hold_type
    li $t0, 7
    sw $t0, bag_index              # new game starts with a fresh bag
    jal next_from_bag
    sw $v0, next_type
    jal spawn_piece
    li $v0, 4
    la $a0, new_msg
    syscall
    jal clear_screen
    jal render
    jal render_panel
    lw $ra, 4($sp)
    addiu $sp, $sp, 8
    jr $ra

# Promote the next piece from the seven-piece bag.
spawn_piece:
    addiu $sp, $sp, -8
    sw $ra, 4($sp)
    lw $t0, next_type
    sw $t0, current_type
    jal next_from_bag
    sw $v0, next_type
    jal reset_active_piece
    lw $ra, 4($sp)
    addiu $sp, $sp, 8
    jr $ra

# Reset a spawned or swapped-in piece to its default position.
reset_active_piece:
    addiu $sp, $sp, -8
    sw $ra, 4($sp)
    li $t0, 3
    sw $t0, piece_x
    sw $zero, piece_y
    sw $zero, piece_rot
    li $v0, 30
    syscall
    sw $a0, last_fall

    lw $a0, piece_x
    lw $a1, piece_y
    lw $a2, piece_rot
    lw $a3, current_type
    jal is_valid
    bnez $v0, reset_active_done
    li $t0, 1
    sw $t0, game_over
    li $v0, 4
    la $a0, end_msg
    syscall
    li $v0, 1
    lw $a0, score
    syscall
    li $v0, 4
    la $a0, end_hint
    syscall
reset_active_done:
    lw $ra, 4($sp)
    addiu $sp, $sp, 8
    jr $ra

# is_valid($a0=x, $a1=y, $a2=rotation, $a3=type)
# Returns $v0=1 if no occupied minos hit walls/floor/locked blocks.
# This routine uses $t registers but never modifies $a registers.
is_valid:
    sll $t0, $a3, 2                 # pattern index = type*4 + rotation
    addu $t0, $t0, $a2
    sll $t0, $t0, 2
    la $t1, patterns
    addu $t0, $t0, $t1
    lw $t0, 0($t0)                  # 16-bit shape occupancy mask
    li $t1, 0                       # index 0..15
valid_loop:
    andi $t2, $t0, 1
    beqz $t2, valid_next
    andi $t3, $t1, 3                # local column
    srl $t4, $t1, 2                 # local row
    addu $t5, $a0, $t3            # board column
    addu $t6, $a1, $t4            # board row
    bltz $t5, invalid
    bltz $t6, invalid
    slti $t7, $t5, 10
    beqz $t7, invalid
    slti $t7, $t6, 20
    beqz $t7, invalid
    # board index = y*10+x
    sll $t7, $t6, 3
    sll $t8, $t6, 1
    addu $t7, $t7, $t8
    addu $t7, $t7, $t5
    la $t8, board
    addu $t8, $t8, $t7
    lbu $t9, 0($t8)
    bnez $t9, invalid
valid_next:
    srl $t0, $t0, 1
    addiu $t1, $t1, 1
    slti $t2, $t1, 16
    bnez $t2, valid_loop
    li $v0, 1
    jr $ra
invalid:
    li $v0, 0
    jr $ra

# try_move($a0=dx,$a1=dy): move only if the proposed piece fits.
# Returns $v0=1 on success, 0 if blocked.
try_move:
    addiu $sp, $sp, -16
    sw $ra, 12($sp)
    lw $t0, piece_x
    addu $t0, $t0, $a0
    sw $t0, 0($sp)
    lw $t1, piece_y
    addu $t1, $t1, $a1
    sw $t1, 4($sp)
    move $a0, $t0
    move $a1, $t1
    lw $a2, piece_rot
    lw $a3, current_type
    jal is_valid
    beqz $v0, move_done
    lw $t0, 0($sp)
    lw $t1, 4($sp)
    sw $t0, piece_x
    sw $t1, piece_y
move_done:
    lw $ra, 12($sp)
    addiu $sp, $sp, 16
    jr $ra

# try_rotate: rotate clockwise; try x offset 0, -1, +1, -2, +2.
# A basic wall-kick lets pieces rotate near the sides.
try_rotate:
    addiu $sp, $sp, -24
    sw $ra, 20($sp)
    lw $t0, piece_rot
    addiu $t0, $t0, 1
    andi $t0, $t0, 3
    sw $t0, 0($sp)                 # proposed rotation
    sw $zero, 4($sp)              # kick index
rotate_loop:
    lw $t0, 4($sp)
    slti $t1, $t0, 5
    beqz $t1, rotate_failed
    sll $t0, $t0, 2
    la $t1, wall_kicks
    addu $t1, $t1, $t0
    lw $t2, 0($t1)
    lw $t3, piece_x
    addu $a0, $t3, $t2
    sw $a0, 8($sp)
    lw $a1, piece_y
    lw $a2, 0($sp)
    lw $a3, current_type
    jal is_valid
    beqz $v0, rotate_retry
    lw $t0, 8($sp)
    sw $t0, piece_x
    lw $t0, 0($sp)
    sw $t0, piece_rot
    li $v0, 1
    j rotate_done
rotate_retry:
    lw $t0, 4($sp)
    addiu $t0, $t0, 1
    sw $t0, 4($sp)
    j rotate_loop
rotate_failed:
    li $v0, 0
rotate_done:
    lw $ra, 20($sp)
    addiu $sp, $sp, 24
    jr $ra

# lock_piece: copy active piece into board; clear full lines;
# spawn the next piece; redraw the result.
lock_piece:
    addiu $sp, $sp, -8
    sw $ra, 4($sp)
    lw $t0, current_type
    sll $t0, $t0, 2
    lw $t1, piece_rot
    addu $t0, $t0, $t1
    sll $t0, $t0, 2
    la $t1, patterns
    addu $t0, $t0, $t1
    lw $t0, 0($t0)
    li $t1, 0
    lw $t9, current_type
    addiu $t9, $t9, 1
lock_loop:
    andi $t2, $t0, 1
    beqz $t2, lock_next
    andi $t3, $t1, 3
    srl $t4, $t1, 2
    lw $t5, piece_x
    lw $t6, piece_y
    addu $t5, $t5, $t3
    addu $t6, $t6, $t4
    bltz $t5, lock_next
    bltz $t6, lock_next
    slti $t7, $t5, 10
    beqz $t7, lock_next
    slti $t7, $t6, 20
    beqz $t7, lock_next
    sll $t7, $t6, 3
    sll $t8, $t6, 1
    addu $t7, $t7, $t8
    addu $t7, $t7, $t5
    la $t8, board
    addu $t8, $t8, $t7
    sb $t9, 0($t8)
lock_next:
    srl $t0, $t0, 1
    addiu $t1, $t1, 1
    slti $t2, $t1, 16
    bnez $t2, lock_loop

    jal clear_lines
    sw $zero, hold_used              # the next piece may be held again
    jal spawn_piece
    jal render
    jal render_panel
    lw $ra, 4($sp)
    addiu $sp, $sp, 8
    jr $ra

# clear_lines: scan bottom-up. When full, shift every row above down.
# Recheck the same row afterward (supports multi-line clears).
# Award 100/300/500/800 for clearing 1/2/3/4 at once.
clear_lines:
    addiu $sp, $sp, -8
    sw $ra, 4($sp)
    li $t0, 19                      # row being tested
    li $t9, 0                       # rows cleared on this lock
check_row:
    bltz $t0, lines_finished
    sll $t2, $t0, 3
    sll $t3, $t0, 1
    addu $t2, $t2, $t3
    la $t3, board
    addu $t3, $t3, $t2
    li $t4, 0
check_cells:
    lbu $t5, 0($t3)
    beqz $t5, row_not_full
    addiu $t3, $t3, 1
    addiu $t4, $t4, 1
    slti $t5, $t4, 10
    bnez $t5, check_cells
    # Full row: shift all rows above it downward by one.
    move $t6, $t0
shift_rows:
    beqz $t6, clear_top
    sll $t7, $t6, 3
    sll $t8, $t6, 1
    addu $t7, $t7, $t8
    la $t8, board
    addu $t7, $t7, $t8            # destination row pointer
    addiu $t8, $t7, -10          # source row pointer
    li $t4, 10
copy_row:
    lbu $t5, 0($t8)
    sb $t5, 0($t7)
    addiu $t7, $t7, 1
    addiu $t8, $t8, 1
    addiu $t4, $t4, -1
    bnez $t4, copy_row
    addiu $t6, $t6, -1
    j shift_rows
clear_top:
    la $t7, board
    li $t4, 10
zero_top:
    sb $zero, 0($t7)
    addiu $t7, $t7, 1
    addiu $t4, $t4, -1
    bnez $t4, zero_top
    addiu $t9, $t9, 1
    j check_row                      # check shifted-down row again
row_not_full:
    addiu $t0, $t0, -1
    j check_row

lines_finished:
    beqz $t9, lines_done
    lw $t0, lines_total
    addu $t0, $t0, $t9
    sw $t0, lines_total
    li $t0, 100
    li $t1, 1
    beq $t9, $t1, add_score
    li $t0, 300
    li $t1, 2
    beq $t9, $t1, add_score
    li $t0, 500
    li $t1, 3
    beq $t9, $t1, add_score
    li $t0, 800                  # 4 lines
add_score:
    lw $t1, score
    addu $t1, $t1, $t0
    sw $t1, score
    lw $t2, best_score
    slt $t3, $t2, $t1
    beqz $t3, best_unchanged
    sw $t1, best_score
best_unchanged:
    sw $t9, 0($sp)               # syscalls are not expected to keep $t9
    li $v0, 4
    la $a0, clear_msg
    syscall
    li $v0, 1
    lw $a0, 0($sp)
    syscall
    li $v0, 4
    la $a0, score_msg
    syscall
    li $v0, 1
    lw $a0, score
    syscall
    li $v0, 4
    la $a0, newline
    syscall
lines_done:
    lw $ra, 4($sp)
    addiu $sp, $sp, 8
    jr $ra

# Clear the whole display only when starting or restarting.
clear_screen:
    la $t0, framebuffer
    li $t1, 4096
    li $t2, 0x000B1020
clear_screen_loop:
    sw $t2, 0($t0)
    addiu $t0, $t0, 4
    addiu $t1, $t1, -1
    bnez $t1, clear_screen_loop
    jr $ra

# Limit full playfield redraws to about ten frames per second.
# Keep pending frames so the final input is always drawn.
render:
    li $v0, 30
    syscall
    lw $t0, last_render
    subu $t1, $a0, $t0
    sltiu $t2, $t1, 100
    bnez $t2, render_wait
    sw $a0, last_render
    sw $zero, redraw_pending
    j render_now
render_wait:
    li $t0, 1
    sw $t0, redraw_pending
    jr $ra
render_now:
    addiu $sp, $sp, -32
    sw $ra, 28($sp)
    sw $s0, 0($sp)
    sw $s1, 4($sp)
    sw $s2, 8($sp)
    sw $s3, 12($sp)
    sw $s4, 16($sp)
    sw $s5, 20($sp)

    # Every board cell is painted, so the previous active piece is erased.
    # Draw the 200 board cells, including occupied colors.
    li $s0, 0
render_row:
    li $s1, 0
render_column:
    sll $t0, $s0, 3
    sll $t1, $s0, 1
    addu $t0, $t0, $t1
    addu $t0, $t0, $s1
    la $t1, board
    addu $t0, $t0, $t1
    lbu $a2, 0($t0)
    move $a0, $s1
    move $a1, $s0
    jal paint_board_cell
    addiu $s1, $s1, 1
    slti $t0, $s1, 10
    bnez $t0, render_column
    addiu $s0, $s0, 1
    slti $t0, $s0, 20
    bnez $t0, render_row

    # Draw a dim landing guide underneath the active piece.
    lw $t0, game_over
    bnez $t0, skip_active_piece
    jal draw_ghost

    # Draw current falling piece over the settled board.
    lw $t0, current_type
    sll $t0, $t0, 2
    lw $t1, piece_rot
    addu $t0, $t0, $t1
    sll $t0, $t0, 2
    la $t1, patterns
    addu $t0, $t0, $t1
    lw $s2, 0($t0)               # shape mask
    li $s0, 0                    # local bit index
    lw $s4, current_type
    addiu $s4, $s4, 1            # palette index
active_draw_loop:
    andi $t0, $s2, 1
    beqz $t0, active_draw_next
    andi $t0, $s0, 3
    srl $t1, $s0, 2
    lw $t2, piece_x
    lw $t3, piece_y
    addu $a0, $t2, $t0
    addu $a1, $t3, $t1
    move $a2, $s4
    jal paint_board_cell
active_draw_next:
    srl $s2, $s2, 1
    addiu $s0, $s0, 1
    slti $t0, $s0, 16
    bnez $t0, active_draw_loop

skip_active_piece:
    lw $t0, game_over
    beqz $t0, render_complete
    jal draw_game_over
render_complete:
    lw $s0, 0($sp)
    lw $s1, 4($sp)
    lw $s2, 8($sp)
    lw $s3, 12($sp)
    lw $s4, 16($sp)
    lw $s5, 20($sp)
    lw $ra, 28($sp)
    addiu $sp, $sp, 32
    jr $ra

# Update NEXT, HOLD, SCORE, and BEST only when their values change.
render_panel:
    addiu $sp, $sp, -8
    sw $ra, 4($sp)
    # Erase just the right-side panel to prevent old digits remaining.
    la $t0, framebuffer
    addiu $t0, $t0, 152            # panel begins at column 38
    li $t1, 64
panel_clear_row:
    move $t2, $t0
    li $t3, 26                     # columns 38 through 63
    li $t4, 0x000B1020
panel_clear_column:
    sw $t4, 0($t2)
    addiu $t2, $t2, 4
    addiu $t3, $t3, -1
    bnez $t3, panel_clear_column
    addiu $t0, $t0, 256           # next 64-pixel row
    addiu $t1, $t1, -1
    bnez $t1, panel_clear_row

    # Draw NEXT above HOLD in the right panel.
    la $a0, next_title
    li $a1, 42
    li $a2, 1
    jal draw_text
    lw $a0, next_type
    li $a1, 42
    li $a2, 8
    jal draw_preview

    la $a0, hold_title
    li $a1, 42
    li $a2, 22
    jal draw_text
    lw $a0, hold_type
    li $a1, 42
    li $a2, 29
    jal draw_preview

    jal draw_score
    jal draw_best_score
    lw $ra, 4($sp)
    addiu $sp, $sp, 8
    jr $ra

# Draw a 4x4 preview. $a0=type (-1 for empty), $a1=x, $a2=y.
draw_preview:
    addiu $sp, $sp, -40
    sw $ra, 36($sp)
    sw $s0, 0($sp)
    sw $s1, 4($sp)
    sw $s2, 8($sp)
    sw $s3, 12($sp)
    sw $s4, 16($sp)
    sw $s5, 20($sp)
    move $s0, $a0
    move $s1, $a1
    move $s2, $a2
    li $s3, 0

preview_background_loop:
    andi $t0, $s3, 3
    srl $t1, $s3, 2
    sll $t2, $t0, 1
    addu $a0, $t0, $t2
    addu $a0, $a0, $s1
    sll $t2, $t1, 1
    addu $a1, $t1, $t2
    addu $a1, $a1, $s2
    li $a2, 0
    jal paint_block
    addiu $s3, $s3, 1
    slti $t0, $s3, 16
    bnez $t0, preview_background_loop
    bltz $s0, preview_finished

    sll $t0, $s0, 4               # rotation zero pattern
    la $t1, patterns
    addu $t1, $t1, $t0
    lw $s4, 0($t1)
    addiu $s5, $s0, 1            # color number
    sll $t0, $s0, 3
    la $t1, preview_offsets
    addu $t1, $t1, $t0
    lw $t2, 0($t1)
    lw $t3, 4($t1)
    sw $t2, 24($sp)              # horizontal centering
    sw $t3, 28($sp)              # vertical centering
    li $s3, 0

preview_piece_loop:
    andi $t0, $s4, 1
    beqz $t0, preview_piece_next
    andi $t0, $s3, 3
    srl $t1, $s3, 2
    sll $t2, $t0, 1
    addu $a0, $t0, $t2
    addu $a0, $a0, $s1
    lw $t2, 24($sp)
    addu $a0, $a0, $t2
    sll $t2, $t1, 1
    addu $a1, $t1, $t2
    addu $a1, $a1, $s2
    lw $t2, 28($sp)
    addu $a1, $a1, $t2
    move $a2, $s5
    jal paint_block
preview_piece_next:
    srl $s4, $s4, 1
    addiu $s3, $s3, 1
    slti $t0, $s3, 16
    bnez $t0, preview_piece_loop

preview_finished:
    lw $s0, 0($sp)
    lw $s1, 4($sp)
    lw $s2, 8($sp)
    lw $s3, 12($sp)
    lw $s4, 16($sp)
    lw $s5, 20($sp)
    lw $ra, 36($sp)
    addiu $sp, $sp, 40
    jr $ra

# Draw the current piece at its lowest valid landing position.
draw_ghost:
    addiu $sp, $sp, -24
    sw $ra, 20($sp)
    sw $s0, 0($sp)
    sw $s1, 4($sp)
    sw $s2, 8($sp)
    sw $s3, 12($sp)
    sw $s4, 16($sp)

    lw $s0, piece_y
ghost_fall:
    lw $a0, piece_x
    addiu $a1, $s0, 1
    lw $a2, piece_rot
    lw $a3, current_type
    jal is_valid
    beqz $v0, ghost_landed
    addiu $s0, $s0, 1
    j ghost_fall

ghost_landed:
    lw $t0, piece_y
    beq $s0, $t0, ghost_done
    lw $t0, current_type
    sll $t0, $t0, 2
    lw $t1, piece_rot
    addu $t0, $t0, $t1
    sll $t0, $t0, 2
    la $t1, patterns
    addu $t0, $t0, $t1
    lw $s2, 0($t0)
    li $s1, 0

ghost_cell_loop:
    andi $t0, $s2, 1
    beqz $t0, ghost_next_cell
    andi $t0, $s1, 3
    srl $t1, $s1, 2
    lw $t2, piece_x
    addu $a0, $t2, $t0
    addu $a1, $s0, $t1
    li $a2, 8                    # dim ghost color
    jal paint_board_cell
ghost_next_cell:
    srl $s2, $s2, 1
    addiu $s1, $s1, 1
    slti $t0, $s1, 16
    bnez $t0, ghost_cell_loop

ghost_done:
    lw $s0, 0($sp)
    lw $s1, 4($sp)
    lw $s2, 8($sp)
    lw $s3, 12($sp)
    lw $s4, 16($sp)
    lw $ra, 20($sp)
    addiu $sp, $sp, 24
    jr $ra

# paint_board_cell($a0=col,$a1=row,$a2=palette index)
# Convert board grid coordinates into 64x64 framebuffer pixels.
paint_board_cell:
    addiu $sp, $sp, -8
    sw $ra, 4($sp)
    sll $t0, $a0, 1
    addu $a0, $a0, $t0
    addiu $a0, $a0, 3
    sll $t1, $a1, 1
    addu $a1, $a1, $t1
    addiu $a1, $a1, 2
    jal paint_block
    lw $ra, 4($sp)
    addiu $sp, $sp, 8
    jr $ra

# paint_block($a0=x,$a1=y,$a2=palette index)
# Draw a 3x3 tile (2x2 colored interior, 1px dark outline).
paint_block:
    # Never write outside the 64 by 64 framebuffer.
    bltz $a0, paint_block_done
    bltz $a1, paint_block_done
    slti $t9, $a0, 62
    beqz $t9, paint_block_done
    slti $t9, $a1, 62
    beqz $t9, paint_block_done
    sltiu $t9, $a2, 9
    beqz $t9, paint_block_done
    sll $t0, $a2, 2
    la $t1, palette
    addu $t1, $t1, $t0
    lw $t2, 0($t1)                # color
    li $t3, 0x002B354A          # outer grid line color
    li $t4, 0                   # dy
paint_row:
    li $t5, 0                   # dx
paint_col:
    slti $t6, $t4, 2
    beqz $t6, paint_border
    slti $t6, $t5, 2
    beqz $t6, paint_border
    move $t6, $t2
    j paint_store
paint_border:
    move $t6, $t3
paint_store:
    addu $t7, $a1, $t4
    sll $t7, $t7, 6
    addu $t8, $a0, $t5
    addu $t7, $t7, $t8
    sll $t7, $t7, 2
    la $t8, framebuffer
    addu $t8, $t8, $t7
    sw $t6, 0($t8)
    addiu $t5, $t5, 1
    slti $t7, $t5, 3
    bnez $t7, paint_col
    addiu $t4, $t4, 1
    slti $t7, $t4, 3
    bnez $t7, paint_row
paint_block_done:
    jr $ra

# Score and best score share the same five-digit renderer.
draw_score:
    addiu $sp, $sp, -8
    sw $ra, 4($sp)
    la $a0, score_title
    li $a1, 40
    li $a2, 42
    jal draw_text
    lw $a0, score
    li $a1, 40
    li $a2, 48
    jal draw_number
    lw $ra, 4($sp)
    addiu $sp, $sp, 8
    jr $ra

draw_best_score:
    addiu $sp, $sp, -8
    sw $ra, 4($sp)
    la $a0, best_title
    li $a1, 42
    li $a2, 54
    jal draw_text
    lw $a0, best_score
    li $a1, 40
    li $a2, 59
    jal draw_number
    lw $ra, 4($sp)
    addiu $sp, $sp, 8
    jr $ra

# Draw the last five digits of a nonnegative number at (x,y).
draw_number:
    addiu $sp, $sp, -24
    sw $ra, 20($sp)
    sw $s0, 0($sp)
    sw $s1, 4($sp)
    sw $s2, 8($sp)
    sw $s3, 12($sp)
    move $s0, $a0
    move $s1, $a1
    move $s3, $a2
    li $t0, 100000
    divu $s0, $t0
    mfhi $s0
    li $s2, 10000
number_digit_loop:
    divu $s0, $s2
    mflo $a2
    mfhi $s0
    move $a0, $s1
    move $a1, $s3
    jal paint_digit
    addiu $s1, $s1, 4
    li $t0, 10
    divu $s2, $t0
    mflo $s2
    bnez $s2, number_digit_loop
    lw $s0, 0($sp)
    lw $s1, 4($sp)
    lw $s2, 8($sp)
    lw $s3, 12($sp)
    lw $ra, 20($sp)
    addiu $sp, $sp, 24
    jr $ra

# Draw a dark panel over the board when the stack reaches the top.
draw_game_over:
    addiu $sp, $sp, -16
    sw $ra, 12($sp)
    sw $s0, 0($sp)
    sw $s1, 4($sp)
    li $s0, 23
panel_row:
    li $s1, 5
panel_column:
    sll $t0, $s0, 6
    addu $t0, $t0, $s1
    sll $t0, $t0, 2
    la $t1, framebuffer
    addu $t1, $t1, $t0
    li $t2, 0x00121B30
    li $t3, 23
    beq $s0, $t3, panel_edge
    li $t3, 42
    beq $s0, $t3, panel_edge
    li $t3, 5
    beq $s1, $t3, panel_edge
    li $t3, 30
    bne $s1, $t3, panel_write
panel_edge:
    li $t2, 0x006B809F
panel_write:
    sw $t2, 0($t1)
    addiu $s1, $s1, 1
    slti $t0, $s1, 31
    bnez $t0, panel_column
    addiu $s0, $s0, 1
    slti $t0, $s0, 43
    bnez $t0, panel_row
    la $a0, game_title
    li $a1, 10
    li $a2, 27
    jal draw_text
    la $a0, over_title
    li $a1, 10
    li $a2, 35
    jal draw_text
    lw $s0, 0($sp)
    lw $s1, 4($sp)
    lw $ra, 12($sp)
    addiu $sp, $sp, 16
    jr $ra

# Print uppercase labels using three-by-five bitmap letters.
draw_text:
    addiu $sp, $sp, -24
    sw $ra, 20($sp)
    sw $s0, 0($sp)
    sw $s1, 4($sp)
    sw $s2, 8($sp)
    move $s0, $a0
    move $s1, $a1
    move $s2, $a2
text_loop:
    lbu $t0, 0($s0)
    beqz $t0, text_done
    move $a0, $s1
    move $a1, $s2
    move $a2, $t0
    jal paint_letter
    addiu $s0, $s0, 1
    addiu $s1, $s1, 4
    j text_loop
text_done:
    lw $s0, 0($sp)
    lw $s1, 4($sp)
    lw $s2, 8($sp)
    lw $ra, 20($sp)
    addiu $sp, $sp, 24
    jr $ra

# Paint one ASCII uppercase letter at framebuffer position (x,y).
paint_letter:
    addiu $t0, $a2, -65
    bltz $t0, letter_done
    slti $t1, $t0, 26
    beqz $t1, letter_done
    sll $t1, $t0, 2
    addu $t1, $t1, $t0
    la $t2, letters
    addu $t1, $t1, $t2
    li $t2, 0
letter_row:
    lbu $t3, 0($t1)
    li $t4, 0
letter_column:
    li $t5, 2
    subu $t5, $t5, $t4
    srlv $t6, $t3, $t5
    andi $t6, $t6, 1
    beqz $t6, letter_skip
    addu $t7, $a1, $t2
    sll $t7, $t7, 6
    addu $t8, $a0, $t4
    addu $t7, $t7, $t8
    sll $t7, $t7, 2
    la $t8, framebuffer
    addu $t8, $t8, $t7
    li $t9, 0x00F1F5FF
    sw $t9, 0($t8)
letter_skip:
    addiu $t4, $t4, 1
    slti $t5, $t4, 3
    bnez $t5, letter_column
    addiu $t1, $t1, 1
    addiu $t2, $t2, 1
    slti $t5, $t2, 5
    bnez $t5, letter_row
letter_done:
    jr $ra

# paint_digit($a0=x,$a1=y,$a2=digit): 3x5 bright bitmap numeral.
paint_digit:
    sll $t0, $a2, 2
    addu $t0, $t0, $a2           # digit * 5
    la $t1, digits
    addu $t1, $t1, $t0
    li $t2, 0                   # row
paint_digit_row:
    lbu $t3, 0($t1)              # three-bit row
    li $t4, 0                   # col
paint_digit_col:
    li $t5, 2
    subu $t5, $t5, $t4
    srlv $t6, $t3, $t5
    andi $t6, $t6, 1
    beqz $t6, paint_digit_skip
    addu $t7, $a1, $t2
    sll $t7, $t7, 6
    addu $t8, $a0, $t4
    addu $t7, $t7, $t8
    sll $t7, $t7, 2
    la $t8, framebuffer
    addu $t8, $t8, $t7
    li $t9, 0x00F1F5FF
    sw $t9, 0($t8)
paint_digit_skip:
    addiu $t4, $t4, 1
    slti $t5, $t4, 3
    bnez $t5, paint_digit_col
    addiu $t1, $t1, 1
    addiu $t2, $t2, 1
    slti $t5, $t2, 5
    bnez $t5, paint_digit_row
    jr $ra
