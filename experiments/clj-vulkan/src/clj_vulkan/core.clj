(ns clj-vulkan.core
  (:require [clj-vulkan.read-list :as lists]
            [clj-vulkan.c-utils :as c])
  (:import [org.lwjgl.glfw GLFW GLFWVulkan]
           [org.lwjgl.system MemoryStack MemoryUtil]
           [org.lwjgl PointerBuffer]
           [org.lwjgl.vulkan
            VK10
            VkApplicationInfo
            VkInstance
            VkInstanceCreateInfo
            VkPhysicalDevice
            VkLayerProperties]))


(defn check-validation-layers [target]
  (let [supported (into #{} (map #(.layerNameString %)) (lists/validation-layers))]
    (every? #(contains? supported %) target)))


(defn init-window [{:keys [width height ^String title]}]
  (when (GLFW/glfwInit)
    (GLFW/glfwCreateWindow (int width) (int height) title c/null c/null)))

(defn teardown-vulkan [instance]
  (VK10/vkDestroyInstance instance nil))

(defn teardown-glfw [window]
  (GLFW/glfwDestroyWindow window)
  (GLFW/glfwTerminate))

(defn event-loop [window]
  (loop []
    (when (not (GLFW/glfwWindowShouldClose window))
      (GLFW/glfwPollEvents)
      (recur))))

(defn init-vulkan [{:keys [validation-layers]}]
  (when (check-validation-layers validation-layers)
    (try
      (let [stack      (MemoryStack/stackPush)
            appInfo    (VkApplicationInfo/callocStack stack)
            createInfo (VkInstanceCreateInfo/callocStack stack)
            ptr        (.mallocPointer stack 1)]

        (doto appInfo
          (.sType VK10/VK_STRUCTURE_TYPE_APPLICATION_INFO)
          (.pApplicationName (c/str "Demo"))
          (.applicationVersion (VK10/VK_MAKE_VERSION 1 0 0))
          (.pEngineName (c/str "No Engine"))
          (.engineVersion (VK10/VK_MAKE_VERSION 1 0 0))
          (.apiVersion VK10/VK_API_VERSION_1_0))

        (doto createInfo
          (.sType VK10/VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO)
          (.pApplicationInfo appInfo)
          (.ppEnabledExtensionNames (GLFWVulkan/glfwGetRequiredInstanceExtensions))
          (.ppEnabledLayerNames (c/pbuffer (map c/str validation-layers))) )

        (when (VK10/vkCreateInstance createInfo nil ptr)
          (VkInstance. (.get ptr 0) createInfo))))))

(def suitable-device? (constantly true))

(defn physical-device [instance]
  (->> #(VK10/vkEnumeratePhysicalDevices instance %1 %2)
       lists/gcalloc
       (map #(VkPhysicalDevice. % instance))
       (filter suitable-device?)
       first))

(defn queue-families [device]
  (->> #(VK10/vkGetPhysicalDeviceQueueFamilyProperties device %1 %2)
       lists/gcalloc))

(defonce graphical-state (atom nil))

(defn start! [config]
  (swap! graphical-state assoc :window (init-window (:window config)))
  (swap! graphical-state assoc :instance (init-vulkan config))
  (swap! graphical-state #(assoc % :device (physical-device (:instance %)))))

(defn stop! []
  (swap! graphical-state update :instance teardown-vulkan)
  (swap! graphical-state update :window teardown-glfw))


(def config
  {:validation-layers #{"VK_LAYER_KHRONOS_validation"}
   :window            {:width  800
                       :height 600
                       :title "CLJ Vulkan test"}})

(defn go! []
  )
