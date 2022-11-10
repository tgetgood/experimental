(ns xprl.core
  (:refer-clojure :exclude [eval]))

(def trivial
  "(defn f [x] (conj [] x)))")

(def less-trivial
  "(defn apply [env ^{quote fn} _ [args body]] ^Fn {:env env :args args :body body})")


(defn eval-xprl [env form]
  )
