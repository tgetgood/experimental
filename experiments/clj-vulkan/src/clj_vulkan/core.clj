(ns clj-vulkan.core
  (:require [clj-vulkan.read-list :as lists]
            [clj-vulkan.api :as api]
            [clj-vulkan.c-utils :as c])
  (:import [org.lwjgl.glfw GLFW GLFWVulkan]
           [org.lwjgl.system MemoryStack MemoryUtil]
           [org.lwjgl PointerBuffer]
           [org.lwjgl.vulkan
            VK11
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
  (VK11/vkDestroyInstance instance nil))

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
    (with-open [stack (MemoryStack/stackPush)]
      (let [appInfo    (VkApplicationInfo/callocStack stack)
            createInfo (VkInstanceCreateInfo/callocStack stack)
            ptr        (.mallocPointer stack 1)]

        (doto appInfo
          (.sType VK11/VK_STRUCTURE_TYPE_APPLICATION_INFO)
          (.pApplicationName (c/str "Demo"))
          (.applicationVersion (VK11/VK_MAKE_VERSION 1 0 0))
          (.pEngineName (c/str "No Engine"))
          (.engineVersion (VK11/VK_MAKE_VERSION 1 0 0))
          (.apiVersion VK11/VK_API_VERSION_1_0))

        (doto createInfo
          (.sType VK11/VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO)
          (.pApplicationInfo appInfo)
          (.ppEnabledExtensionNames (GLFWVulkan/glfwGetRequiredInstanceExtensions))
          (.ppEnabledLayerNames (c/pbuffer (map c/str validation-layers))) )

        (when (VK11/vkCreateInstance createInfo nil ptr)
          (VkInstance. (.get ptr 0) createInfo))))))

(def queue-flags
  (->> api/enums
       (filter #(= "VkQueueFlagBits" (:name %)))
       first))

(defn bit-check [pos x]
  (odd? (unsigned-bit-shift-right x pos)))

(defn suitable-device? [device]
  (let [gbit   (->> queue-flags
                    :values
                    (filter #(= "VK_QUEUE_GRAPHICS_BIT" (:name %)))
                    first
                    :value)
        queues (->> device
                    lists/queue-families
                    (map api/parse)
                    (map :queueFlags))]
    (some (partial bit-check gbit) queues)))

(defn physical-device [instance]
  (->> #(VK11/vkEnumeratePhysicalDevices instance %1 %2)
       lists/gcalloc
       (map #(VkPhysicalDevice. % instance))
       (filter suitable-device?)
       first))

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
