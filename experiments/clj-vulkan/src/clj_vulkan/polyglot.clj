(ns clj-vulkan.polyglot
  (:require [clojure.reflect :as r])
  (:import [org.graalvm.polyglot Context Source Value]))

(def llvm-context
  (-> (Context/newBuilder (into-array ["llvm" "jvm"]))
      (.allowAllAccess true)
      .build))

(def vulkan
  (.build (Source/newBuilder "llvm" (java.io.File. "/usr/lib/libvulkan.so.1"))))

(def vk
  (.eval llvm-context vulkan))
