import macros

##unless branch
template unless*(cond: bool, body: untyped) =
  if not(cond):
    body

##until loop with testing at the beginning
template until*(cond: bool, body: untyped) =
  while not(cond):
    body

##while loop with testing at the end
template do_while*(cond: bool, body: untyped) =
  while true:
    body
    if not (cond):
      break

##until loop with testing at the end
template do_until*(cond: bool, body: untyped) =
  while true:
    body
    if (cond):
      break

##repeat forever
template do_forever*(body) =
  while true:
    body

##repeat n times
template times*(head: int, body: untyped) =
  for i in 1..head:
    body

##Repeat until an exception is raised
template do_until_exception*(body) =
  while true:
    try:
      body
    except:
      break

##Repeat while an exception is raised
template do_while_exception*(body) = 
  while true:
    try:
      body
      break
    except:
      discard

##Arithmetic If
macro a_if*(head, body: untyped): untyped =

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

## Python-like Context Manager
## Executes 'enter()' on entrance and 'exit()' on exit
macro with*(head, body: untyped): untyped =
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
  discard

proc exit*(a: any) =
  discard
  
##Python-like Class Definitions
macro class*(head, body: untyped): untyped =
  var
    typeName, baseName: NimNode
    exported: bool

  if head.kind == nnkInfix and $head[0] == "of":
    typeName = head[1]
    baseName = head[2]
  elif head.kind == nnkInfix and $head[0] == "*" and head[2].kind == nnkPrefix and $head[2][0] == "of":
    typeName = head[1]
    baseName = head[2][1]
    exported = true
  else:
    error "Invalid node: " & head.lispRepr

  template typeDecl(a, b): untyped =
    type a = ref object of b

  template typeDeclPub(a, b): untyped =
    type a* = ref object of b

  if exported:
    result = getAst(typeDeclPub(typeName, baseName))
  else:
    result = getAst(typeDecl(typeName, baseName))

  var recList = newNimNode(nnkRecList)

  let ctorName = newIdentNode("new" & $typeName)

  for node in body.children:
    case node.kind:
    of nnkMethodDef, nnkProcDef:
      if node.name.kind != nnkAccQuoted and node.name.basename == ctorName:
        node.params[0] = typeName
      else:
        node.params.insert(1, newIdentDefs(ident("self"), typeName))
      result.add(node)
    of nnkVarSection:
      for n in node.children:
        recList.add(n)
    else:
      result.add(node)
  result[0][0][2][0][2] = recList
