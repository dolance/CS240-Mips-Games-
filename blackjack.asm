# CS 240 - Blackjack for MARS 4.5
# One player vs. dealer. No betting, splitting, or doubling down.
# Full shuffled 52-card deck: four each of A,2,3,...,10,J,Q,K.
# Ace counts as 11 unless that would bust (then 1).
# Dealer stands on all 17s, including soft 17.
#
# Bitmap Display settings:
#   Unit Width / Height: 4 / 4 pixels
#   Display Width / Height: 256 / 256 pixels
#   Base address: 0x10010000 (static data)
# Connect both Bitmap Display and Keyboard and Display MMIO Simulator.
# Type H=hit, S=stand, R=restart, Q=quit in MMIO keyboard.
# Delayed branching OFF; run at maximum speed.

.data 0x10010000
framebuffer: .space 16384          # 64 x 64 logical units x 4 bytes
.align 2
deck:        .space 208            # 52 words, one for each card rank
player_hand: .space 52             # At most 52 cards (one byte per card)
dealer_hand: .space 52
player_count: .word 0
dealer_count: .word 0
hide_hole:   .word 1               # 1 hides dealer's second card

# Five bitmap rows per rank. 3-bit-wide monochrome glyphs.
# Rank 1=A; 2-9=digits; 10=T; 11=J; 12=Q; 13=K.
glyphs:
    .byte 2,5,7,5,5  # A
    .byte 7,1,7,4,7  # 2
    .byte 7,1,7,1,7  # 3
    .byte 5,5,7,1,1  # 4
    .byte 7,4,7,1,7  # 5
    .byte 7,4,7,5,7  # 6
    .byte 7,1,1,1,1  # 7
    .byte 7,5,7,5,7  # 8
    .byte 7,5,7,1,7  # 9
    .byte 7,2,2,2,2  # T (10)
    .byte 1,1,1,5,7  # J
    .byte 7,5,5,7,1  # Q
    .byte 5,5,6,5,5  # K

card_names:
    .word name_A,name_2,name_3,name_4,name_5,name_6,name_7
    .word name_8,name_9,name_T,name_J,name_Q,name_K
name_A: .asciiz "A"
name_2: .asciiz "2"
name_3: .asciiz "3"
name_4: .asciiz "4"
name_5: .asciiz "5"
name_6: .asciiz "6"
name_7: .asciiz "7"
name_8: .asciiz "8"
name_9: .asciiz "9"
name_T: .asciiz "10"
name_J: .asciiz "J"
name_Q: .asciiz "Q"
name_K: .asciiz "K"

instructions: .asciiz "\nBLACKJACK: H = hit, S = stand, R = new round, Q = quit.\nRed cards at top = dealer; blue cards at bottom = you.\nT on a card means 10. Dealer stands on 17.\n"
player_label: .asciiz "\nYour cards: "
dealer_label: .asciiz "Dealer cards: "
space_text:   .asciiz " "
question:     .asciiz "?"
total_label:  .asciiz "Total = "
newline:      .asciiz "\n"
turn_prompt:  .asciiz "H to hit, S to stand (or R/Q): "
invalid_msg:  .asciiz "Invalid key. Use H, S, R, or Q.\n"
player_bust:  .asciiz "BUST! Dealer wins.\n"
dealer_bust:  .asciiz "Dealer busts! You win!\n"
player_wins:  .asciiz "You win!\n"
dealer_wins:  .asciiz "Dealer wins.\n"
push_msg:     .asciiz "Push (tie game)!\n"
natural_msg:  .asciiz "Blackjack on the initial deal!\n"
round_end:    .asciiz "Press R for a new round or Q to quit.\n"
restart_msg:  .asciiz "\nNew round: shuffling the deck.\n"
bye_msg:      .asciiz "\nThanks for playing!\n"

.text
.globl main

main:
    # Seed MARS random generator 0 with low 32 bits of current time.
    li $v0, 30
    syscall                        # $a0 = low word of millisecond clock
    move $a1, $a0                 # seed
    li $a0, 0                     # random stream 0
    li $v0, 40                    # MARS: set random seed
    syscall

    la $a0, instructions
    jal print_string

new_round:
    sw $zero, player_count
    sw $zero, dealer_count
    li $t0, 1
    sw $t0, hide_hole
    jal shuffle_deck              # builds all 52 cards; $s6=deck index

    # Player, dealer, player, dealer.
    jal deal_player
    jal deal_dealer
    jal deal_player
    jal deal_dealer

    jal show_state                # second dealer card hidden on screen
    # Natural blackjack: reveal immediately and compare scores.
    jal get_player_total
    move $s2, $v0
    jal get_dealer_total
    move $s3, $v0
    li $t0, 21
    beq $s2, $t0, natural_finish
    beq $s3, $t0, natural_finish
    j player_turn

natural_finish:
    la $a0, natural_msg
    jal print_string
    j finish_round

player_turn:
    la $a0, turn_prompt
    jal print_string
    jal read_key
    li $t0, 113                   # q
    beq $v0, $t0, quit
    li $t0, 114                   # r
    beq $v0, $t0, restart
    li $t0, 115                   # s
    beq $v0, $t0, dealer_turn
    li $t0, 104                   # h
    bne $v0, $t0, invalid_move

    # Hit: give one new card, then score the hand.
    jal deal_player
    jal show_state
    jal get_player_total
    li $t0, 21
    bgt $v0, $t0, player_busted
    beq $v0, $t0, dealer_turn    # auto-stand at exactly 21
    j player_turn

invalid_move:
    la $a0, invalid_msg
    jal print_string
    j player_turn

player_busted:
    # Reveal hole card, print complete hand and bust result.
    sw $zero, hide_hole
    jal show_state
    la $a0, player_bust
    jal print_string
    j end_round

dealer_turn:
    # Dealer reveals the hole card and hits while below 17.
    sw $zero, hide_hole
dealer_draw_loop:
    jal get_dealer_total
    li $t0, 17
    bge $v0, $t0, finish_round
    jal deal_dealer
    j dealer_draw_loop

finish_round:
    sw $zero, hide_hole
    jal show_state
    jal get_player_total
    move $s2, $v0
    jal get_dealer_total
    move $s3, $v0
    li $t0, 21
    bgt $s3, $t0, result_dealer_bust
    bgt $s2, $s3, result_player_wins
    blt $s2, $s3, result_dealer_wins
    la $a0, push_msg
    j print_result

result_dealer_bust:
    la $a0, dealer_bust
    j print_result
result_player_wins:
    la $a0, player_wins
    j print_result
result_dealer_wins:
    la $a0, dealer_wins

print_result:
    jal print_string

end_round:
    la $a0, round_end
    jal print_string
end_round_wait:
    jal read_key
    li $t0, 113
    beq $v0, $t0, quit
    li $t0, 114
    beq $v0, $t0, restart
    j end_round_wait

restart:
    la $a0, restart_msg
    jal print_string
    j new_round

quit:
    la $a0, bye_msg
    jal print_string
    li $v0, 10
    syscall

# PRINT AND KEYBOARD HELPERS
print_string:                       # $a0: null-terminated string
    li $v0, 4
    syscall
    jr $ra

read_key:                           # blocks until a MMIO key, returns lowercase
    li $t0, 0xFFFF0000
read_key_wait:
    lw $t1, 0($t0)
    andi $t1, $t1, 1
    beqz $t1, read_key_wait
    lw $v0, 4($t0)
    andi $v0, $v0, 0xFF
    ori $v0, $v0, 0x20            # uppercase letters -> lowercase
    jr $ra

# CARD DECK: 52 cards, four copies of each rank 1..13.
# Fisher-Yates shuffle; MARS random-int-range syscall 42.
shuffle_deck:
    la $t0, deck
    li $t1, 0
fill_deck:
    li $t2, 13
    div $t1, $t2
    mfhi $t3                     # 0..12
    addiu $t3, $t3, 1
    sw $t3, 0($t0)
    addiu $t0, $t0, 4
    addiu $t1, $t1, 1
    slti $t4, $t1, 52
    bnez $t4, fill_deck

    li $t8, 51
shuffle_loop:
    # Random index j in [0,i]. Syscall overwrites $a0 only.
    li $a0, 0
    addiu $a1, $t8, 1
    li $v0, 42
    syscall
    move $t9, $a0                # j

    la $t0, deck
    sll $t1, $t8, 2              # i * 4
    addu $t1, $t1, $t0          # &deck[i]
    sll $t2, $t9, 2              # j * 4
    addu $t2, $t2, $t0          # &deck[j]
    lw $t3, 0($t1)
    lw $t4, 0($t2)
    sw $t4, 0($t1)
    sw $t3, 0($t2)
    addiu $t8, $t8, -1
    bgtz $t8, shuffle_loop

    li $s6, 0                   # index of next undealt card
    jr $ra

next_card:                          # $v0: next rank
    la $t0, deck
    sll $t1, $s6, 2
    addu $t0, $t0, $t1
    lw $v0, 0($t0)
    addiu $s6, $s6, 1
    jr $ra

deal_player:
    addiu $sp, $sp, -8
    sw $ra, 4($sp)
    jal next_card
    lw $t0, player_count
    la $t1, player_hand
    addu $t1, $t1, $t0
    sb $v0, 0($t1)
    addiu $t0, $t0, 1
    sw $t0, player_count
    lw $ra, 4($sp)
    addiu $sp, $sp, 8
    jr $ra

deal_dealer:
    addiu $sp, $sp, -8
    sw $ra, 4($sp)
    jal next_card
    lw $t0, dealer_count
    la $t1, dealer_hand
    addu $t1, $t1, $t0
    sb $v0, 0($t1)
    addiu $t0, $t0, 1
    sw $t0, dealer_count
    lw $ra, 4($sp)
    addiu $sp, $sp, 8
    jr $ra

# score_hand: $a0 = hand address, $a1 = card count
# returns $v0 = total. Ace = 11 unless it would bust.
score_hand:
    move $t0, $a0
    move $t1, $a1
    li $t2, 0                   # total
    li $t3, 0                   # aces currently counted as 11
score_loop:
    beqz $t1, score_adjust
    lbu $t4, 0($t0)
    li $t5, 1
    beq $t4, $t5, score_ace
    li $t5, 10
    ble $t4, $t5, score_add
    li $t4, 10                  # J/Q/K = 10
score_add:
    addu $t2, $t2, $t4
    j score_advance
score_ace:
    addiu $t2, $t2, 11
    addiu $t3, $t3, 1
score_advance:
    addiu $t0, $t0, 1
    addiu $t1, $t1, -1
    j score_loop
score_adjust:
    li $t5, 21
    ble $t2, $t5, score_done
    beqz $t3, score_done
    addiu $t2, $t2, -10          # turn one 11-point ace into 1
    addiu $t3, $t3, -1
    j score_adjust
score_done:
    move $v0, $t2
    jr $ra

get_player_total:
    la $a0, player_hand
    lw $a1, player_count
    j score_hand                 # tail-call; score_hand uses same $ra

get_dealer_total:
    la $a0, dealer_hand
    lw $a1, dealer_count
    j score_hand

# CONSOLE STATE: show visible cards and visible scores.
# Dealer's hole card and total stay hidden during your turn.
show_state:
    addiu $sp, $sp, -8
    sw $ra, 4($sp)
    jal redraw

    la $a0, dealer_label
    jal print_string
    la $a0, dealer_hand
    lw $a1, dealer_count
    lw $a2, hide_hole
    jal print_hand
    lw $t0, hide_hole
    bnez $t0, show_player
    la $a0, total_label
    jal print_string
    jal get_dealer_total
    move $a0, $v0
    li $v0, 1
    syscall

show_player:
    la $a0, player_label
    jal print_string
    la $a0, player_hand
    lw $a1, player_count
    li $a2, 0
    jal print_hand
    la $a0, total_label
    jal print_string
    jal get_player_total
    move $a0, $v0
    li $v0, 1
    syscall
    la $a0, newline
    jal print_string

    lw $ra, 4($sp)
    addiu $sp, $sp, 8
    jr $ra

# print_hand: $a0=hand, $a1=count, $a2=hide dealer hole (1/0)
print_hand:
    addiu $sp, $sp, -24
    sw $ra, 20($sp)
    sw $s0, 16($sp)
    sw $s1, 12($sp)
    sw $s2, 8($sp)
    move $s0, $a0                # pointer
    move $s1, $a1                # number of cards
    move $s2, $a2                # hide hole?
    li $t0, 0
    sw $t0, 4($sp)              # index
print_hand_loop:
    lw $t0, 4($sp)
    beq $t0, $s1, print_hand_end
    li $t1, 1
    bne $t0, $t1, print_face
    beqz $s2, print_face
    la $a0, question
    jal print_string
    j print_card_space
print_face:
    addu $t2, $s0, $t0
    lbu $t3, 0($t2)
    addiu $t3, $t3, -1
    sll $t3, $t3, 2
    la $t4, card_names
    addu $t4, $t4, $t3
    lw $a0, 0($t4)
    jal print_string
print_card_space:
    la $a0, space_text
    jal print_string
    lw $t0, 4($sp)
    addiu $t0, $t0, 1
    sw $t0, 4($sp)
    j print_hand_loop
print_hand_end:
    la $a0, newline
    jal print_string
    lw $s2, 8($sp)
    lw $s1, 12($sp)
    lw $s0, 16($sp)
    lw $ra, 20($sp)
    addiu $sp, $sp, 24
    jr $ra

# BITMAP RENDERING: 64 x 64 pixels; dealer on top, player
# below. Each card is a 7x10 rectangle with a 3x5 rank.
# Up to 16 cards per hand shown (8 across x 2 rows).
redraw:
    addiu $sp, $sp, -16
    sw $ra, 12($sp)
    sw $s0, 8($sp)
    sw $s1, 4($sp)
    sw $s2, 0($sp)
    jal clear_screen

    # Thin black divider between the dealer and player areas.
    li $a0, 0
    li $a1, 31
    li $a2, 64
    li $a3, 3
    li $t9, 0x00000000
    jal fill_rect

    # Dealer cards; hide second card before dealer's turn.
    li $s0, 0
    lw $s1, dealer_count
render_dealer:
    beq $s0, $s1, begin_player_render
    move $a0, $zero            # 0 = dealer
    move $a1, $s0
    la $t0, dealer_hand
    addu $t0, $t0, $s0
    lbu $a2, 0($t0)
    li $t1, 1
    bne $s0, $t1, draw_dealer
    lw $t2, hide_hole
    beqz $t2, draw_dealer
    li $a2, 0                   # rank 0 means facedown card
draw_dealer:
    jal draw_card
    addiu $s0, $s0, 1
    j render_dealer

begin_player_render:
    li $s0, 0
    lw $s1, player_count
render_player:
    beq $s0, $s1, redraw_done
    li $a0, 1                   # 1 = player
    move $a1, $s0
    la $t0, player_hand
    addu $t0, $t0, $s0
    lbu $a2, 0($t0)
    jal draw_card
    addiu $s0, $s0, 1
    j render_player

redraw_done:
    lw $s2, 0($sp)
    lw $s1, 4($sp)
    lw $s0, 8($sp)
    lw $ra, 12($sp)
    addiu $sp, $sp, 16
    jr $ra

clear_screen:
    la $t0, framebuffer
    li $t1, 4096
    li $t2, 0x000C5639         # felt-green background
clear_loop:
    sw $t2, 0($t0)
    addiu $t0, $t0, 4
    addiu $t1, $t1, -1
    bnez $t1, clear_loop
    jr $ra

# fill_rect inputs: $a0=x, $a1=y, $a2=width, $a3=height,
# $t9=RGB color. Clobbers only temporary registers.
fill_rect:
    li $t0, 0                  # local row
rect_rows:
    li $t1, 0                  # local column
rect_columns:
    addu $t2, $a1, $t0
    sll $t2, $t2, 6            # y * 64
    addu $t2, $t2, $a0
    addu $t2, $t2, $t1
    sll $t2, $t2, 2            # 4 bytes per bitmap cell
    la $t3, framebuffer
    addu $t3, $t3, $t2
    sw $t9, 0($t3)
    addiu $t1, $t1, 1
    bne $t1, $a2, rect_columns
    addiu $t0, $t0, 1
    bne $t0, $a3, rect_rows
    jr $ra

# draw_card: $a0=side (0 dealer/1 player)
#            $a1=card index (0..15), $a2=rank (0 = facedown)
# Each row fits 8 cards. Slot X=1+8*(index%8);
# Y=5+12*(index/8)+32*side.
draw_card:
    addiu $sp, $sp, -28
    sw $ra, 24($sp)
    sw $s0, 20($sp)
    sw $s1, 16($sp)
    sw $s2, 12($sp)
    sw $s3, 8($sp)
    sw $s4, 4($sp)
    sw $s5, 0($sp)
    move $s0, $a0                # side
    move $s1, $a1                # card index
    move $s2, $a2                # rank
    andi $t0, $s1, 7
    sll $s3, $t0, 3
    addiu $s3, $s3, 1           # card x
    srl $t0, $s1, 3
    li $t1, 12
    mul $s4, $t0, $t1
    addiu $s4, $s4, 5           # dealer y first row
    beqz $s0, card_border
    addiu $s4, $s4, 32          # player y

card_border:
    move $a0, $s3
    move $a1, $s4
    li $a2, 7
    li $a3, 10
    li $t9, 0x000B1720         # dark border
    jal fill_rect

    addiu $a0, $s3, 1
    addiu $a1, $s4, 1
    li $a2, 5
    li $a3, 8
    li $t9, 0x00F7F3E8         # off-white card face
    bnez $s2, card_face
    li $t9, 0x00B52B30         # red dealer card back
card_face:
    jal fill_rect

    beqz $s2, card_done

    # The 3x5 font comes from glyphs[(rank-1)*5].
    addiu $t0, $s2, -1
    li $t1, 5
    mul $t0, $t0, $t1
    la $s5, glyphs
    addu $s5, $s5, $t0
    li $t8, 0x00C0392B         # red rank for dealer
    beqz $s0, rank_start
    li $t8, 0x001A61CF         # blue rank for player
rank_start:
    li $t0, 0                   # glyph row
rank_row:
    lbu $t1, 0($s5)             # 3-bit row pattern
    li $t2, 0                   # glyph col
rank_col:
    li $t3, 4
    srlv $t3, $t3, $t2         # mask = 4,2,1
    and $t4, $t1, $t3
    beqz $t4, rank_skip
    addu $t5, $s4, $t0
    addiu $t5, $t5, 2
    sll $t5, $t5, 6
    addu $t5, $t5, $s3
    addu $t5, $t5, $t2
    addiu $t5, $t5, 2
    sll $t5, $t5, 2
    la $t6, framebuffer
    addu $t6, $t6, $t5
    sw $t8, 0($t6)
rank_skip:
    addiu $t2, $t2, 1
    li $t7, 3
    blt $t2, $t7, rank_col
    addiu $s5, $s5, 1
    addiu $t0, $t0, 1
    li $t7, 5
    blt $t0, $t7, rank_row
    j card_done

card_done:
    lw $s5, 0($sp)
    lw $s4, 4($sp)
    lw $s3, 8($sp)
    lw $s2, 12($sp)
    lw $s1, 16($sp)
    lw $s0, 20($sp)
    lw $ra, 24($sp)
    addiu $sp, $sp, 28
    jr $ra
