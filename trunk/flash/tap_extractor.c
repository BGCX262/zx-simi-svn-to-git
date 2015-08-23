#include <stdio.h>

int main(int argc, char * argv[])
{
   FILE * pFile, *oFile;
   int c,length,i;
   
   if (argc != 3) return 1;

   pFile = fopen (argv[1], "rb");
   if (pFile == NULL) perror ("Error opening file");
   oFile = fopen (argv[2], "wb");
   if (oFile == NULL) perror ("Error opening output file");   
   
   else
   {
    do {
      c = getc (pFile);
      length = c;
      c = getc(pFile);
      length += (c<<8); 
      if (c==EOF) break;
      printf("length: %d\n",length);
      
      for (i=0;i<length;i++)
      {
        c = getc (pFile);
        fputc(c,oFile);      
      }
      
    } while (c != EOF);

     fclose (pFile);
     fclose (oFile);
   }
   return 0;
}