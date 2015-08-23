#include <stdio.h>
#include <spectrum.h>
#include <string.h>
#include <stdlib.h>
#include <graphics.h>
#include "keyboard.h"
#include "error.h"
#include "filesystem.h"
#include "sdcard.h"
#include "textgui.h"
#include "dma.h"
#include "file_z80.h"
#include "file_sna.h"
#include "file_tap.h"
#include "file_tzx.h"
#include "file_rom.h"

unsigned char text1[] = "Loading a file. Please wait...";
unsigned char text2[] = "Loading";
unsigned char text3[] = "Loading a tape into memory. Please run \"Tape Loader\" in the 128K Basic or run LOAD command in the 48K Basic.";

void printList(tFileSystemDir *dir, unsigned char from, unsigned char to)
{
    unsigned char i;

    //vymazu seznam
    clga(8,8,30*8,22*8);

    setTextColor(INK_BLACK);
    setBackgroundColor(INK_WHITE);

    for (i=from;i<=to;i++)
    {
        gotoXY(1,i+1);
        if ((dir->dirEntry[i].attr & 0x10) != 0) putchar('/');
        else putchar(' ');
        
        if (dir->dirEntry[i].useLongName==0) {        
            printf("%s%c%s", dir->dirEntry[i].name,((dir->dirEntry[i].attr & 0x10) != 0 ? ' ' : '.'),dir->dirEntry[i].ext);
        }
        else {
            printf("%s",dir->dirEntry[i].longName);
        }
    }
}

void printListUnselect(unsigned char s, unsigned char left, unsigned char top, unsigned char width)
{
    unsigned char x;

    for (x=left;x<left+width;x++)
    {
        setScreenAttr(x,s+top,INK_BLACK | PAPER_WHITE);
    }
}

void printListSelect(unsigned char s, unsigned char left, unsigned char top, unsigned char width)
{
    unsigned char x;

    for (x=left;x<left+width;x++)
    {
        setScreenAttr(x,s+top,INK_BLACK | PAPER_CYAN | BRIGHT);
    }
}

/*
unsigned char guiRomMenu()
{
    unsigned char selected; 
    unsigned int key;

    drawWindow(7,8,18,6,"ROM file");

    gotoXY(8,10);
    puts_cons("Run");
    gotoXY(8,11);
    puts_cons("Load into memory");
    gotoXY(8,12);
    puts_cons("Cancel");


    selected=0;
    do {
        printListSelect(selected,7,10,18);
        key = waitForKey();
        waitForNoKey();
        
        switch(key)
        {
            case KEY_UP:
                if (selected>0) {
                    printListUnselect(selected,7,10,18);
                    selected--;
                }
                break;
            case KEY_DOWN:
                if (selected<2) {
                    //vymazu oznaceni radku
                    printListUnselect(selected,7,10,18);
                    selected++;
                }
                break;
        }
    } while (key != KEY_ENTER);
    return selected;
}
*/

void guiMainWindow()
{
    //nakreslim okno
    drawWindow(0,0,32,24,"ZX Simi OS v1.0");

//    draw(14*8-1,8,14*8-1,8*24-1);
}

void printfBlock(unsigned char x, unsigned char y, unsigned char width, char *text)
{
    unsigned char i,ii;
    
    while(1) {
        //jedu zprava a hledam prvni mezeru, kde to muzu rozriznout a skocit na novy radek
        for (i=width; text[i]!=' ' && text[i]!=0; i--) ;
        
        gotoXY(x,y);
        //ted ten text vytisknu az do mezery
        for (ii=0; ii<i; ii++) {
            if (text[ii]==0) return;
            putchar(text[ii]);
        }
    
        text+=i;
        if (text[0]==' ') text++;
        
        //zvysim cislo radku
        y++;
    }; 
}



//****************************************************************************
int main()
{
    tFileSystemDir dir;
	unsigned int key;
	unsigned int skip;
	errc err;

    unsigned char ch;

    unsigned char selected;
    unsigned long target;

    //rezim 32 znaku na radek
    set32columnMode();

    //okraj    
    zx_border(INK_BLUE);
//    zx_colour(PAPER_RED | INK_RED);
    
    //zobrazim hlavni okno
    guiMainWindow();

    ///////////////////////////////////////////
    
    //inicializuji filesystem
    if ((err = fsStart(&dir)) != ERR_OK) return err;
    
    //nastavim se na zacatek adresare (nebudu preskakovat zadne soubory)
    skip = 0;

    //nastavim prvni soubor jako oznaceny 
    selected=0;
    //nactu seznam souboru
    if ((err = fsDir(0,&dir)) != ERR_OK) return err;

    printList(&dir,0,dir.size-1);
/*
    drawChar(20,10,imgWarning0);
    drawChar(21,10,imgWarning1);
    drawChar(20,11,imgWarning2);
    drawChar(21,11,imgWarning3);
*/    
        
    while(1)
    {
        printListSelect(selected,0,1,32);
        key = waitForKey();
        waitForNoKey();
        

        switch(key)
        {
            case KEY_UP:
                if (selected==0) { //jsem na konci seznamu
                    //pokud jsem uplne na zacatku adresaru, tak se nikam posunovat nebudu a skoncim
                    if (skip==0) break;
                    //snizim pocet souboru, ktere mam pri nacitani preskocit
                    skip -= FS_DIR_SIZE;
                    if ((err = fsDir(skip,&dir)) != ERR_OK) return err;

                    //vymazu oznaceni radku
                    printListUnselect(selected,0,1,32);

                    selected = FS_DIR_SIZE-1;
                    printList(&dir,0,dir.size-1);
                } else { //jsem uprostred seznamu, takze prekreslim jen predchozi radek
                    printListUnselect(selected,0,1,32);
                    selected--;
                }
                break;

            case KEY_DOWN:
                if (selected==dir.size-1 && dir.moreFiles==0) {}
                else if (selected==FS_DIR_SIZE-1) { //jsem na konci seznamu
                    //zvysim pocet souboru, ktere mam pri nacitani preskocit
                    skip += FS_DIR_SIZE;
                    if ((err = fsDir(skip,&dir)) != ERR_OK) return err;

                    //vymazu oznaceni radku
                    printListUnselect(selected,0,1,32);

                    selected = 0;
                    printList(&dir,0,dir.size-1);
                } else {
                    printListUnselect(selected,0,1,32);
                    selected++;
                }
                break;


            case KEY_ENTER:
                
                if ((dir.dirEntry[selected].attr & 0x10) == 0) { //aktualni polozka je soubor
                    if (memcmp(dir.dirEntry[selected].ext,"ROM",3)==0)
                    {
                        drawWindow(7,8,18,6,text2);
                        printfBlock(8, 10, 18, text1);
                        loadFileRunRom(&(dir.dirEntry[selected]));                        
/*                        
                        switch(guiRomMenu()) {
                            case 0:
                                loadFileRunRom(&(dir.dirEntry[selected]));
                            case 1:
                                loadFileRom(&(dir.dirEntry[selected]));
                            case 2:
                                guiMainWindow();
                                printList(&dir,0,dir.size-1);
                                break;
                        }*/
                    }
                    else if (memcmp(dir.dirEntry[selected].ext,"SNA",3)==0)
                    {
                        drawWindow(7,8,18,6,text2);
                        printfBlock(8, 10, 18, text1);

                        loadFileSna(&(dir.dirEntry[selected]));
                    }
                    else if (memcmp(dir.dirEntry[selected].ext,"Z80",3)==0)
                    {
                        drawWindow(7,8,18,6,text2);
                        printfBlock(8, 10, 18, text1);

                        loadFileZ80(&(dir.dirEntry[selected]));
                    }
                    else if (memcmp(dir.dirEntry[selected].ext,"TAP",3)==0)
                    {
                        drawWindow(4,6,24,9,text2);
                        printfBlock(5, 8, 22, text3);

                        tapLoadFile(&(dir.dirEntry[selected]));
                    }
                    else if (memcmp(dir.dirEntry[selected].ext,"TZX",3)==0)
                    {
                        drawWindow(4,6,24,9,text2);
                        printfBlock(5, 8, 22, text3);

                        tzxLoadFile(&(dir.dirEntry[selected]));
                    }
                }
                else { //aktualni polozka je adresar
                    //nastavim oznaceny odresar jako aktualni
                    dir.dirCluster = dir.dirEntry[selected].cluster;
                    //nactu seznam souboru
                    if ((err = fsDir(0,&dir)) != ERR_OK) return err;

                    //vymazu oznaceny radek
                    printListUnselect(selected,0,1,32);                
                
                    selected = 0;
                    skip = 0;
                    printList(&dir,0,dir.size-1);
                }
                break;                
            default:
                break;
                
        }
    }












    ////////////////////////////////////////

/*

    while(1)
    {
        if ((err = guiMainWindow()) != ERR_OK)
        {
            setTextColor(INK_WHITE);
            zx_border(INK_RED);
            gotoXY(0,0);
            printf("ERROR %d\n",err);
            key = waitForKey();
            waitForNoKey();
        }
    }
    

    zx_border(INK_RED);

    while(1)
    {

        key = waitForKey();
        waitForNoKey();
        
        switch(key)
        {
            case 'q':   //status karty
                data = inp(0x06F7);
                printf("s:%x ",data);
                break;
            default:
                gotoXY(3,3);
                printf("%d ",key);
                break;
        }
    }
*/  
      
    return 0;
}
