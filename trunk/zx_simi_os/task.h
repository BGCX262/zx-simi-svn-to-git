#define TASK_RAM_BASE_ADDR 0x40000

#define TASK_ROM0 (0x20000)

#define TASK_RAM0 (TASK_RAM_BASE_ADDR)
#define TASK_RAM2 (TASK_RAM_BASE_ADDR + 0x8000)
#define TASK_RAM5 (TASK_RAM_BASE_ADDR + 0x14000)

extern unsigned char taskSetA(unsigned char *pole, unsigned char byte);

extern unsigned char taskSetB(unsigned char *pole, unsigned char byte);

extern unsigned char taskSetC(unsigned char *pole, unsigned char byte);

extern unsigned char taskSetD(unsigned char *pole, unsigned char byte);

extern unsigned char taskSetE(unsigned char *pole, unsigned char byte);

extern unsigned char taskSetH(unsigned char *pole, unsigned char byte);

extern unsigned char taskSetL(unsigned char *pole, unsigned char byte);

extern unsigned char taskSetBORDER(unsigned char *pole, unsigned char byte);

extern unsigned char taskSetI(unsigned char *pole, unsigned char byte);

extern unsigned char taskSetR(unsigned char *pole, unsigned char byte);

extern unsigned char taskSetEXX(unsigned char *pole);

extern unsigned char taskSetEXAF(unsigned char *pole);

extern unsigned char taskSetAF(unsigned char *pole, unsigned char low, unsigned char high);

extern unsigned char taskSetIX(unsigned char *pole, unsigned char low, unsigned char high);

extern unsigned char taskSetIY(unsigned char *pole, unsigned char low, unsigned char high);

extern unsigned char taskSetSP(unsigned char *pole, unsigned char low, unsigned char high);

extern unsigned char taskSetPC(unsigned char *pole, unsigned char low, unsigned char high);

extern unsigned char taskSetRETN(unsigned char *pole);

extern unsigned char taskSetIM(unsigned char *pole, unsigned char byte);

/**
 * Nastavi IFF1 a IFF2 na hodnotu 0 nebo 1
 * byte == 0    DI
 * byte != 0    EI
 */ 
extern unsigned char taskSetIFF(unsigned char *pole, unsigned char byte);

extern void taskOut7FFD(unsigned char byte);

extern void taskRun(unsigned char *ind, unsigned char *pole);
