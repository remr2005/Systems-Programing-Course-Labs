nasm -f bin boot.asm -o boot.bin
nasm -f bin stage2.asm -o stage2.bin
dd if=/dev/zero of=floppy.img bs=512 count=2880
dd if=boot.bin of=floppy.img conv=notrunc
dd if=stage2.bin of=floppy.img bs=512 seek=1 conv=notrunc
