(ns clj-vulkan.core
  (:import [org.lwjgl PointerBuffer]
           [org.lwjgl.glfw GLFW GLFWVulkan]
           [org.lwjgl.system MemoryUtil MemoryStack]
           [org.lwjgl.vulkan VK10]
           [org.lwjgl.vulkan VkInstance VkApplicationInfo VkInstanceCreateInfo]))

(def null MemoryUtil/NULL)

(defonce window (atom nil))

(defn init-window []
  (when (GLFW/glfwInit)
    (reset! window (GLFW/glfwCreateWindow (int 800) (int 600) "The Window" null null ))))

(defn cleanup []
  (GLFW/glfwDestroyWindow @window)
  (GLFW/glfwTerminate))

(defn event-loop []
  (loop []
    (when (not (GLFW/glfwWindowShouldClose @window))
      (GLFW/glfwPollEvents)
      (recur))))

(defonce instance (atom nil))

(defn init-vulkan []
  (try
    (let [stack      (MemoryStack/stackPush)
          appInfo    (VkApplicationInfo/callocStack stack)
          createInfo (VkInstanceCreateInfo/callocStack stack)
          ptr        (.mallocPointer stack 1)]

      (doto appInfo
        (.sType VK10/VK_STRUCTURE_TYPE_APPLICATION_INFO)
        (.pApplicationName (.UTF8Safe stack "Demo"))
        (.applicationVersion (VK10/VK_MAKE_VERSION 1 0 0))
        (.pEngineName (.UTF8Safe stack "No Engine"))
        (.engineVersion (VK10/VK_MAKE_VERSION 1 0 0))
        (.apiVersion VK10/VK_API_VERSION_1_0))

      (doto createInfo
        (.sType VK10/VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO)
        (.pApplicationInfo appInfo)
        (.ppEnabledExtensionNames (GLFWVulkan/glfwGetRequiredInstanceExtensions))
        (.ppEnabledLayerNames nil))

      (when (VK10/vkCreateInstance createInfo nil ptr)
        (reset! instance (VkInstance. (.get ptr 0) createInfo))))))
