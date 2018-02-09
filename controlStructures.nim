import macros


template unless*(cond: bool, body: untyped) =
  if not(cond):
    body


template until*(cond: bool, body: untyped) =
  while not(cond):
    body


template do_while*(cond: bool, body: untyped) =
  while true:
    body
    if not (cond):
      break


template do_until*(cond: bool, body: untyped) =
  while true:
    body
    if (cond):
      break


template do_forever*(body) =
  while true:
    body


template do_until_exception*(body) =
  while true:
    try:
      body
    except:
      break


template do_while_exception*(body) = 
  while true:
    try:
      body
      break
    except:
      discard


## Python-like Context Manager
## Executes 'enter()' on entrance and 'exit()' on exit
macro with*(head, body: untyped): untyped =
  var
    value, varName: NimNode

  if head.kind == nnkInfix and $head[0] == "as":
    value = head[1]
    varName = head[2]

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

