/* ========================================================================== */
/*                                                                            */
/*   keyboard.h                                                               */
/*   (c) 2011 Petr Simon                                                      */
/*                                                                            */
/*   Obsluha klavesnice                                                       */
/*                                                                            */
/* ========================================================================== */

#ifndef _KEYBOARD_H_
#define _KEYBOARD_H_

#define KEY_UP 11
#define KEY_DOWN 10
#define KEY_ENTER 13

/**
 * Ceka na stisk klavesy
 * 
 * @return ASCII kod stisknute klavesy  
 */ 
unsigned int waitForKey(); 

/**
 * Ceka na uvolneni klaves
 */ 
void waitForNoKey(); 

#endif