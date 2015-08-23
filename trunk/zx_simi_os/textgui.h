#ifndef _TEXTGUI_H_
#define _TEXTGUI_H_
/*
extern unsigned char imgError0[8];
extern unsigned char imgError1[8];
extern unsigned char imgError2[8];
extern unsigned char imgError3[8];
extern unsigned char imgWarning0[8];
extern unsigned char imgWarning1[8];
extern unsigned char imgWarning2[8];
extern unsigned char imgWarning3[8];
*/
extern unsigned char imgTitleTriangle[8];


#define set32columnMode() puts_cons("\1\32");

extern void setBackgroundColor(unsigned char inkColor);

extern void setTextColor(unsigned char inkColor);

extern void setBright(unsigned char bright);

extern void gotoXY(unsigned char x,unsigned char y);


#define setScreenAttr(x,y,attr) *zx_cyx2aaddr(y,x) = attr;

#define drawCharLine(x,y,line,data) *(zx_cyx2saddr(y,x)+line*0x100) = data;

extern void drawChar(unsigned char x,unsigned char y,unsigned char *img);

extern void drawWindow(unsigned char x, unsigned char y, unsigned char width, unsigned char height,char *title);
extern void drawProgressBar(unsigned char x, unsigned char y, unsigned char width, unsigned long max, unsigned long current);

#endif
