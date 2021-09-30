CFLAGS =  -O1 -g -shared
LDFLAGS = -lglfw -lvulkan -lgraalvm-llvm
LLVM_TOOLS=/usr/lib/jvm/java-11-graalvm/languages/llvm/native/bin

bc: vulkan.c
	${LLVM_TOOLS}/clang $(CFLAGS) vulkan.c $(LDFLAGS) -o vulkan.so
