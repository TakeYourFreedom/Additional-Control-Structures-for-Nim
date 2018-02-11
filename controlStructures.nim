import macros

## This Module provides a number of Control Structures.
## Most of them are just Syntactic Sugar: some Loops,
## better syntax for defining Classes. But there is also
## an Python-like Context-Manager and hopefully some more
## in the future 
##

template unless*(cond: bool, body: untyped) =
  ##if not(cond)  
  if not(cond):
    body


template until*(cond: bool, body: untyped) =
  ##until loop with testing at the beginnings
  while not(cond):
    body


template do_while*(cond: bool, body: untyped) =
  ##while loop with testing at the end
  while true:
    body
    if not (cond):
      break


template do_until*(cond: bool, body: untyped) =
  ##until loop with testing at the end
  while true:
    body
    if (cond):
      break


template do_forever*(body) =
  ##repeat forever
  while true:
    body


template times*(head: int, body: untyped) =
  ##repeat n times
  for i in 1..head:
    body


template do_until_exception*(body) =
  ##Repeat until an exception is raised
  while true:
    try:
      body
    except:
      break


template do_while_exception*(body) = 
  ##Repeat while an exception is raised
  while true:
    try:
      body
      break
    except:
      discard



macro a_if*(head, body: untyped): untyped =
  ##An Arithmetic If similiar to the one in Fortran
  template prepareAST(exp, pos, zero, neg: untyped) =
    case exp:
    of 1..high(int):
      pos
    of 0:
      zero
    of low(int)..(-1):
      neg
    else:
      raise newException(ValueError, "Invalid Value")


  echo $body[0][0]
  if len(body) == 3 and $body[0][0] == "pos" and $body[1][0] == "zero" and $body[2][0] == "neg":
    result = getAst(prepareAST(head, body[0][1], body[1][1], body[2][1]))
  else:
    error "syntaxError"


macro take*(head, body: untyped): untyped =
  ## Python-like Context Manager
  ## Executes 'enter()' on entrance and 'exit()' on exit
  var
    value, varName: NimNode

  if head.kind == nnkInfix and $head[0] == "as":
    value = head[1]
    varName = head[2]
  else:
    error "Invalid node: " & head.lispRepr

  #preparing AST
  template withstmt(a, b:varargs[untyped], c:untyped): untyped =
    block:
      var
        b = a
      
      try:
        enter(b)
      except:
        discard
      
      try:
        c
      except:
        raise
      finally:
        exit(b)

  result = getAst(withstmt(value, varName, body))

proc enter*(a: any) =
  ##general proc for 'take'
  discard

proc exit*(a: any) =
  ##general proc for 'take'
  discard
  

macro class*(head, body: untyped): untyped =
  ##Better Syntax for Class-Definitions
  ## 
  ## ..code-block:: nim
  ##   class Test of RootObj:
  ##     var
  ##       name: string
  ##     proc hello() =
  ##       echo "Hello " & this.name
  ##     method bye() =
  ##       echo "Bye " & this.name
  ## 
  ## gets transformed to:
  ## ..code-block:: nim
  ##   type Test = ref of RootObj
  ##     name: string
  ##   proc hello(this: Test) =
  ##     echo "Hello " & this.name
  ##   method bye(this: Test) {.base.}=
  ##     echo "Bye " & this.name

  var
    className, classType : NimNode 
    exported : bool
    routineDefs : NimNode
    varDefs : NimNode

  varDefs = newNimNode(nnkRecList)
  routineDefs = newStmtList()

  if head.kind == nnkInfix and $head[0] == "of":
    className = head[1]
    classType = head[2]
    exported = false
  elif head.kind == nnkInfix and $head[0] == "*":
    className = head[1]
    classType = head[2][1]
    exported = true
  else:
    error "Invalid Node"

  for node in body:
    if node.kind == nnkProcDef or node.kind == nnkMethodDef:
      routineDefs.add(node)
    elif node.kind == nnkVarSection:
      for i in node:
        if i.kind == nnkIdentDefs:
          varDefs.add(i)

  for node in routineDefs:
    node[3].insert(1, newIdentDefs(ident("this"), className))
    if node.kind == nnkMethodDef:
      node[4] = newNimNode(nnkPragma)
      node[4].add(ident("base"))
  
  
  result = routineDefs

  template typeDecl(a, b: untyped): untyped =
    type a = ref object of b

  template typeDeclPub(a, b: untyped): untyped =
    type a* = ref object of b


  if exported:
    result.insert(0, getAst(typeDeclPub(className, classType)))
  else:
    result.insert(0, getAst(typeDecl(className, classType)))

  result[0][0][2][0][2] = varDefs
