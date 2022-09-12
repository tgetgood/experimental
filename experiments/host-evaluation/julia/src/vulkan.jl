#module Vulkan

function toglfwname(name)
    bits = split(name, r"-")
    reduce(*, map(uppercasefirst, bits), init="glfw")
end

function init()
    ccall(("glfwInit", "libglfw.so"), Cvoid, ())
end

t = Ptr{Cvoid}

function createwindow(width, height, name)
    @eval ccall(("glfwCreateWindow", "libglfw.so"), $t, (Int32, Int32, Cstring, Ptr{Cvoid}, Ptr{Cvoid},), $width, $height, $name, C_NULL, C_NULL)
end
