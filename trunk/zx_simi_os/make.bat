del *.ROM *.o *.BIN *.TAP

zcc -vn -Wall -c textgui.c
zcc -vn -Wall -c dma.c
zcc -vn -Wall -c sdcard.c
zcc -vn -Wall -c fat32.c
zcc -vn -Wall -c filesystem.c
zcc -vn -Wall -c task.c
zcc -vn -Wall -c keyboard.c
zcc -vn -Wall -c file_z80.c
zcc -vn -Wall -c file_sna.c
zcc -vn -Wall -c file_rom.c
zcc -vn -Wall -c file_tap.c
zcc -vn -Wall -c file_tzx.c

zcc +zx -create-app -vn -Wall -lndos dma.o sdcard.o fat32.o filesystem.o task.o keyboard.o textgui.o file_z80.o file_sna.o file_rom.o file_tap.o file_tzx.o zxsimi.c
