(ns lang.demo
  "Demo program to test the IR generator.")

(def fib
  {:inst       :define
   :name       :fib
   :attrs      "#0"
   :params     [:dso_local]
   :addr-space []
   :unnamed    :local_unnamed_addr
   :meta       {}
   :type       :i64
   :args       [{:type :i32
                 :arg  'i}]
   :blocks     [{:label 'entry
                 :block [{:inst    :switch
                          :type    :i32
                          :switch  'i
                          :default 'default
                          :cases   [[0 'return]
                                    [1 'jump]]}]}
                {:label 'jump
                 :block [{:inst  :br
                          :then 'return}]}
                {:label 'default
                 :block [{:ret  'T_1
                          :inst :sub
                          :type :i32
                          :args ['i 1]}
                         {:ret  'T_2
                          :inst :call
                          :type :i64
                          :fn   :fib
                          :args [{:type :i32
                                  :arg  'T_1}]}
                         {:ret  'T_3
                          :inst :sub
                          :type :i32
                          :args ['T_1 1]}
                         {:ret  'T_4
                          :inst :call
                          :type :i64
                          :fn   :fib
                          :args [{:type :i32
                                  :arg  'T_3}]}
                         {:ret  'T_5
                          :inst :add
                          :type :i64
                          :args ['T_2 'T_4]}
                         {:inst  :br
                          :then 'return}]}
                {:label 'return
                 :block [{:ret       'res
                          :inst      :phi
                          :type      :i64
                          :locations [[1 'jump]
                                      ['T_5 'default]
                                      [0 'entry]]}
                         {:inst :ret
                          :type :i64
                          :arg  'res}]}]})

(def read-input
  {:inst   :define
   :name   :readInput
   :attrs  "#0"
   :type   :i32
   :args   []
   :blocks [{:label 'entry
             :block [{:ret   'A_1
                      :inst  :alloca
                      :type  {:size 10
                              :type :i8}
                      :align 1}
                     {:ret  'A_2
                      :inst :alloca
                      :type :i8}
                     {:inst  :call
                      :type  :i64
                      :fn    :read
                      :args  [{:type :i32
                               :arg  0}
                              {:type :i8*
                               :arg  'A_2}
                              {:type :i64
                               :arg  1}]
                      :attrs :#0}
                     {:ret  'L_1
                      :inst :load
                      :type :i8
                      :arg  'A_2}
                     {:ret  'T_2
                      :inst :icmp
                      :cmp  :eq
                      :type :i8
                      :args ['L_1 10]}
                     {:inst :br
                      :cond {:type :i1
                             :arg  'T_2}
                      :then 'endread
                      :else 'loopread}]}
            {:label 'loopread
             :block [{:ret       'T_3
                      :inst      :phi
                      :type      :i32
                      :locations [['T_6 'loopread]
                                  [0 'entry]]}
                     {:ret       'T_4
                      :inst      :phi
                      :type      :i8
                      :locations [['L_2 'loopread]
                                  ['L_1 'entry]]}
                     {:ret       'T_5
                      :inst      :getelementptr
                      :inbounds? true
                      :type      {:size 10
                                  :type :i8}
                      :ptr       'A_1
                      :args      [{:type :i32
                                   :arg  0}
                                  {:type :i32
                                   :arg  'T_3}]}
                     {:inst :store
                      :type :i8
                      :val  'T_4
                      :ptr  'T_5}
                     {:ret  'T_6
                      :inst :add
                      :type :i32
                      :args [1 'T_3]}
                     {:inst  :call
                      :fn    :read
                      :type  :i64
                      :attrs :#0
                      :args  [{:type :i32
                               :arg  0}
                              {:type   :i8*
                               :params [:nonnull]
                               :arg    'A_2}
                              {:type :i64
                               :arg  1}]}
                     {:ret  'L_2
                      :inst :load
                      :type :i8
                      :arg  'A_2}
                     {:inst :icmp
                      :ret  'T_7
                      :cmp  :eq
                      :type :i8
                      :args ['L_2 10]}
                     {:inst :br
                      :cond {:type :i1
                             :arg  'T_7}
                      :then 'endread
                      :else 'loopread}]}
            {:label 'endread
             :block [{:ret       'T_8
                      :inst      :phi
                      :type      :i32
                      :locations [[0 'entry]
                                  ['T_6 'loopread]]}
                     {:ret  'T_9
                      :inst :add
                      :type :i32
                      :args ['T_8 1]}
                     {:ret   'A_3
                      :inst  :alloca
                      :type  :i8
                      :size  {:type :i32
                              :size 'T_9}
                      :align 16}
                     {:ret  'T_10
                      :inst :icmp
                      :type :i32
                      :cmp  :eq
                      :args ['T_8 0]}
                     {:inst :br
                      :cond {:type :i1
                             :arg  'T_10}
                      :then 'return
                      :else 'memcpy}]}
            {:label 'memcpy
             :block [{:ret  'T_11
                      :inst :bitcast
                      :from {:type :i8
                             :size 10
                             :ptr? 1}
                      :to   :i8*
                      :arg  'A_1}
                     {:inst :call
                      :fn   :llvm.memcpy.p0i8.p0i8.i32
                      :type :void
                      :args [{:type   :i8*
                              :align  16
                              :params [:nonnull]
                              :arg    'A_3}
                             {:type   :i8*
                              :params [:nonnull]
                              :arg    'T_11}
                             {:type :i32
                              :arg  'T_8}
                             {:type :i1
                              :arg  false}]}
                     {:inst :br
                      :then 'return}]}
            {:label 'return
             :block [{:ret       'T_12
                      :inst      :getelementptr
                      :inbounds? true
                      :type      :i8
                      :ptr       'A_3
                      :args      [{:type :i32
                                   :arg  'T_8}]}
                     {:inst :store
                      :type :i8
                      :val  0
                      :ptr  'T_12}
                     {:ret  'T_13
                      :inst :call
                      :type :i64
                      :fn   :strtol
                      :args [{:type   :i8*
                              :params [:nocapture :nonnull]
                              :arg    'A_3}
                             {:type :i8**
                              :arg  :null}
                             {:type :i32
                              :arg  10}]}
                     {:ret  'R_1
                      :inst :trunc
                      :from :i64
                      :to   :i32
                      :arg  'T_13}
                     {:inst :ret
                      :type :i32
                      :arg  'R_1}]}]})

(def main
  {:inst       :define
   :name       :main
   :attrs      "#0"
   :type       :i64
   :params     [:dso_local]
   :addr-space []
   :unnamed    :local_unnamed_addr
   :args       []
   :blocks     [{:block [{:inst :call
                          :ret  'T_1
                          :type :i32
                          :fn   :readInput
                          :args []}
                         {:inst :call
                          :ret  'T_2
                          :type :i64
                          :fn   :fib
                          :args [{:type :i32
                                  :arg  'T_1}]}

                         {:ret   'A_1
                          :inst  :alloca
                          :type  {:size 5
                                  :type :i8}
                          :size  {:type :i8
                                  :size 1}
                          :align 1}
                         {:inst  :store
                          :type  {:type :i8
                                  :size 5}
                          :val   {:type    :i8
                                  :vector? false
                                  :vals    [37 108 100 10 0]}
                          :ptr   'A_1
                          :align 1}
                         {:ret  'A_2
                          :inst :bitcast
                          :from {:type :i8
                                 :size 5
                                 :ptr? 1}
                          :arg  'A_1
                          :to   :i8*}
                         {:inst    :call
                          :type    :i32
                          :fn-type [:i8*, :...]
                          :fn      :printf
                          :args    [{:type   :i8*
                                     :arg    'A_2
                                     :params [:nonnull "dereferenceable(5)"]}
                                    {:type :i64
                                     :arg  'T_2}]}
                         {:inst :ret
                          :type :i64
                          :arg  0}]}]})

(def imports
  [{:inst    :declare
    :name    :read
    :attrs   "#0"
    :type    :i64
    :params  [:noundef]
    :unnamed :local_unnamed_addr
    :args    [{:type   :i32
               :params [:noundef]}
              {:type   :i8*
               :params [:nocapture :noundef]}
              {:type   :i64
               :params [:noundef]}]}
   {:inst    :declare
    :name    :printf
    :attrs   "#0"
    :type    :i32
    :params  [:noundef]
    :unnamed :local_unnamed_addr
    :args    [{:type   :i8*
               :params [:nocapture :noundef :readonly]}
              {:arg :...}]}
   {:inst    :declare
    :name    :strtol
    :attrs   "#0"
    :type    :i64
    :params  [:noundef]
    :unnamed :local_unnamed_addr
    :args    [{:type   :i8*
               :params [:readonly]}
              {:type   :i8**
               :params [:nocapture]}
              {:type :i32}]}
   {:inst  :declare
    :name  :llvm.memcpy.p0i8.p0i8.i32
    :attrs "#0"
    :type  :void
    :args  [{:type   :i8*
             :params [:noalias :nocapture :writeonly]}
            {:type   :i8*
             :params [:noalias :nocapture :readonly]}
            {:type :i32}
            {:type   :i1
             :params [:immarg]}]}])

(def prog
  [fib
   imports
   read-input
   main])
