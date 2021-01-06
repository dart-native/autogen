import 'package:antlr4/antlr4.dart';
import 'package:dart_native_codegen/parser/java/Java9Parser.dart';

class DNContext {
  ParserRuleContext internal;
  DNContext parent;
  List<DNContext> children;

  DNContext(internal) {
    this.internal = internal;
    this.parent = null;
    this.children = [];
  }

  void addChild(ctx) {
    ctx.parent = this;
    this.children.add(ctx);
  }

  String parse() {
    return '';
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
    // result += this.children.map(ctx => {
    //     var childResult = ctx.parse()
    //     // if (!(ctx is DNImportContext)) {
    //     //     childResult = '\n' + childResult
    //     // } else {
    //     packageSet.add(ctx.package)
    //     // }
    //     return childResult
    // }).join('\n');
    result += this.children.map((ctx) => ctx.parse()).join('\n');
    return (result);
  }
}

class DNMethodContext extends DNContext {
  DNMethodContext(internal) : super(internal);

  @override
  String parse() {
    if (internal is MethodDeclarationContext) {
      MethodDeclarationContext antrlMethodNode = internal;
      List<MethodModifierContext> antrlModifiers =
          antrlMethodNode.methodModifiers();
      String methodStatement = "";
      var isPublic = false;
      antrlModifiers.forEach((m) {
        if (m.PUBLIC() != null) {
          isPublic = true;
          methodStatement += "public ";
        } else if (m.FINAL() != null) {
          methodStatement += "final";
        }
      });
      if (!isPublic) {
        return "";
      }
      // TODO handle static modifier
      MethodHeaderContext antrlHeaderNode = antrlMethodNode.methodHeader();
      ResultContext antrlResultNode = antrlHeaderNode.result();
      if (antrlResultNode != null) {
        methodStatement += (antrlResultNode.text + " ");
      }

      MethodDeclaratorContext antrlDeclaratorNode =
          antrlHeaderNode.methodDeclarator();
      if (antrlDeclaratorNode != null) {
        methodStatement += antrlDeclaratorNode.identifier().text;
        methodStatement += "(";
        FormalParameterListContext paramsList =
            antrlDeclaratorNode.formalParameterList();
        if (paramsList != null) {
          paramsList.children.forEach((node) {
            if (node is FormalParametersContext) {
              FormalParametersContext frontParams = node;
              frontParams.formalParameters()?.forEach((param) {
                methodStatement += param.unannType().text;
                methodStatement += " ";
                methodStatement += param.variableDeclaratorId().text;
                methodStatement += ", ";
              });
            } else if (node is LastFormalParameterContext) {
              LastFormalParameterContext one = node;
              FormalParameterContext param = one.formalParameter();
              if (param != null) {
                methodStatement += param.unannType().text;
                methodStatement += " ";
                methodStatement += param.variableDeclaratorId().text;
              }
            }
          });
        }
        methodStatement += ")";
      }
      methodStatement += "{}";

      return methodStatement;
    }
    return "";
  }
}
