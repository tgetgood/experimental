(ns clj-vulkan.api
  (:require [clojure.reflect :as r]
            [clojure.string :as str]
            [clojure.walk :as walk]
            [clojure.xml :as xml])
  (:import org.lwjgl.system.MemoryUtil
           org.lwjgl.vulkan.VK11))

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
                       {:pointer? true})
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
       (if (str/starts-with? t "org.lwjgl.vulkan")
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

(defn type-o-matic
  "Given a vulkan parameter map, return a sensible JVM type for that parameter."
  [{:keys [pointer? type]}]
  (cond
    (and pointer? (= "char" type))     'String
    (and pointer? (= "uint32_t" type)) 'java.nio.IntBuffer

    :else (symbol (str "org.lwjgl.vulkan." type))))

(defn typed-arg [{:keys [name] :as param}]
  (with-meta (symbol name) {:tag (type-o-matic param)}))

;; TODO: The following works for structures, but not for pointers. Abstract the
;; allocator (I really hope I don't have to write a new one) so that it can
;; handle both cases.

(defmacro wrap-enumerate [vk-version n]
  (let [fname    (name n)
        fqfn     (symbol (name vk-version) fname)
        spec     (find-fn fname)
        args     (->> spec :params (drop-last 2) (map typed-arg))
        ret-type (->> spec :params last type-o-matic)]
    `(fn [~@args]
       (with-open [stack# (org.lwjgl.system.MemoryStack/stackPush)]
         (let [^java.nio.IntBuffer c# (.mallocInt stack# 1)]
           (~fqfn ~@args c# nil)
           (let [xs# (~(symbol (name ret-type) "mallocStack") (.get c# 0) stack#)]
             (~fqfn ~@args c# xs#)
             (into [] (map parse) xs#)))))))

;; Should eventually allow invocation of any vk 1.1 fn in an idiomatic
;; way. Currently only manages the "enumerate struct" family of fns.

;; TODO: Make sure the inner `wrap-enumerate` is expanded during AOT
;; compilation. It's not intended to be efficient, but that won't matter if it
;; only happens at compile time.
;; TODO: Also memoise the expansion.
(defmacro call [n & args]
  `((wrap-enumerate org.lwjgl.vulkan.VK11 ~n) ~@args))

(defmacro doc [n]
  `(find-fn ~(name n)))
