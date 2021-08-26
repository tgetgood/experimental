(ns clj-vulkan.c-utils
  "Utility ns for hiding the C like parts of the vulkan api."
  (:refer-clojure :exclude [str])
  (:import [org.lwjgl.system MemoryStack MemoryUtil]))

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

(defn str
  "Given a clojure (java) String, returns a pointer to a stack allocated UTF8
   C string. Why? Don't ask. Returns `nil` if `s` is `nil`."
  [^String s]
  (.UTF8Safe (MemoryStack/stackGet) s))

(def ^Long null MemoryUtil/NULL)
