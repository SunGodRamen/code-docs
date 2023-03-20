;; Define a base class called `expression` with methods for evaluating the expression and converting it to a string representation.

(defclass expression ()
  ()
  (:abstract t))

(defmethod eval ((expr expression)) 0)

(defmethod to-string ((expr expression)) "")


;; Define subclasses for each mathematical operation (addition, subtraction, multiplication, and division) that inherit from `expression`.

(defclass addition (expression)
  ((operands :accessor operands :initarg :operands))
  (:default-initargs :value 0))

(defmethod eval ((expr addition))
  (reduce #'+ (mapcar #'eval (operands expr))))

(defmethod to-string ((expr addition))
  (format nil "(~{~A~+~})" (mapcar #'to-string (operands expr))))

(defclass subtraction (expression)
  ((operands :accessor operands :initarg :operands))
  (:default-initargs :value 0))

(defmethod eval ((expr subtraction))
  (reduce #'- (mapcar #'eval (operands expr))))

(defmethod to-string ((expr subtraction))
  (format nil "(~A - ~A)" (to-string (first (operands expr))) (to-string (second (operands expr)))))

(defclass multiplication (expression)
  ((operands :accessor operands :initarg :operands))
  (:default-initargs :value 1))

(defmethod eval ((expr multiplication))
  (reduce #'* (mapcar #'eval (operands expr))))

(defmethod to-string ((expr multiplication))
  (format nil "(~{~A~*~})" (mapcar #'to-string (operands expr))))

(defclass division (expression)
  ((numerator :accessor numerator :initarg :numerator)
   (denominator :accessor denominator :initarg :denominator))
  (:default-initargs :value 0))

(defmethod eval ((expr division))
  (/ (eval (numerator expr)) (eval (denominator expr))))

(defmethod to-string ((expr division))
  (format nil "(~A / ~A)" (to-string (numerator expr)) (to-string (denominator expr))))


;; Use macros to generate classes and methods at compile-time based on a list of expressions provided at runtime.

(defmacro define-expr (name value)
  `(progn
     (defclass ,name (expression) () (:default-initargs :value ,value))
     (defmethod eval ((expr ,name)) ,value)
     (defmethod to-string ((expr ,name)) ,(format nil "~A" value))))

(defmacro define-addition (name &rest operands)
  `(progn
     (defclass ,name (addition) ((operands :initform ,(mapcar #'(lambda (x) (list 'quote x)) operands))))
     (defmethod to-string ((expr ,name)) ,(format nil "(~{~A~+~})" (mapcar #'to-string operands)))))

(defmacro define-subtraction (name a b)
  `(progn
     (defclass ,name (subtraction) ((operands :initform ,(list (list 'quote a) (list 'quote b)))))
     (defmethod to-string ((expr ,name)) ,(format nil "(~A - ~A)" (to-string a) (to-string b)))))

(defmacro define-multiplication (name &rest operands)
  `(progn
     (defclass ,name (multiplication) ((operands :initform ,(mapcar #'(lambda (x) (list 'quote x)) operands))))
     (defmethod to-string ((expr ,name)) ,(format nil "(~{~A~*~})" (mapcar #'to-string operands)))))

(defmacro define-division (name numerator denominator)
  `(progn
     (defclass ,name (division) ((numerator :initform ,(list 'quote numerator)) (denominator :initform ,(list 'quote denominator))))
     (defmethod to-string ((expr ,name)) ,(format nil "(~A / ~A)" (to-string numerator) (to-string denominator)))))

(defun add (a b) (make-instance 'addition :operands (list a b)))
(defun sub (a b) (make-instance 'subtraction :operands (list a b)))
(defun mul (a b) (make-instance 'multiplication :operands (list a b)))
(defun div (a b) (make-instance 'division :numerator a :denominator b))

(defun simplify (expr)
  (let ((op (class-name (class-of expr))))
    (cond
      ((eq op 'addition)
       (let ((operands (mapcar #'simplify (operands expr))))
         (if (and (member 0 operands) (< (length operands) 3))
             (if (member 0 operands)
                 (simplify (reduce #'add (remove 0 operands)))
                 (simplify (reduce #'add operands)))
             (make-instance 'addition :operands operands))))
      ((eq op 'subtraction)
       (let ((operands (mapcar #'simplify (operands expr))))
         (if (and (member 0 operands) (< (length operands) 3))
             (if (member 0 operands)
                 (simplify (reduce #'sub (remove 0 operands)))
                 (simplify (reduce #'sub operands)))
             (make-instance 'subtraction :operands operands))))
      ((eq op 'multiplication)
       (let ((operands (mapcar #'simplify (operands expr))))
         (if (member 0 operands)
             0
             (if (member 1 operands)
                 (simplify (remove 1 operands))
                 (make-instance 'multiplication :operands operands))))))
      ((eq op 'division)
       (let ((numerator (simplify (numerator expr)))
             (denominator (simplify (denominator expr))))
         (if (eq (class-name (class-of numerator)) 'addition)
             (simplify (mul numerator (make-instance 'division :numerator denominator :denominator denominator)))
             (if (eq (class-name (class-of denominator)) 'addition)
                 (simplify (div (make-instance 'division :numerator numerator :denominator numerator) denominator))
                 (make-instance 'division :numerator numerator :denominator denominator))))))))

(defmethod simplify ((expr expression)) expr)

(defmethod simplify ((expr addition))
  (let ((operands (mapcar #'simplify (operands expr))))
    (if (and (member 0 operands) (< (length operands) 3))
        (if (member 0 operands)
            (simplify (reduce #'add (remove 0 operands)))
            (simplify (reduce #'add operands)))
        (make-instance 'addition :operands operands))))

(defmethod simplify ((expr subtraction))
  (let ((operands (mapcar #'simplify (operands expr))))
    (if (and (member 0 operands) (< (length operands) 3))
        (if (member 0 operands)
            (simplify (reduce #'sub (remove 0 operands)))
            (simplify (reduce #'sub operands)))
        (make-instance 'subtraction :operands operands))))

(defmethod simplify ((expr multiplication))
  (let ((operands (mapcar #'simplify (operands expr))))
    (if (member 0 operands)
        0
        (if (member 1 operands)
            (simplify (remove 1 operands))
            (make-instance 'multiplication :operands operands))))))

(defmethod simplify ((expr division))
  (let ((numerator (simplify (numerator expr)))
        (denominator (simplify (denominator expr))))
    (if (eq (class-name (class-of numerator)) 'addition)
        (simplify (mul numerator (make-instance 'division :numerator denominator :denominator denominator)))
        (if (eq (class-name (class-of denominator)) 'addition)
            (simplify (div (make-instance 'division :numerator numerator :denominator numerator) denominator))
            (make-instance 'division :numerator numerator :denominator denominator))))))

;; Define some expressions and simplify them using the simplify function.

(let ((a (make-instance 'number :value 3))
      (b (make-instance 'number :value 2))
      (c (make-instance 'number :value 1)))
  (let ((expr1 (add (mul a b) (sub a c)))
        (expr2 (div (add (mul a b) (sub a c)) (add b c)))
        (expr3 (sub (mul a b) (mul c a))))
    (print expr1)
    (print (simplify expr1))
    (print expr2)
    (print (simplify expr2))
    (print expr3)
    (print (simplify expr3))))

