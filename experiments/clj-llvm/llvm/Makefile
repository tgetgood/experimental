CFLAGS =  -O1 -S -emit-llvm
LDFLAGS = #-lglfw -lvulkan 

ll: example.c
	clang $(CFLAGS) example.c $(LDFLAGS) -o example.ll
