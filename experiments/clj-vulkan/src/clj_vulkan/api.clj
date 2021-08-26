(ns clj-vulkan.api
  (:require [clojure.xml :as xml]))

(def api-doc
  (xml/parse (java.io.File. "vk.xml")))
