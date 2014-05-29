;;;; abavus.lisp
;;;; Copyright (c) 2014 Christoph Kohlhepp 

(defpackage :abacus
  ; import namespaces from the following packages
  (:use :common-lisp :optima :let-over-lambda)
 
  ; abacus package exported symbols
  (:export #:amatch 
           #:algebraic-match-with
           #:algebraic-guard
           #:enable-match-syntax
           :left-bracket
           :right-bracket
           :*readtables-stack*))

(in-package #:let-over-lambda)

(export 'defmacro!)

(in-package :abacus)

;;http://dorophone.blogspot.com.au/2008/03/common-lisp-reader-macros-simple.html
;;https://gist.github.com/chaitanyagupta/9324402

(defvar *readtables-stack* nil)

(defconstant left-bracket #\[)
(defconstant right-bracket #\])

(defmacro enable-match-syntax ()
  '(eval-when (:compile-toplevel :load-toplevel :execute)
    (push *readtable* *readtables-stack*)
    (setq *readtable* (copy-readtable))
    (set-macro-character right-bracket 'read-delimiter)
    (set-macro-character left-bracket 'read-left-bracket )))

(defmacro disable-match-syntax ()
  '(eval-when (:compile-toplevel :load-toplevel :execute)
    (setq *readtable* (pop *readtables-stack*))))


(defun tokenequal (x y)
  "A function which compares tokens based on aesthetic rendering equivalence
   deliberately ignoring which package a symbol is interned in; only found to behave
   differently from equalp in the context of reader macros"
  (let ((xstring (format nil "~A" x))
        (ystring (format nil "~A" y)))
    (equal xstring ystring)))


(defun parse-match-elements (elements)
  (format t "~%; compiling ABACUS: parsing elements ~S" elements)
  
  (let ((args (loop
               while (and (not (tokenequal (car elements) '->)) elements)
               collect (prog1
                        (car elements)
                        (setf elements (cdr elements))))))
    (let ((match-expression (cdr elements)))
       (format t "~%; compiling ABACUS: match expression is  ~S" match-expression)
      
       (if (not elements) 
           (error "ABACUS: Empty match [] operation. Args is ~A" args)
           (if (not args)
               (error "ABACUS: No pattern specifier given to match []")
               (if (not (cdr elements))
                   (error "ABACUS: No match expression given to match [~A]" args)
                   (if (member '-> (cdr elements) :test #'tokenequal)
                       (error "ABACUS: Match expression not allowed to contain -> symbol")
                       (progn
                         (format t "~%; compiling ABACUS: generating ~S" 
                            `((,@args) ,@match-expression)) 
                       `((,@args) ,@match-expression)

                       )))))
       )
     ))


(defun read-left-bracket (stream char)
  (declare (ignore char))
  (let* ((match-list (read-delimited-list right-bracket stream t)))
      (parse-match-elements match-list)))

;; We need this as otherwise the simple expression '[x -> x]
;; would fail to parse since x] would be read as an atom resulting in END-OF-FILE
(defun read-delimiter (stream char)
  (declare (ignore stream))
  (error "Delimiter ~S shouldn't be read alone" char))




(defvar abacus-typespec nil) ; only used at compile time
                             ; silence compiler about undefined variable
                             ; at runtime

;; This macro needs no once-only as long as each input
;; is expanded but once. This is presently the case.
;; Adjust if necessary in the future.

(defmacro amatch (arg &body clauses)
"[Macro] amatch
 amatch arg &body clauses
 Same as MATCH, except that handling of algebraic types is enabled"
  (if (not (boundp 'abacus-typespec))
    (defvar abacus-typespec nil))
  `(let  ((abacus-it nil))
     (match ,arg ,@clauses)))


(defmacro algebraic-match-with  (&body clauses)
" Macro wrapper around cl-algebraic:match
  abacus-typespec is generated at compile time by algebraic-guard
  and initially defvar'ed by amatch. 
  abacus-it is also set  by code generated by algebraic-guard
  but at runtime."
  (if (or (not (boundp 'abacus-typespec)) (not abacus-typespec))
      (progn
        (error "~%ALGEBRAIC-MATCH-WITH no type specification! Did you use algebraic-guard?")
        (setf abacus-typespec nil))
      (format t "~%; compiling (ALGEBRAIC-MATCH-WITH over type ~A...)" abacus-typespec))
  `(progn
     ;;(if (not (boundp 'abacus-it ))
     ;;   (warn "~%ALGEBRAIC-MATCH-WITH no match argument! Did you use algebraic-guard?")
        (format t "~%ALGEBRAIC-MATCH-WITH on ~A over type ~A" abacus-it abacus-typespec)
     (adt:match ,abacus-typespec abacus-it ,@clauses)))

;; Note use of o! and g! prefixes.
;; O-Bang provides automatic once-only bindings to gensyms
;; G-Bang dereferences through these gensyms inside the macro
;; These simple prefixes will should make our macro hygenic.
;; We guard the argument in this way, but not the type
;; Dereferencing a type ought to be side-effect free

(defmacro! algebraic-guard  (o!arg argtype)
  "Same as typep, except that it checks for algebraic type also
   and sets the abacus-match local variables abacus-it and abacus-typespec
   to reflect the last guarded instance and type.
   Expects type argument quoted like typep"

   (setf abacus-typespec argtype)
   (format t "~%; compiling (ALGEBRAIC-GUARD over type ~A...)"  abacus-typespec)
   
  `(progn
    (setf abacus-it ,g!arg)
    (and (typep ,g!arg ',argtype )
        (adt:algebraic-data-type-p ',argtype))
  )
)
