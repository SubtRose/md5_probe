PROGNAME= myMD5
LFLAGS=
NASMFLAGS= -f elf64 -F dwarf -g -O0 -X gnu -w+x

all: $(PROGNAME)
$(PROGNAME): md5.o
	ld $(LFLAGS) md5.o -o $(PROGNAME)
md5.o: md5.asm
	nasm $(NASMFLAGS) md5.asm -o md5.o

.PHONY: clean

clean: 
	rm -rf *.o $(PROGNAME)
