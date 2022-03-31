(ns lang.ir)

(def preamble
  ["source_filename = \"none\""
   "target datalayout = \"e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-f80:128-n8:16:32:64-S128\""
   "target triple = \"x86_64-pc-linux-gnu\""])

(defn inst-type [x]
  (cond
    (contains? x :instruction)  (first (:instruction x))
    (contains? x :instructions) :block
    (contains? x :name)         :fn))

(defmulti gen-ll inst-type)

(defmethod )

(def fib
  {:global?    true
   :name       :fib
   :properties {}
   :meta       {}
   :args       [{:type :i32 :name 'i}]
   :blocks     [{:label 'entry
                 :instructions [{:instrunction
                                 [:switch :i32 'i :label 'default
                                  [:i32 0 :label 'return]
                                  [:i32 1 :label 'jump]]}]}
                {:label 'jump
                 :instructions [{:instruction [:br :label 'return]}]}
                {:label 'default
                 :instructions [{:return 'T_1
                                 :instruction [:sub :i32 'i 1]}
                                {:return 'T_2
                                 :instruction [:call :i64 :fib [:i32 'T_1]]}
                                {:return 'T_3
                                 :instruction [:sub :i32 'T_1 1]}
                                {:return 'T_4
                                 :instruction [:call :i64 :fib [:i32 'T_2]]}
                                {:return 'T_5
                                 :instruction [:add :i32 'T_2 'T_4]}
                                {:instruction [:br :label 'return]}]}]})
