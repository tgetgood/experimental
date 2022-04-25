(ns lang.core
  (:gen-class)
  (:require [clojure.edn :as edn]
            [clojure.walk :as walk])
  (:import java.io.File))

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

(defn lisp [expr]
  (try
    (second expr)
    (catch Throwable e
      (println "Error in eval: " e)
      nil)))

(defn stdin-repl []
  (let [r (clojure.java.io/reader System/in)]
    (loop []
      (print "\n> ")
      (flush)
      (when-let [t (.readLine r)]
        (when-let [expr (try (edn/read-string t)
                             (catch Throwable e (println "Error in reader: " e)))]
          (println (lisp expr)))
        (recur)))
    (.close r)))

(defn -main [& args]
  (stdin-repl))
