/* ========================================================================== */
/*                                                                            */
/*   keyboard.c                                                               */
/*   (c) 2011 Petr Simon                                                      */
/*                                                                            */
/*   Obsluha klavesnice                                                       */
/*                                                                            */
/* ========================================================================== */

#include <input.h>
#include "keyboard.h"
#include <stdio.h>
#include <spectrum.h>
#include <stdlib.h>


unsigned char keyState = 0;

/**
 * Ceka na stisk klavesy
 * 
 * @return ASCII kod stisknute klavesy  
 */ 
unsigned int waitForKey() 
{
    unsigned int key;

    //ceka, dokud neni stisknuta klavesa
    do {
        key = in_Inkey();
    } while (key==0);

    return key;
}

/**
 * Ceka na uvolneni klaves
 */ 
void waitForNoKey() 
{
    unsigned int key,a;

    a=0;
    //ceka, dokud uzivatel neuvolni vsechny stisknute klavesy
    do {
        key = in_Inkey();
        a++;
    } while (key!=0 && a<(keyState==0 ? 400 : 80));

    if (key!=0) keyState=1;
    else keyState=0;
}
