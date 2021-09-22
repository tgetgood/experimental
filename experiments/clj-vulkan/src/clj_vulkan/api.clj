(ns clj-vulkan.api
  (:require [clojure.string :as str]
            [clojure.walk :as walk]
            [clojure.xml :as xml])
  (:import org.lwjgl.system.MemoryUtil))

(defn invoke [x p]
  (clojure.lang.Reflector/invokeInstanceMethod x p (into-array [])))

(defn lwjgl-read-str [b]
  (-> b
      MemoryUtil/memUTF8Safe
      (str/replace  #"[^a-zA-Z_]" "")
      (str/trim)))

(def api-doc
  (xml/parse (java.io.File. "vk.xml")))

(defn tag
  "Filters `seq` for elements with :tag `t`"
  [t seq]
  (filter #(= t (:tag %)) seq))

(defn tagval [t seq]
  (->> seq (tag t) first :content first))

(defn vname
  "Returns the Vulkan API name of the class of an object"
  [x]
  (-> x
      class
      str
      (str/split #"\.")
      last))

(defn find-type [n]
  (->> api-doc
       xml-seq
       (filter #(= :type (:tag %)))
       (filter #(= n (:name (:attrs %))))
       first))

(defn parse-command [{:keys [attrs content]}]
 ;; TODO: This is a clear use case for spec
  (let [head   (:content (first (tag :proto content)))
        params (tag :param content)]
    {:name (tagval :name head)
     :return (merge attrs
                    {:type (tagval :type head)})
     :params (map (fn [{:keys [content]}]
                    (merge
                     (when (string? (first content))
                       {:attribute (keyword (str/trim (first content)))})
                     (when (= "* " (last (butlast content)))
                       {:pointer true})
                     {:name (tagval :name content)
                      :type (tagval :type content)}))
                  params)}))

(defn find-fn [n]
  (->> api-doc
       xml-seq
       (filter #(= :command (:tag %)))
       (map parse-command)
       (filter #(= n (:name %)))
       first))

(defn p* [x]
  (->> x
       vname
       find-type
       xml-seq
       (filter #(= :member (:tag %)))
       (map :content)
       (map #(filter (comp (partial = :name) :tag) %))
       (map first)
       (map :content)
       (map first)
       (map (fn [p] [(keyword p) (invoke x p)]))
       (map (fn [[k v]] [k (if (= java.nio.DirectByteBuffer (type v))
                             (lwjgl-read-str v)
                             v)]))
       (into {})))

(defn parse [x]
  (walk/prewalk
   (fn [x]
     (let [t (.getName (type x))]
       (if (string/starts-with? t "org.lwjgl.vulkan")
         (p* x)
         x)))
   x))

(defn vname->clj [s]
  s)

(defn parse-enum [node]
  (let [{:keys [name comment]} (-> node :attrs)]
    (merge
     (when comment
       {:doc comment})
     {:name   name
      :values (->> node
                   :content
                   (map :attrs)
                   (mapv (fn [{:keys [name comment value type bitpos]}]
                           (merge
                            {:name            (vname->clj name)
                             :vulkan-api-name name}
                            (when bitpos
                              {:value     (Integer/parseUnsignedInt bitpos)
                               :raw-value value})
                            (when value
                              {:value value})
                            (when comment
                              {:doc comment})
                            (when type
                              {:type type})))))})))

(def enums
  (->> api-doc
       xml-seq
       (filter #(= :enums (:tag %)))
       (map parse-enum)
       (into [])))
