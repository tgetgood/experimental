(ns clj-vulkan.core
  (:require [clj-vulkan.read-list :as lists]
            [clj-vulkan.api :as api]
            [clj-vulkan.c-utils :as c])
  (:import [org.lwjgl.glfw GLFW GLFWVulkan]
           [org.lwjgl.system MemoryStack MemoryUtil Callback]
           [org.lwjgl PointerBuffer]
           [org.lwjgl.vulkan
            EXTDebugUtils
            VkDebugUtilsMessengerCreateInfoEXT
            VkDebugUtilsMessengerCallbackDataEXT
            KHRSurface
            KHRSwapchain
            VK11
            VkDebugUtilsMessengerCallbackEXT
            VkDebugUtilsMessengerCallbackEXTI
            VkApplicationInfo
            VkDeviceQueueCreateInfo
            VkPhysicalDeviceFeatures
            VkDeviceCreateInfo
            VkDevice
            VkInstance
            VkSurfaceCapabilitiesKHR
            VkQueue
            VkInstanceCreateInfo
            VkPhysicalDevice
            VkLayerProperties]))

;;;;;
;; GLFW
;;;;;

(defn create-window [{:keys [width height ^String title]}]
  (when (GLFW/glfwInit)
    (GLFW/glfwWindowHint GLFW/GLFW_CLIENT_API GLFW/GLFW_NO_API)
    (GLFW/glfwWindowHint GLFW/GLFW_RESIZABLE GLFW/GLFW_FALSE)
    (GLFW/glfwCreateWindow (int width) (int height) title c/null c/null)))

(defn teardown-glfw [window]
  (GLFW/glfwDestroyWindow window)
  (GLFW/glfwTerminate))

;;;;; ???

(defn teardown-vulkan [{:keys [instance context surface]}]
  (VK11/vkDestroyDevice context nil)
  (KHRSurface/vkDestroySurfaceKHR instance surface nil)
  (VK11/vkDestroyInstance instance nil))

(defn event-loop [window]
  (loop []
    (when (not (GLFW/glfwWindowShouldClose window))
      (GLFW/glfwPollEvents)
      (recur))))

;;;;;
;; Vulkan init logging
;;;;;

(def debug-logger
  (reify VkDebugUtilsMessengerCallbackEXTI
    (invoke [_ _ _ cb-data _]
      (let [data (VkDebugUtilsMessengerCallbackDataEXT/create cb-data)]
        (println (.pMessageString data))
        VK11/VK_FALSE))))

(defn create-debug-messenger []
  (with-open [stack (MemoryStack/stackPush)]
    (let [ci (VkDebugUtilsMessengerCreateInfoEXT/callocStack stack)]
      (doto ci
        (.sType
         EXTDebugUtils/VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT)

        (.messageSeverity
         (bit-or EXTDebugUtils/VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT
                 EXTDebugUtils/VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT
                 EXTDebugUtils/VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT
                 EXTDebugUtils/VK_DEBUG_UTILS_MESSAGE_SEVERITY_INFO_BIT_EXT))

        (.messageType
         (bit-or EXTDebugUtils/VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT
                 EXTDebugUtils/VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT
                 (EXTDebugUtils/VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT)))

        (.pfnUserCallback debug-logger)))))

(defn check-validation-layers [target]
  (let [supported (into #{} (map #(.layerNameString %)) (lists/validation-layers))]
    (every? #(contains? supported %) target)))

;;;;; Instance creation

(defn create-instance [{:keys [validation-layers]}]
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
          (.ppEnabledLayerNames (c/pbuffer (map c/str validation-layers)))
          (.pNext (.address (create-debug-messenger))))

        (when (= (VK11/vkCreateInstance createInfo nil ptr) VK11/VK_SUCCESS)
          (VkInstance. (.get ptr 0) createInfo))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;; Device selection
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;; Swapchain config

(defn swapchain-support [device surface]
  (with-open [stack (MemoryStack/stackPush)]
    (let [capabilities (VkSurfaceCapabilitiesKHR/mallocStack stack)]
      (KHRSurface/vkGetPhysicalDeviceSurfaceCapabilitiesKHR
       device surface capabilities)
      capabilities)))

;;;;; Queue Selection

(def queue-flags
  (->> api/enums
       (filter #(= "VkQueueFlagBits" (:name %)))
       first))

(defn bit-check [pos x]
  (odd? (unsigned-bit-shift-right x pos)))

(defn suitable-queue-family? [qf]
  (let [gbit (->> queue-flags
                  :values
                  (filter #(= "VK_QUEUE_GRAPHICS_BIT" (:name %)))
                  first
                  :value)]
    (bit-check gbit (:queueFlags qf))))

(defn presentation-support? [i device surface]
  (with-open [stack (MemoryStack/stackPush)]
    (let [p? (.ints stack VK11/VK_FALSE)]

      (KHRSurface/vkGetPhysicalDeviceSurfaceSupportKHR device i surface p?)
      (= VK11/VK_TRUE (.get p? 0)))))

(defn swapchain? [device {:keys [extensions]}]
  (let [supported (->> device
                       lists/device-extensions
                       (map api/parse)
                       (map :extensionName)
                       (into #{}))]
    (every? #(contains? supported %) extensions)))

(defn queue-family-index [device surface]
  (->> device
       lists/queue-families
       (map api/parse)
       (zipmap (range))
       (filter (fn [[k v]] (and (presentation-support? k device surface)
                                (suitable-queue-family? v))))
       (map key)
       first))

(defn suitable-device?
  "Note: We require at present that there exists a device in the system which
  supports a queue family capable of both drawing and presentation. This isn't
  guaranteed to be the case in specialised hardware setups.
  TOOO: Confirm that this *is* a reasonable assumption in most personal
  computing setups."
  [device surface config]
  (and (swapchain? device config) (not (nil? (queue-family-index device surface)))))


(defn physical-device [instance surface config]
  (->> #(VK11/vkEnumeratePhysicalDevices instance %1 %2)
       lists/gcalloc
       (map #(VkPhysicalDevice. % instance))
       (filter #(suitable-device? % surface config))
       first))

(defn create-device [device surface {:keys [validation-layers extensions]}]
  (with-open [stack (MemoryStack/stackPush)]
    (let [qfi      (queue-family-index device surface)
          qc       (VkDeviceQueueCreateInfo/callocStack 1 stack)
          df       (VkPhysicalDeviceFeatures/callocStack stack)
          dc       (VkDeviceCreateInfo/callocStack stack)
          &context (.pointers stack VK11/VK_NULL_HANDLE)]

      (doto qc
        (.sType VK11/VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO)
        (.queueFamilyIndex qfi)
        (.pQueuePriorities (.floats stack (float 1))))

      (doto dc
        (.sType VK11/VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO)
        (.pQueueCreateInfos qc)
        (.ppEnabledLayerNames (c/pbuffer (map c/str validation-layers)))
        (.ppEnabledExtensionNames (c/pbuffer (map c/str extensions)))
        (.pEnabledFeatures df))

      (when (= (VK11/vkCreateDevice device dc nil &context) VK11/VK_SUCCESS)
        (let [context (VkDevice. (.get &context 0) device dc)
              &queue  (.pointers stack VK11/VK_NULL_HANDLE)]
          (VK11/vkGetDeviceQueue context qfi 0 &queue)
          {:context context :queue (VkQueue. (.get &queue 0) context)})))))

;;;;; Surface creation
(defn create-surface [instance window]
  (with-open [stack (MemoryStack/stackPush)]
    (let [&surface (.longs stack VK11/VK_NULL_HANDLE)]
      (let [o  (GLFWVulkan/glfwCreateWindowSurface instance window nil &surface)]
        (when (= VK11/VK_SUCCESS o)
          (.get &surface 0))))))

(defonce graphical-state (atom nil))

(defn start! [config]
  (let [window   (create-window (:window config))
        instance (create-instance config)
        surface  (create-surface instance window)
        pdevice  (physical-device instance surface config)
        device   (create-device pdevice surface config)]
    (reset! graphical-state
            (merge
             {:window          window
              :instance        instance
              :surface         surface
              :physical-device pdevice}
             device))))

(defn stop! []
  (teardown-vulkan @graphical-state)
  (teardown-glfw (:window @graphical-state))
  (reset! graphical-state nil))

(def config
  {:validation-layers #{"VK_LAYER_KHRONOS_validation"}
   :extensions        #{"VK_KHR_swapchain"}
   :window            {:width  800
                       :height 600
                       :title  "CLJ Vulkan test"}})

(defn go! []
  )
