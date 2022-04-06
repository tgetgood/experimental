// #include <GLFW/glfw3.h>
// #include <vulkan/vulkan.h>
#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>

long fib(int i) {
  if (i == 0) {
      return 0;
    } else if (i == 1) {
      return 1;
    } else {
    return fib(i - 1) + fib(i - 2);
  }
}

int readInput() {
  char buf[10];
  int i = 0;
  char next;

  while (1) {
    read(STDIN_FILENO, &next, 1);
    if (next == '\n') {
      break;
    } else {
      buf[i] = next;
      i++;
    }
  }

  char num[i+1];
  for(int j = 0; j < i; j++) {
    num[j] = buf[j];
  }

  num[i] = '\0';

  int res = atoi(num);

  return res;
}

int main() {
  int i = readInput();
  printf("%ld\n", fib(i));
}
