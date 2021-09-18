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
            VK11
            VkDebugUtilsMessengerCallbackEXT
            VkDebugUtilsMessengerCallbackEXTI
            VkApplicationInfo
            VkDeviceQueueCreateInfo
            VkPhysicalDeviceFeatures
            VkDeviceCreateInfo
            VkDevice
            VkInstance
            VkQueue
            VkInstanceCreateInfo
            VkPhysicalDevice
            VkLayerProperties]))


(defn check-validation-layers [target]
  (let [supported (into #{} (map #(.layerNameString %)) (lists/validation-layers))]
    (every? #(contains? supported %) target)))


(defn init-window [{:keys [width height ^String title]}]
  (when (GLFW/glfwInit)
    (GLFW/glfwCreateWindow (int width) (int height) title c/null c/null)))

(defn teardown-vulkan [{:keys [instance context surface] :as state}]
  (VK11/vkDestroyDevice context nil)
  (KHRSurface/vkDestroySurfaceKHR instance surface nil)
  (VK11/vkDestroyInstance instance nil)
  nil)

(defn teardown-glfw [window]
  (GLFW/glfwDestroyWindow window)
  (GLFW/glfwTerminate))

(defn event-loop [window]
  (loop []
    (when (not (GLFW/glfwWindowShouldClose window))
      (GLFW/glfwPollEvents)
      (recur))))

(def dbl
  (proxy [VkDebugUtilsMessengerCallbackEXT]
      []
    (invoke [a b cb-data d]
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

        (.pfnUserCallback dbl)))))

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

(def queue-flags
  (->> api/enums
       (filter #(= "VkQueueFlagBits" (:name %)))
       first))

(defn bit-check [pos x]
  (odd? (unsigned-bit-shift-right x pos)))

(defn suitable-queue-family? [opts qf]
  (let [gbit   (->> queue-flags
                    :values
                    (filter #(= "VK_QUEUE_GRAPHICS_BIT" (:name %)))
                    first
                    :value)]
    (bit-check gbit (:queueFlags qf))))

(defn queue-family-index [opts device]
  (->> device
       lists/queue-families
       (map api/parse)
       (zipmap (range))
       (filter (fn [[k v]] (suitable-queue-family? opts v)))
       (map key)
       first))

(defn suitable-device? [opts device]
  (->> device
       lists/queue-families
       (map api/parse)
       (some suitable-queue-family?)))

(defn physical-device [{:keys [surface instance]}]
  (->> #(VK11/vkEnumeratePhysicalDevices instance %1 %2)
       lists/gcalloc
       (map #(VkPhysicalDevice. % instance))
       (filter (partial suitable-device? {:surface surface}))
       first))

(defn init-device [device]
  (with-open [stack (MemoryStack/stackPush)]
    (let [qfi      (queue-family-index device)
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
        (.pEnabledFeatures df))

      (when (= (VK11/vkCreateDevice device dc nil &context) VK11/VK_SUCCESS)
        (let [context (VkDevice. (.get &context 0) device dc)
              &queue  (.pointers stack VK11/VK_NULL_HANDLE)]
          (VK11/vkGetDeviceQueue context qfi 0 &queue)
          {:context context :queue (VkQueue. (.get &queue 0) context)})))))

(defn create-surface [instance window]
  (with-open [stack (MemoryStack/stackPush)]
    (let [&surface (.longs stack VK11/VK_NULL_HANDLE)]
      (let [o  (GLFWVulkan/glfwCreateWindowSurface instance window nil &surface)]
        (println o)
        (when (= VK11/VK_SUCCESS o)
          (.get &surface 0))))))

(defn init-vulkan [opts]
  (let [instance                (create-instance opts)
        device                  (physical-device instance)
        {:keys [context queue]} (init-device device)]
    {:instance instance
     :device   device
     :context  context
     :queue    queue}))


(defonce graphical-state (atom nil))

(defn start! [config]
  (swap! graphical-state assoc :window (init-window (:window config)))
  (swap! graphical-state assoc :vulkan (init-vulkan config)))

(defn stop! []
  (swap! graphical-state update :vulkan teardown-vulkan)
  (swap! graphical-state update :window teardown-glfw))


(def config
  {:validation-layers #{"VK_LAYER_KHRONOS_validation"}
   :window            {:width  800
                       :height 600
                       :title "CLJ Vulkan test"}})

(defn go! []
  )
