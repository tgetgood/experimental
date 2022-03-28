CFLAGS =  -O1 -S -emit-llvm
LDFLAGS = -lglfw -lvulkan -lgraalvm-llvm
LLVM_TOOLS=/usr/lib/jvm/java-17-graalvm/languages/llvm/native/bin

ll: vulkan.c
	clang $(CFLAGS) vulkan.c $(LDFLAGS) -o vulkan.ll
