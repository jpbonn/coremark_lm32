/* 
	File : core_portme.c
*/
/*
	Author : Shay Gal-On, EEMBC
	Legal : TODO!
*/ 
#include "coremark.h"
#include "core_portme.h"

#include <hal/time.h>

#if VALIDATION_RUN
	volatile ee_s32 seed1_volatile=0x3415;
	volatile ee_s32 seed2_volatile=0x3415;
	volatile ee_s32 seed3_volatile=0x66;
#endif
#if PERFORMANCE_RUN
	volatile ee_s32 seed1_volatile=0x0;
	volatile ee_s32 seed2_volatile=0x0;
	volatile ee_s32 seed3_volatile=0x66;
#endif
#if PROFILE_RUN
	volatile ee_s32 seed1_volatile=0x8;
	volatile ee_s32 seed2_volatile=0x8;
	volatile ee_s32 seed3_volatile=0x8;
#endif
	volatile ee_s32 seed4_volatile=ITERATIONS;
	volatile ee_s32 seed5_volatile=0;
/* Porting : Timing functions
	How to capture time and convert to seconds must be ported to whatever is supported by the platform.
	e.g. Read value from on board RTC, read value from cpu clock cycles performance counter etc. 
	Sample implementation for standard time.h and windows.h definitions included.

	We're returning milliseconds.
*/
static unsigned int time = 0;
CORETIMETYPE barebones_clock() {

	struct timestamp dest;
	time_get(&dest);
	return dest.sec*1000 + dest.usec/1000;

	return time;
}
/* Define : TIMER_RES_DIVIDER
	Divider to trade off timer resolution and total time that can be measured.

	Use lower values to increase resolution, but make sure that overflow does not occur.
	If there are issues with the return value overflowing, increase this value.
	*/
#define GETMYTIME(_t) (*_t=barebones_clock())
#define MYTIMEDIFF(fin,ini) ((fin)-(ini))
#define TIMER_RES_DIVIDER 1
#define SAMPLE_TIME_IMPLEMENTATION 1
#define EE_TICKS_PER_SEC (CLOCKS_PER_SEC / TIMER_RES_DIVIDER)

/** Define Host specific (POSIX), or target specific global time variables. */
static CORETIMETYPE start_time_val, stop_time_val;

/* Function : start_time
	This function will be called right before starting the timed portion of the benchmark.

	Implementation may be capturing a system timer (as implemented in the example code) 
	or zeroing some system parameters - e.g. setting the cpu clocks cycles to 0.

*/
void start_time(void) {
	GETMYTIME(&start_time_val );
}
/* Function : stop_time
	This function will be called right after ending the timed portion of the benchmark.

	Implementation may be capturing a system timer (as implemented in the example code) 
	or other system parameters - e.g. reading the current value of cpu cycles counter.
*/
void stop_time(void) {
        GETMYTIME(&stop_time_val );
}
/* Function : get_time
	Return an abstract "ticks" number that signifies time on the system.
	
	Actual value returned may be cpu cycles, milliseconds or any other value,
	as long as it can be converted to seconds by <time_in_secs>.
	This methodology is taken to accomodate any hardware or simulated platform.
	The sample implementation returns millisecs by default, 
	and the resolution is controlled by <TIMER_RES_DIVIDER>
*/
CORE_TICKS get_time(void) {
	CORE_TICKS elapsed=(CORE_TICKS)(MYTIMEDIFF(stop_time_val, start_time_val));
	return elapsed;
}
/* Function : time_in_secs
	Convert the value returned by get_time to seconds.

	The <secs_ret> type is used to accomodate systems with no support for floating point.
	Default implementation implemented by the EE_TICKS_PER_SEC macro above.
*/
secs_ret time_in_secs(CORE_TICKS ticks) {
	secs_ret retval=((secs_ret)ticks) / (secs_ret)EE_TICKS_PER_SEC;
	return retval;
}

ee_u32 default_num_contexts=1;

extern int main(void);

/* External Milkymist functions: */
void splash_display();

#include <stdio.h>
#include <stdlib.h>
#include <console.h>
#include <string.h>
#include <uart.h>
#include <blockdev.h>
#include <fatfs.h>
/* #include <crc.h> */
#include <system.h>
#include <board.h>
#include <irq.h>
#include <version.h>
#include <net/mdio.h>
#include <hw/fmlbrg.h>
#include <hw/sysctl.h>
#include <hw/gpio.h>
#include <hw/flash.h>
#include <hw/minimac.h>

#include <hal/vga.h>
#include <hal/tmu.h>
#include <hal/brd.h>
#include <hal/usb.h>
#include <hal/ukb.h>

static const char banner[] =
        "\nMILKYMIST(tm) v"VERSION" BIOS   http://www.milkymist.org\n"
        "(c) Copyright 2007, 2008, 2009, 2010, 2011 Sebastien Bourdeauducq\n\n"
        "This program is free software: you can redistribute it and/or modify\n"
        "it under the terms of the GNU General Public License as published by\n"
        "the Free Software Foundation, version 3 of the License.\n\n";

void
time_tick(void)
{
  return;
}

int rescue;

static int test_user_abort()
{
        char c;

        puts("I: Press Q or ESC to abort boot");
        CSR_TIMER0_COUNTER = 0;
        CSR_TIMER0_COMPARE = 2*CSR_FREQUENCY;
        CSR_TIMER0_CONTROL = TIMER_ENABLE;
        while(CSR_TIMER0_CONTROL & TIMER_ENABLE) {
                if(readchar_nonblock()) {
                        c = readchar();
                        if((c == 'Q')||(c == '\e')) {
                                puts("I: Aborted boot on user request");
                                return 0;
                        }
                        if(c == 0x07) {
                                vga_unblank();
                                vga_set_console(1);
                                netboot();
                                return 0;
                        }
                }
        }
        return 1;
}



/*
static void boot_sequence()
{
        if(test_user_abort()) {
                if(rescue) {
                        netboot();
                        serialboot();
                        fsboot(BLOCKDEV_MEMORY_CARD);
                        flashboot();
                } else {
                        fsboot(BLOCKDEV_MEMORY_CARD);
                        flashboot();
                        netboot();
                        serialboot();
                }
                printf("E: No boot medium found\n");
        }
}
*/

static void ethreset_delay()
{
        CSR_TIMER0_COUNTER = 0;
        CSR_TIMER0_COMPARE = CSR_FREQUENCY >> 2;
        CSR_TIMER0_CONTROL = TIMER_ENABLE;
        while(CSR_TIMER0_CONTROL & TIMER_ENABLE);
}

static void ethreset()
{
        CSR_MINIMAC_SETUP = MINIMAC_SETUP_PHYRST;
        ethreset_delay();
        CSR_MINIMAC_SETUP = 0;
        ethreset_delay();
}

/* main is from Milkymist bios. */
int port_main(int i, char **c)
{
        /* lock gdbstub ROM */
        CSR_DBG_CTRL = DBG_CTRL_GDB_ROM_LOCK;

        /* enable bus errors */
        CSR_DBG_CTRL = DBG_CTRL_BUS_ERR_EN;

        CSR_GPIO_OUT = GPIO_LED1;
        rescue = !((unsigned int)main > FLASH_OFFSET_REGULAR_BIOS);

        irq_setmask(0);
        irq_enable(1);
	time_init();
        uart_init();
//        vga_init(!(rescue || (CSR_GPIO_IN & GPIO_BTN2)));
        putsnonl(banner);
//        crcbios();
//        brd_init();
//        tmu_init(); /* < for hardware-accelerated scrolling */
//        usb_init();
//        ukb_init();

        if(rescue)
                printf("I: Booting in rescue mode\n");

//        splash_display();
//        ethreset(); /* < that pesky ethernet PHY needs two resets at times... */
//        print_mac();
//        boot_sequence();
//        vga_unblank();
//        vga_set_console(1);
    uart_force_sync(1);
while (1)  {
        putsnonl("\e[1mStarting CoreMark\e[0m\n");
        main();
	putsnonl("\e[1mCoreMark ended.\e[0m ");
}
        return 0;
}
                    

/* Function : portable_init
	Target specific initialization code 
	Test for some common mistakes.
*/
void portable_init(core_portable *p, int *argc, char *argv[])
{
	if (sizeof(ee_ptr_int) != sizeof(ee_u8 *)) {
		ee_printf("ERROR! Please define ee_ptr_int to a type that holds a pointer!\n");
	}
	if (sizeof(ee_u32) != 4) {
		ee_printf("ERROR! Please define ee_u32 to a 32b unsigned type!\n");
	}
	p->portable_id=1;
}
/* Function : portable_fini
	Target specific final code 
*/
void portable_fini(core_portable *p)
{
	p->portable_id=0;
}

