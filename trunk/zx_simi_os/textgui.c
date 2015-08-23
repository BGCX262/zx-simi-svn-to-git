#include <stdio.h>
#include <stdlib.h>
#include <graphics.h>
#include <spectrum.h>
#include "textgui.h"
unsigned char imgTitleTriangle[8] = {0xFF, 0xFE, 0xFC, 0xF8, 0xF0, 0xE0, 0xC0, 0x80};
/*
unsigned char imgError0[8] = {0x03, 0x0F, 0x1F, 0x37, 0x63, 0x71, 0xF8, 0xFC};
unsigned char imgError1[8] = {0xC0, 0xF0, 0xF8, 0xEC, 0xC6, 0x8E, 0x1F, 0x3F};
unsigned char imgError2[8] = {0xFC, 0xF8, 0x71, 0x63, 0x37, 0x1F, 0x0F, 0x03};
unsigned char imgError3[8] = {0x3F, 0x1F, 0x8E, 0xC6, 0xEC, 0xF8, 0xF0, 0xC0};


unsigned char imgWarning0[8] = {0x01, 0x01, 0x03, 0x03, 0x06, 0x06, 0x0E, 0x0E};
unsigned char imgWarning1[8] = {0x80, 0x80, 0xC0, 0xC0, 0x60, 0x60, 0x70, 0x70};
unsigned char imgWarning2[8] = {0x1E, 0x1E, 0x3E, 0x3F, 0x7F, 0x7E, 0xFE, 0xFF};
unsigned char imgWarning3[8] = {0x78, 0x78, 0x7C, 0xFC, 0xFE, 0x7E, 0x7F, 0xFF};
*/

void drawChar(unsigned char x,unsigned char y,unsigned char *img)
{
    unsigned char ch;

    for (ch=0;ch<8;ch++)
        drawCharLine(x,y,ch,img[ch]); 
}

void setBackgroundColor(unsigned char inkColor)
{
    printf("%c%c",17,'0'+inkColor);
}

void setTextColor(unsigned char inkColor)
{
    printf("%c%c",16,'0'+inkColor);
}

void setBright(unsigned char bright)
{
    printf("%c%c",19,1);
}

void gotoXY(unsigned char x,unsigned char y)
{
    unsigned char xx,yy;

    if (x==0) xx=1;
    else xx=x;
    if (y==0) yy=1;
    else yy=y;
   
    xx <<=1;
   
    printf("%c%c%c",22,32+yy,32+xx);

    if (x==0) printf("%c",8);
    if (y==0) printf("%c",11);
}

 
void drawProgressBar(unsigned char x, unsigned char y, unsigned char width, unsigned long max, unsigned long current)
{
    unsigned char i;
    
    drawb(x*8,y*8,width*8,8);
    for (i=0;i<width*current/max;i++)
        setScreenAttr(i+x,y,PAPER_GREEN | INK_BLACK)
    
}

void drawWindow(unsigned char x, unsigned char y, unsigned char width, unsigned char height, char *title)
{
    unsigned char xx,yy;

    //vymazu data pod oknem.                                       
    clga(x*8,y*8,width*8,height*8);
    
    gotoXY(x+1,y);
    puts_cons(title);
  
    //nakreslim horni cerny pruh
    for (xx=x;xx<width+x-6;xx++)
        setScreenAttr(xx,y,PAPER_BLACK | INK_WHITE | BRIGHT);

    //nastavim barevne atributy pro vykresleni barevneho prouzku vpravo nahore
    setScreenAttr(x+width-1,y,PAPER_BLACK | INK_BLACK | BRIGHT);
    setScreenAttr(x+width-2,y,PAPER_BLACK | INK_CYAN | BRIGHT);
    setScreenAttr(x+width-3,y,PAPER_CYAN | INK_GREEN | BRIGHT);        
    setScreenAttr(x+width-4,y,PAPER_GREEN | INK_YELLOW | BRIGHT);
    setScreenAttr(x+width-5,y,PAPER_YELLOW | INK_RED | BRIGHT);
    setScreenAttr(x+width-6,y,PAPER_RED | INK_BLACK | BRIGHT);

    
    
    //ted ty pruhy udelam zkosene
        for (xx=x+width-6;xx<x+width-1;xx++)
            drawChar(xx,y,imgTitleTriangle);

   
   
    //nastavim pro cele okno atributy barev
    for (xx=x; xx<(x+width); xx++)
        for (yy=y+1;yy<y+height;yy++)
            setScreenAttr(xx,yy,PAPER_WHITE | INK_BLACK);


    //nakreslim ohraniceni okolo okna

    draw(x*8,(y+1)*8,x*8,(y+height)*8-1); //leva hrana
    draw((x+width)*8-1,(y+1)*8,(x+width)*8-1,(y+height)*8-1); //prava hrana
    draw(x*8,(y+height)*8-1,(x+width)*8-1,(y+height)*8-1); //spodni hrana
}

