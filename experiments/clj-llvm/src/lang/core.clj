(ns lang.core
  (:refer-clojure :exclude [compile])
  (:require [clojure.walk :as walk])
  (:import java.io.File))

(defn label [] (str (gensym)))
(defn local [] (str "%" (name (gensym))))
(defn global [] (str "@" (name (gensym))))

(defn grun
  "Ghetto run shell `cmd`."
  [cmd]
  (let [p (.exec (Runtime/getRuntime) cmd)]
    {:exit   (.waitFor p)
     :stdout (slurp (.getInputStream p))
     :stderr (slurp (.getErrorStream p))}))

(defn tempfile []
  (let [f (File/createTempFile "intermediate" ".ll")]
    (.deleteOnExit f)
    {:path (.getAbsolutePath f)
     :file f}))

(def preamble
  ["source_filename = \"none\""
   "target datalayout = \"e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-f80:128-n8:16:32:64-S128\""
   "target triple = \"x86_64-pc-linux-gnu\""])

(def then-block
  {:type :block
   :name 1
   :content
   [:br :label :%9]})

(def fib
  {:type   :fn
   :name   :fib
   :args   [{:type :i32 :name 0}]
   :blocks {1 {:type :block
               :body {1 {}}}}
   :meta   {}})

(def fib
  '(fn [i]
     (cond
       (= i 0) 0
       (= i 1) 1
       true    (+ (fib (- i 1)) (fib (- i 2))))))

(defmulti dispatch first)

(defmethod dispatch :default
  [x]
  (throw (Exception. (str "unsupported form " (str x)))))

(defmethod dispatch 'fn
  [[_ args & body]]
  )

(defn check-num [x]
  (if (integer? x)
    x
    (throw (Exception. (str "unsupported number: " x)))))

(defn compile [form]
  (walk/postwalk
   (fn [x]
     (cond
       (number? x)                         (check-num x)
       (string? x)                         x
       (vector? x)                         x
       (map? x)                            x
       (and (list? x) (symbol? (first x))) (dispatch x)
       :else                               x))
   form))
