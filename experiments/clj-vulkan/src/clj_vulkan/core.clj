(ns clj-vulkan.core
  (:import [org.lwjgl.glfw GLFW GLFWVulkan]
           [org.lwjgl.system MemoryStack MemoryUtil]
           [org.lwjgl PointerBuffer]
           [org.lwjgl.vulkan
            VK10
            VkApplicationInfo
            VkInstance
            VkInstanceCreateInfo
            VkLayerProperties]))

(defn reducible-pbuffer [this]
  (reify clojure.lang.IReduce
    (reduce [_ f start]
      (let [capacity (.capacity this)]
        (loop [i   0
               ret start]
          (if (clojure.lang.RT/isReduced ret)
            (deref ret)
            (if (< i capacity)
              (recur (inc i) (.invoke f ret (.get this i)))
              ret)))))
    (reduce [_ f]
      (let [capacity (.capacity this)]
        (when (< 0 capacity)
          (loop [i   1
                 ret (.get this 0)]
            (if (clojure.lang.RT/isReduced ret)
              (deref ret)
              (if (< i capacity)
                (recur (inc i) (.invoke f ret (.get this i)))
                ret))))))))

(def bufvec
  "Given a PointerBuffer, returns a normal vector containing the pointers.")
(defn gcalloc
  "Given a function of 2 args in the vulkan pattern of &count, &ptr, returns a
  vector containing all things pointed to. That's a terrible description."
  ;; Experimental. Read: does not work
  [f & [allocator]]
  (try
    (let [^MemoryStack stack (MemoryStack/stackPush)
          ^ints count-ptr    (.mallocInt stack 1)]
      (f count-ptr nil)
      (let [num  (.get count-ptr 0)
            ptrs (.mallocPointer stack num)]
        (f count-ptr ptrs)
        (into [] (reducible-pbuffer ptrs))))))

(defn validation-layers
  "Returns set of all validation layers supported by this system."
  []
  (gcalloc #(VK10/vkEnumerateInstanceLayerProperties %1 %2))
  #_(try
    (let [stack (MemoryStack/stackPush)
          ptr   (.mallocInt stack 1)]
      ()
      (let [lc         (.get ptr 0)
            layer-ptrs (VkLayerProperties/mallocStack lc stack)]
        (VK10/vkEnumerateInstanceLayerProperties ptr layer-ptrs)
        (into #{} layer-ptrs)))))

(defn check-validation-layers [target]
  (let [supported (into #{} (map #(.layerNameString %)) (validation-layers))]
    (every? #(contains? supported %) target)))

(defn pbuffer
  "Returns a pointer buffer full of `xs` and rewound."
  [xs]
  (let [stack (MemoryStack/stackGet)
        buff (.mallocPointer stack (count xs))]
    (loop [xs xs]
      (when (seq xs)
        (.put buff (first xs))
        (recur (rest xs))))
    (.rewind buff)))

(defn c-str
  "Given a clojure (java) String, returns a pointer to a stack allocated UTF8
   C string. Why? Don't ask. Returns `nil` is `s` is `nil`."
  [s]
  (.UTF8Safe (MemoryStack/stackGet) s))

(def ^Long null MemoryUtil/NULL)

(defn init-window [{:keys [width height ^String title]}]
  (when (GLFW/glfwInit)
    (GLFW/glfwCreateWindow (int width) (int height) title null null)))

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
          (.pApplicationName (c-str "Demo"))
          (.applicationVersion (VK10/VK_MAKE_VERSION 1 0 0))
          (.pEngineName (c-str "No Engine"))
          (.engineVersion (VK10/VK_MAKE_VERSION 1 0 0))
          (.apiVersion VK10/VK_API_VERSION_1_0))

        (doto createInfo
          (.sType VK10/VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO)
          (.pApplicationInfo appInfo)
          (.ppEnabledExtensionNames (GLFWVulkan/glfwGetRequiredInstanceExtensions))
          (.ppEnabledLayerNames (pbuffer (map c-str validation-layers))) )

        (when (VK10/vkCreateInstance createInfo nil ptr)
          (VkInstance. (.get ptr 0) createInfo))))))

(defonce window (atom nil))
(defonce instance (atom nil))

(defn start! [config]
  (reset! window (init-window (:window config)))
  (reset! instance (init-vulkan config)))

(defn stop! []
  (swap! instance teardown-vulkan)
  (swap! window teardown-glfw))


(def config
  {:validation-layers #{"VK_LAYER_KHRONOS_validation"}
   :window            {:width  800
                       :height 600
                       :title "CLJ Vulkan test"}})

(defn go! []
  )
