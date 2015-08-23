//bazova adresa DMA radice
#define DMA_BASE_ADDR 0xF3

//registr pro ulozeni cilove adresy (kam se bude ukladat)
#define DMA_DEST_ADDR0 (0x0000 + DMA_BASE_ADDR)
#define DMA_DEST_ADDR1 (0x0100 + DMA_BASE_ADDR)
#define DMA_DEST_ADDR2 (0x0200 + DMA_BASE_ADDR)

//registr pro odeslani jednoho bajtu
#define DMA_SEND_BYTE (0x0300 + DMA_BASE_ADDR)

//registr pro ulozeni zdrojove adresy (odkud se bude nacitat)
#define DMA_SRC_ADDR0 (0x0400 + DMA_BASE_ADDR)
#define DMA_SRC_ADDR1 (0x0500 + DMA_BASE_ADDR)
#define DMA_SRC_ADDR2 (0x0600 + DMA_BASE_ADDR)

//registr pro ulozeni delky prenaseneho bloku
#define DMA_LENGTH0 (0x0700 + DMA_BASE_ADDR)
#define DMA_LENGTH1 (0x0800 + DMA_BASE_ADDR)

//konfiguracni registr
#define DMA_CONFIG (0x0900 + DMA_BASE_ADDR)



//priznak inkrementace cilove adresy
#define DMA_INC_DST 0x01
//cilova adresa je IO
#define DMA_IORQ_DST 0x02

//priznak inkrementace zdrojove adresy
#define DMA_INC_SRC 0x10
//zdrojova adresa je IO
#define DMA_IORQ_SRC 0x20



/**
 * Nastavi cilovou fyzickou adresu
 * 
 * @param addr  Fyzicka adresa
 */ 
extern void dmaSetDestAddr(unsigned long addr);

/**
 * Nastavi zdrojovou fyzickou adresu
 * 
 * @param addr  Fyzicka adresa  
 */ 
extern void dmaSetSrcAddr(unsigned long addr);

/**
 * Nastavi konfiguraci DMA radice
 * 
 * @param conf  Konfigurace  
 */ 
extern void dmaSetConfig(unsigned char conf);

/**
 * Prenese blok dat o zadane delce
 * 
 * @param length    Delka prenasenych dat  
 */ 
extern void dmaTransfer(unsigned int length);

/**
 * Precte jeden bajt
 */ 
#define dmaReadByte() inp(DMA_BASE_ADDR)

/**
 * Ulozi jeden bajt
 */ 
extern void dmaSendByte(unsigned char byte);

extern unsigned long swAddr2hwAddr(unsigned long addr);
