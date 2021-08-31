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

(defn teardown-vulkan [{:keys [instance context] :as state}]
  (VK11/vkDestroyDevice context nil)
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
          (.ppEnabledLayerNames (c/pbuffer (map c/str validation-layers))) )

        (when (VK11/vkCreateInstance createInfo nil ptr)
          (VkInstance. (.get ptr 0) createInfo))))))

(def queue-flags
  (->> api/enums
       (filter #(= "VkQueueFlagBits" (:name %)))
       first))

(defn bit-check [pos x]
  (odd? (unsigned-bit-shift-right x pos)))

(defn suitable-queue-family? [qf]
  (let [gbit   (->> queue-flags
                    :values
                    (filter #(= "VK_QUEUE_GRAPHICS_BIT" (:name %)))
                    first
                    :value)]
    (bit-check gbit (:queueFlags qf))))

(defn queue-family-index [device]
  (->> device
       lists/queue-families
       (map api/parse)
       (zipmap (range))
       (filter (fn [[k v]] (suitable-queue-family? v)))
       (map key)
       first))

(defn suitable-device? [device]
  (->> device
       lists/queue-families
       (map api/parse)
       (some suitable-queue-family?)))

(defn physical-device [instance]
  (->> #(VK11/vkEnumeratePhysicalDevices instance %1 %2)
       lists/gcalloc
       (map #(VkPhysicalDevice. % instance))
       (filter suitable-device?)
       first))

(defn init-device [device]
  (with-open [stack (MemoryStack/stackPush)]
    (let [qfi      (queue-family-index device)
          qc       (VkDeviceQueueCreateInfo/callocStack 1 stack)
          df       (VkPhysicalDeviceFeatures/callocStack stack)
          dc       (VkDeviceCreateInfo/callocStack stack)
          context& (.pointers stack VK11/VK_NULL_HANDLE)]

      (doto qc
        (.sType VK11/VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO)
        (.queueFamilyIndex qfi)
        (.pQueuePriorities (.floats stack (float 1))))

      (doto dc
        (.sType VK11/VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO)
        (.pQueueCreateInfos qc)
        (.pEnabledFeatures df))

      (when (VK11/vkCreateDevice device dc nil context&)
        (let [context (VkDevice. (.get context& 0) device dc)
              queue&  (.pointers stack VK11/VK_NULL_HANDLE)]
          (VK11/vkGetDeviceQueue context qfi 0 queue&)
          {:context context :queue (VkQueue. (.get queue& 0) context)})))))

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
