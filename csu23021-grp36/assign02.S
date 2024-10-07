
#include "hardware/regs/addressmap.h"
#include "hardware/regs/io_bank0.h"
#include "hardware/regs/timer.h"
#include "hardware/regs/m0plus.h"

.syntax unified
.cpu    cortex-m0plus
.thumb
.global main_asm
.global level0
.align  4


.equ    DFLT_STATE_STRT, 1            @ Specify the value to start flashing
.equ    DFLT_STATE_STOP, 0            @ Specify the value to stop flashing
.equ    DFLT_ALARM_TIME, 1000000      @ Specify the default ALARM timeout


.equ    GPIO_BTN_FALL_MSK, 0x00400000   @ Bit-22 for falling-edge event on GP21
.equ    GPIO_BTN_RISE_MSK, 0x00800000   @ Bit-26 for rising-edge event on GP21

.equ    GPIO_BTN_EN,  21              @ Specify pin for the "enter" button
.equ    GPIO_LED_PIN, 25              @ Specify pin for the built-in LED
.equ    GPIO_DIR_IN,   0              @ Specify input direction for a GPIO pin
.equ    GPIO_DIR_OUT,  1              @ Specify output direction for a GPIO pin

.equ    ZERO_SEC,    0              @ Specify value that turns the LED "on"
.equ    ONE_SEC,     1              @ Specify value that turns the LED "off"
.equ    TWO_SEC,     2   

.equ    DOT_TIME,    300000             @ Specify value that should display dot
.equ    DASH_TIME,   1000000            @ Specify value that should display dash
.equ    EMPTY_TIME,  300000          @ Specify value that should display spoace
.equ    SPASE_TIME,  1000000           @ Specify value that should check code
.equ    ENTER_TIME, 2000000
.equ    MIN_TIME,    100000 



.equ    GPIO_ISR_OFFSET, 0x74         @ GPIO is int #13 (vector table entry 29)
.equ    ALRM_ISR_OFFSET, 0x40         @ ALARM0 is int #0 (vector table entry 16)

@ Entry point to the ASM portion of the program
main_asm:
    bl      init_gpio_led                               @Initialise the GPIO LED pin                            @ Install each of the GPIO buttons
    bl      init_gpio_en                         @Install the SVC interrupt service routine
    bl      install_alrm_isr
    bl      install_gpio_isr
Homescreen:
    bl      homescreen
    bl      setLED
    bl      sleep
    ldr     r4, =#3
    ldr     r5, =#0
    bl      alarm
    b       ChooseLevel
    
Inputting0:
    cmp     r5, ONE_SEC
    beq     Inputtingover0
    b       Inputting0
ChooseLevel:
    cmp     r5, #ONE_SEC
    bne     Inputting0
Inputtingover0:
    ldr     r5, =ZERO_SEC
    bl      level0
    cmp     r0, #1
    beq     Level1
    cmp     r0, #2
    beq     Level2
    cmp     r0, #3
    beq     Level3
    cmp     r0, #4
    beq     Level4
    b       ChooseLevel

Inputting:
    cmp     r5, ONE_SEC
    beq     Inputtingover
    b       Inputting
Level1:
    bl      level1
    cmp     r5, #ONE_SEC
    bne     Inputting
Inputtingover:
    ldr     r5, =ZERO_SEC
    bl      checkEntry
    cmp     r0, #1
    beq     next1
    b       Level1
next1:
    bl      Level2header
    b       Level2

Inputting2:
    cmp     r5, ONE_SEC
    beq     Inputtingover2
    b       Inputting2
Level2:
    bl      level2
    cmp     r5, #ONE_SEC
    bne     Inputting2
Inputtingover2:
    ldr     r5, =ZERO_SEC
    bl      checkEntry
    cmp     r0, #1
    beq     next2
    b       Level2
next2:
    bl      Level3header
    b       Level3

Inputting3:
    cmp     r5, ONE_SEC
    beq     Inputtingover3
    b       Inputting3
Level3:
    bl      level3
    cmp     r5, #ONE_SEC
    bne     Inputting3
Inputtingover3:
    ldr     r5, =ZERO_SEC
    bl      checkEntry
    cmp     r0, #1
    beq     next3
    b       Level3
next3:
    bl      Level4header
    b       Level4

Inputting4:
    bl      clearAnswer
    cmp     r5, ONE_SEC
    beq     Inputtingover4
    b       Inputting4
Level4:
    bl      level4
    cmp     r5, #ONE_SEC
    bne     Inputting4
Inputtingover4:
    ldr     r5, =ZERO_SEC
    bl      checkEntry
    cmp     r0, #1
    beq     GameFinished
    b       Level4
ResetGame:

GameFinished:
    bl      gameover
    b       main_asm          

GameOver:








@ Subroutine used to initialise the PI Pico built-in LED
init_gpio_led:
    push    {lr}                                        @initialising GPIO LED by moving pin no to r0 and setting direction as output
    movs    r0, #GPIO_LED_PIN                           @ moving the pin number into register 0
    bl      asm_gpio_init                               @calling function to  initialising the pin
    movs    r0, #GPIO_LED_PIN                   
    movs    r1, #GPIO_DIR_OUT                           @moving the direction we want into register 1
    bl      asm_gpio_set_dir                            @ calling function to setting the direction       
    pop     {pc}                                        
                                                        @ similar operation for all buttons

init_gpio_en:
    push    {lr}                                        @initialising GPIO BTN by moving pin no to r0 and setting direction as input
    movs    r0, #GPIO_BTN_EN
    bl      asm_gpio_init
    movs    r0, #GPIO_BTN_EN
    movs    r1, #GPIO_DIR_IN
    bl      asm_gpio_set_dir                            
    movs    r0, #GPIO_BTN_EN
    bl      asm_gpio_set_irq
    pop     {pc}

alarm:
    push    {lr}                                        @pushes return address to stack
    ldr     r2, =(TIMER_BASE + TIMER_TIMELR_OFFSET)     @loads timer component adress and 32 bitoffset adress into r2 
    ldr     r1, [r2]
    ldr     r2, =ltimer                                 @loads timing into r2
    ldr     r0, [r2]
    add     r1, r0                                      @adds the timing to the two address values
    ldr     r2, =(TIMER_BASE + TIMER_ALARM0_OFFSET)     @laods offset for alarm control register
    str     r1, [r2]                                    @ stores added value into register
    
    ldr     r2, =(TIMER_BASE + TIMER_INTE_OFFSET)       @loads offset of interupt enable
    ldr     r1, =#0x1
    str     r1, [r2]                                    @storing the correct value into the interupt register
    pop     {pc}

     
@ Subroutine used to install the alrm interrupt service handler
install_alrm_isr:
    ldr     r2, =(PPB_BASE + M0PLUS_VTOR_OFFSET)        @loads rp2040 component adress and vector adress into r2 
    ldr     r1, [r2]                                    
    movs    r2, #ALRM_ISR_OFFSET                        @movs value of iser offset into r2
    add     r1, r2                                      @adding the values 
    ldr     r0, =alrm_isr                               @loading the alrm_isr function to r0
    str     r0, [r1]                                    @stroing it in the added address
    ldr     r2, =(PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET)   @setting up the pending/disable register and putting into r2
    ldr     r0, =#0x1                                   @ 
    str     r0, [r2]                                    @setting the correct value for the pending interupt
    ldr     r2, =(PPB_BASE + M0PLUS_NVIC_ISER_OFFSET)   @setting the enable interupt into r2
    ldr     r0, =#0x1                                   
    str     r0, [r2]                                    @ storing the correct value into the enable offset registers
    bx      lr                                          @ exiting the routine

.thumb_func                                             @ Required for all interrupt service routines
alrm_isr:                                               
    push    {lr}                                        @pushes return address to stack
    ldr     r2, =(TIMER_BASE + TIMER_INTR_OFFSET)       @loads offset of timer raw interupt
    ldr     r1, =#0x1                                   @ <TODO – add comment>
    str     r1, [r2]    @update the state of the LED  
    cmp     r7, #ONE_SEC
    beq     alrm_done   
    ldr     r5, =ZERO_SEC       
    ldr     r1, =ONE_SEC
    adds    r4, r4, r1   
    cmp     r4, #TWO_SEC  
    beq     dashproc    
    bl      alrm_done
dashproc:                @ storing the correct value into the register to disable interupt
    bl      printtheoutput     @update the state of the LED
    ldr     r5, =#1                             @call the alarm routine
alrm_done:
    bl      alarm
    pop     {pc}                                        @exiting the fucntion

@ Subroutine used to install the gpio interrupt service handler
install_gpio_isr:
    ldr     r2, =(PPB_BASE + M0PLUS_VTOR_OFFSET)        @Similar to the alarm_isr, it initialises the interupt disable and enables for GPIO buttons
    ldr     r1, [r2]                                    
    movs    r2, #GPIO_ISR_OFFSET                        
    adds    r1, r2                                      
    ldr     r0, =gpio_isr                               
    str     r0, [r1]                                    
    ldr     r2, =(PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET)   
    ldr     r1, =#0x2000                                
    str     r1, [r2]                                    
    ldr     r2, =(PPB_BASE + M0PLUS_NVIC_ISER_OFFSET)   
    ldr     r1, =#0x2000                                
    str     r1, [r2]           
    bx      lr                                          

@ gpio interrupt service handler routine
.thumb_func                     
gpio_isr:
    push    {lr}                                                    @enters the routine
    ldr     r2, =(IO_BANK0_BASE + IO_BANK0_PROC0_INTS2_OFFSET)      @enters interupt register to determine interupts
    ldr     r0, [r2]                                                @stores correct value to init
    ldr     r1, =0x2000
    str     r1, [r2]                                                
    //ldr     r2, = (TIMER_BASE + TIMER_INTE_OFFSET)                  @ stores correct value to enable the interupt
    //str     r1, [r2]    
    bl      watchdog_timer_reset 
    ldr     r1, =(GPIO_BTN_FALL_MSK)                                  @ loads value of falling edge for dwn btn and compares to interupt
    cmp     r0, r1
    beq     gpiofall                                                @if its equal enter the down routine
    ldr     r2, =(GPIO_BTN_RISE_MSK)                                  @loads value of falling edge for up btn and compares to interupt
    cmp     r0, r2
    beq     gpiorise                                                 @if its equal enter the up routine                                             @if its equal enter the engage routine
    b       done                                                    @ else exit

gpiofall:
    ldr     r2, =(IO_BANK0_BASE + IO_BANK0_INTR2_OFFSET)            @disables pending interupt by writing falling edge value to raw offset     
    ldr     r1, =#GPIO_BTN_FALL_MSK                                   
    str     r1,[r2]  
    ldr     r2, =(TIMER_BASE + 0x28) 
    ldr     r1, [r2]
    ldr     r7, =#ONE_SEC
    subs    r1, r6
    ldr     r2, =(TIMER_BASE + 0x28)
    ldr     r6, [r2]
    ldr     r2, =#SPASE_TIME
    cmp     r1, r2
    blt     empty
    ldr     r2, =#ENTER_TIME
    cmp     r1, r2
    blt     spase
    b       done
    
empty:
    ldr     r2, =#MIN_TIME
    cmp     r1, r2
    blt     done
    movs    r0, #43
    bl      addtoanswer
    ldr     r0, =msgsapce
    bl      printf   
    b       done 

spase:
    movs    r0, #32
    bl      addtoanswer
    ldr     r0, =msgplus
    bl      printf  
    b       done 

       
gpiorise:
    ldr     r2, =(IO_BANK0_BASE + IO_BANK0_INTR2_OFFSET)            @disables pending interupt by writing falling edge value to raw offset     
    ldr     r1, =#GPIO_BTN_RISE_MSK                                   
    str     r1, [r2]  
    ldr     r2, =(TIMER_BASE + 0x28) 
    ldr     r1, [r2]
    ldr     r7, =#ZERO_SEC
    subs    r1, r6 
    ldr     r2, =(TIMER_BASE + 0x28) 
    ldr     r6, [r2]
    ldr     r2, =#DOT_TIME
    cmp     r1, r2
    blt     dot   
    bge     dash  
    b       done      
dot: 
    movs    r0, #46
    bl      addtoanswer
    ldr     r0, =msgdot
    bl      printf   
    b       done     

dash: 
    movs    r0, #45
    bl      addtoanswer
    ldr     r0, =msgdash
    bl      printf   
    b       done   
 
                                    @ <TODO – add comment>
done:                                
    ldr     r4, =#ZERO_SEC           
    bl      alarm    @proc the alarm routine 
    pop     {pc}                                                    @exit the routine


.align 4
msgdot:    .asciz "."
msgdash:   .asciz "-"
msgsapce:   .asciz " "
msgplus:    .asciz "+"



.data
lstate: .word   DFLT_STATE_STRT
ltimer: .word   DFLT_ALARM_TIME

