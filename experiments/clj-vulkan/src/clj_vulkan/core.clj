(ns clj-vulkan.core
  (:import [org.graalvm.polyglot Context Source]
           [org.graalvm.polyglot.io ByteSequence]))

(def context
  (-> (Context/newBuilder (into-array ["llvm"]))
      (.allowNativeAccess true)
      ;; FIXME: Ideally, we'd create a new FileSystem with only the native libs
      ;; we need.
      (.allowIO true)
      .build))

(def clang-cmd
  (into-array
   ["/usr/lib/jvm/java-11-graalvm/languages/llvm/native/bin/clang"
    "-flto"
    "-O1"]))

(defn assemble
  "Takes a string representing llvm IR, and a Graal Source object."
  ;; TODO: Dump the code in a temp file, compile to another tempfile, read elf
  ;; into ram and delete both files.
  ;; What about repeatability and persistence? The pipeline is not
  ;; stable. Anything we delete will not necessarily be reconstructable.
  [ir]
  (let [p      (.exec (Runtime/getRuntime) clang-cmd)
        stdin  (-> p
                   .getOutputStream
                   java.io.OutputStreamWriter.
                   java.io.BufferedWriter.)
        stdout (-> p
                   .getInputStream
                   java.io.InputStreamReader.
                   java.io.BufferedReader.)]
    (doto stdin
      (.write ir)
      .flush
      .close)
    (.waitFor p)
    (-> stdout
        slurp
        .getBytes
        ByteSequence/create)))

(defn source [code]
  (.buildLiteral (Source/newBuilder "llvm" (assemble code) "<literal>")))

(def code
  "

define i64 @addtest(i64 %x, i64 %y) {
  %1 = add i64 %x, %y
  ret i64 %1
}

define i64 @main() {
  %1 = call i64 @addtest (i64 7, i64 19)
  ret i64 %1
}
")


(defn f [x]
  (+ x :12))
