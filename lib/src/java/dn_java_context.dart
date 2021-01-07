import 'package:antlr4/antlr4.dart';
import 'package:dart_native_codegen/parser/java/Java9Parser.dart';

import 'dn_java_list_op_node.dart';

class DNContext extends ListOpNode {
  ParserRuleContext internal;
  DNContext parent;
  List<DNContext> children;

  DNContext(internal) {
    this.internal = internal;
    this.parent = null;
    this.children = [];
  }

  String parse() {
    return '';
  }

  @override
  ListOpNode enter(ListOpNode enterWhich) {
    if (enterWhich is DNContext) {
      DNContext ctx = enterWhich;
      this.parent = ctx;
      ctx.children.add(this);
    }
    return super.enter(enterWhich);
  }

  @override
  ListOpNode exit() {
    return super.exit();
  }

  bool hasIndentation() {
    return false;
  }

  String calculateIndentation() {
    DNContext node = this;
    String indentation = '';
    while (node != null) {
      if (node.hasIndentation()) {
        indentation += '  ';
      }
      node = node.parent;
    }
    return indentation;
  }
}

class DNRootContext extends DNContext {
  var needExport;

  DNRootContext(internal, needExport) : super(internal) {
    this.needExport = needExport;
  }

  parse() {
    var result = '';
    result +=
        '// Generated by @dartnative/codegen:\n// https://www.npmjs.com/package/@dartnative/codegen\n\n';
    var packageSet = new Set();
    if (!this.needExport) {
      result += "import 'dart:ffi';\n\n";
      result += "import 'package:dart_native/dart_native.dart';\n";
      result += "import 'package:dart_native_gen/dart_native_gen.dart';\n";
      packageSet.add('dart_native');
      packageSet.add('dart_native_gen');
    }
    result += '\n';
    result += this.children.map((ctx) => ctx.parse()).join('\n');
    return (result);
  }
}

class DNClassContext extends DNContext {
  DNClassContext(internal) : super(internal);

  @override
  String parse() {
    var result = '';

    if (internal is ClassDeclarationContext) {
      ClassDeclarationContext aClassDeclarationContext = internal;
      String className = aClassDeclarationContext
          ?.normalClassDeclaration()
          ?.identifier()
          ?.text;
      if (className != null) {
        result += ("class " + className + " {\n");
        result += this.children.map((ctx) => ctx.parse()).join('\n');
        result += ("}\n");
      }
    }
    return result;
  }
}

class DNMethodContext extends DNContext {
  DNMethodContext(internal) : super(internal);

  @override
  String parse() {
    if (internal is MethodDeclarationContext) {
      MethodDeclarationContext aMethodNode = internal;
      if (!checkAssessable(aMethodNode)) {
        return "";
      }
      String blank = calculateIndentation();
      String methodStatement = blank;
      ResultContext aResultNode = aMethodNode.methodHeader()?.result();
      if (aResultNode != null) {
        methodStatement += (aResultNode.text + " ");
      }

      MethodDeclaratorContext aDeclaratorNode =
          aMethodNode?.methodHeader()?.methodDeclarator();
      if (aDeclaratorNode != null) {
        methodStatement += aDeclaratorNode.identifier().text + "(";
        FormalParameterListContext paramsList =
            aDeclaratorNode.formalParameterList();
        if (paramsList != null) {
          FormalParametersContext frontParams = paramsList?.formalParameters();
          if (frontParams != null) {
            frontParams.formalParameters()?.forEach((param) {
              methodStatement += param.unannType().text;
              methodStatement += " ";
              methodStatement += param.variableDeclaratorId().text;
              methodStatement += ", ";
            });
          }

          FormalParameterContext lastParam =
              paramsList?.lastFormalParameter()?.formalParameter();
          if (lastParam != null) {
            methodStatement += lastParam.unannType().text;
            methodStatement += " ";
            methodStatement += lastParam.variableDeclaratorId().text;
          }
        }
        methodStatement += ")";
      }
      methodStatement += " {\n" + blank + "}";
      return methodStatement;
    }
    return "";
  }

  bool checkAssessable(MethodDeclarationContext aMethodNode) {
    var isPublic = false;
    aMethodNode.methodModifiers()?.forEach((m) {
      if (m.PUBLIC() != null) {
        isPublic = true;
      }
    });
    return isPublic;
  }

  bool hasIndentation() {
    return true;
  }
}

class DNFieldContext extends DNContext {
  DNFieldContext(internal) : super(internal);

  @override
  String parse() {
    if (internal is FieldDeclarationContext) {
      FieldDeclarationContext aFieldContext = internal;
      bool isPublic = false;
      aFieldContext.fieldModifiers()?.forEach((aModifierContext) {
        if (aModifierContext.PUBLIC() != null) {
          isPublic = true;
        }
      });
      if (!isPublic) {
        return "";
      }
      String type = aFieldContext.unannType().text;
      String value = aFieldContext
          ?.variableDeclaratorList()
          ?.variableDeclarator(0)
          ?.variableDeclaratorId()
          ?.identifier()
          ?.text;
      if (type != null && value != null) {
        String blank = calculateIndentation();
        String statement = blank;
        statement +=
            type + ' get${toUpperCaseFirstV(value)}(){\n' + blank + '}\n';
        statement += blank +
            'void set${toUpperCaseFirstV(value)}(${type} ${value}){\n${blank}}\n';
        return statement;
      }
    }
    return "";
  }

  @override
  bool hasIndentation() {
    return true;
  }
}

String toUpperCaseFirstV(String value) {
  if (value == null || value.length == 0) {
    return "";
  }
  if (value.length > 1) {
    return '${value[0].toUpperCase()}${value.substring(1)}';
  } else {
    return value.toUpperCase();
  }
}
