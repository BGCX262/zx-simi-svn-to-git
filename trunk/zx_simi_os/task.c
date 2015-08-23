#include <stdlib.h>

//bazova adresa DMA radice
#define TASK_BASE_ADDR 0x1F

//registr pro ulozeni cilove adresy (kam se bude ukladat)
#define TASK_ADDR0 (0x0000 + TASK_BASE_ADDR)
#define TASK_ADDR1 (0x0100 + TASK_BASE_ADDR)
#define TASK_7FFD  (0x0200 + TASK_BASE_ADDR)
#define TASK_CMD   (0x0400 + TASK_BASE_ADDR)


unsigned char taskSetA(unsigned char *pole, unsigned char byte) {
    //LD r,n
    pole[0] = 0x3E;
    pole[1] = byte;
    return 2;
}

unsigned char taskSetB(unsigned char *pole, unsigned char byte) {
    //LD r,n
    pole[0] = 0x06;
    pole[1] = byte;
    return 2;
}

unsigned char taskSetC(unsigned char *pole, unsigned char byte) {
    //LD r,n
    pole[0] = 0x0E;
    pole[1] = byte;
    return 2;
}

unsigned char taskSetD(unsigned char *pole, unsigned char byte) {
    //LD r,n
    pole[0] = 0x16;
    pole[1] = byte;
    return 2;
}

unsigned char taskSetE(unsigned char *pole, unsigned char byte) {
    //LD r,n
    pole[0] = 0x1E;
    pole[1] = byte;
    return 2;
}

unsigned char taskSetH(unsigned char *pole, unsigned char byte) {
    //LD r,n
    pole[0] = 0x26;
    pole[1] = byte;
    return 2;
}

unsigned char taskSetL(unsigned char *pole, unsigned char byte) {
    //LD r,n
    pole[0] = 0x2E;
    pole[1] = byte;
    return 2;
}

/**
 * likviduje registr A
 */ 
unsigned char taskSetBORDER(unsigned char *pole, unsigned char byte) {
    //LD A,n
    pole[0] = 0x3E;
    pole[1] = byte;
    //OUT (n),A
    pole[2] = 0xD3;
    pole[3] = 0xFE;
    return 4;
}


/**
 * likviduje registr A
 */ 
unsigned char taskSetI(unsigned char *pole, unsigned char byte) {
    //LD A,n
    pole[0] = 0x3E;
    pole[1] = byte;
    //LD I,A
    pole[2] = 0xED;
    pole[3] = 0x47;
    return 4;
}

/**
 * likviduje registr A
 */ 
unsigned char taskSetR(unsigned char *pole, unsigned char byte) {
    //LD A,n
    pole[0] = 0x3E;
    pole[1] = byte;
    //LD R,A
    pole[2] = 0xED;
    pole[3] = 0x4F;
    return 4;
}


unsigned char taskSetEXX(unsigned char *pole) {
    //EXX
    pole[0] = 0xD9;
    return 1;
}

unsigned char taskSetEXAF(unsigned char *pole) {
    //EX AF,AF'
    pole[0] = 0x08;
    return 1;
}

/**
 * Likviduje registr IX
 */ 
unsigned char taskSetAF(unsigned char *pole, unsigned char low, unsigned char high) {
    //LD IX,nn
    pole[0] = 0xDD;
    pole[1] = 0x21;
    pole[2] = low;
    pole[3] = high;
    //PUSH IX
    pole[4] = 0xDD;
    pole[5] = 0xE5;
    //POP AF
    pole[6] = 0xF1;
    return 7;
}


unsigned char taskSetIX(unsigned char *pole, unsigned char low, unsigned char high) {
    //LD IX,nn
    pole[0] = 0xDD;
    pole[1] = 0x21;
    pole[2] = low;
    pole[3] = high;
    return 4;
}

unsigned char taskSetIY(unsigned char *pole, unsigned char low, unsigned char high) {
    //LD IY,nn
    pole[0] = 0xFD;
    pole[1] = 0x21;
    pole[2] = low;
    pole[3] = high;
    return 4;
}



unsigned char taskSetSP(unsigned char *pole, unsigned char low, unsigned char high) {
    //LD SP,nn
    pole[0] = 0x31;
    pole[1] = low;
    pole[2] = high;
    return 3;
}

/**
 * Tato instrukce musi byt jako posledni. 
 */ 
unsigned char taskSetPC(unsigned char *pole, unsigned char low, unsigned char high) {
    //JP nn
    pole[0] = 0xC3;
    pole[1] = low;
    pole[2] = high;
    return 3;
}

unsigned char taskSetRETN(unsigned char *pole) {
    pole[0] = 0xED;
    pole[1] = 0x45;
    return 2;
}

unsigned char taskSetIM(unsigned char *pole, unsigned char byte) {
    pole[0] = 0xED;
    if (byte==1) pole[1] = 0x56; //IM 1
    else if (byte==2) pole[1] = 0x5E; //IM 2
    else pole[1] = 0x46; //IM 0
    return 2;
}

unsigned char taskSetIFF(unsigned char *pole, unsigned char byte) {
    if (byte == 0) pole[0] = 0xF3; //DI
    else pole[0] = 0xFB; //EI 
    return 1;
}



int (*taskFunc)();

void taskOut7FFD(unsigned char byte) {
    outp(TASK_7FFD, byte);
}

void taskRun(unsigned char *ind, unsigned char *pole)
{
    outp(TASK_ADDR0, ((unsigned int)ind      ) & 0xFF);  //nejnizsi bajt adresy
    outp(TASK_ADDR1, ((unsigned int)ind >>  8) & 0xFF);
                    
    outp(TASK_CMD, 0x01);  //dam prikaz pro monitorovani adresy z CPU. Pokud bude CPU adresovat stejnou adresu, ktera je ulozena v SIMI_ADDR, pak provedu prepnuti pameti

    taskFunc = pole;
    taskFunc();
}
