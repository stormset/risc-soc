#!/bin/bash

if [ ! -r $1 ]
then
	echo "Usage: $0 <dlx_assembly_file>.asm"
	exit 1
fi

asmfile=$(basename "$1" .asm)
perl ./assembler/dlxasm.pl -o $asmfile.bin -list $asmfile.list $1
rm $asmfile.bin.hdr
cat $asmfile.bin | hexdump -v -e '/1 "%02X" /1 "%02X" /1 "%02X" /1 "%02X\n"' > $asmfile\.mem
rm $asmfile.bin
rm $asmfile.list

# pad file to required size (parameter #2)
padding="00000000"
let missing=$2-$(cat $asmfile\.mem | wc -l)
for((i=0;i<$missing;i++));do
	echo $padding >> $asmfile\.mem
done
