del *.bin *.exe

rem -------------------------------------------------
rem preklad TAP exporteru

gcc tap_extractor.c -o tap_extractor.exe

rem -------------------------------------------------
rem Exrakce souboru TAP s operacnim systemem ZX Simi

tap_extractor.exe ..\zx_simi_os\a.tap tmp.bin

rem -------------------------------------------------
rem Vytvoreni celeho ROM souboru pro FLASH pamet

copy /B ..\rom\ZXS128_LOAD.ROM +tmp.bin flash.bin

rem -------------------------------------------------
rem Vysledny soubor flash.bin naprogramujte do FLASH pameti
