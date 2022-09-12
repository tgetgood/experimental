(def glfw
  {:lib "libglfw.so"
   :fns {:init           {:ret  :void
                          :args []}
         :terminate      {:ret  :void
                          :args []}
         :create-window  {:ret  :void*
                          :args [:i32 :i32 :string :void* :void*]}
         :destroy-window {:ret  :void
                          :args [:void*]}}})
