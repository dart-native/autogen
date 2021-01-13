import 'dart:io';

import 'package:antlr4/antlr4.dart';
import 'package:dart_native_codegen/parser/java/Java9Parser.dart';
import 'package:dart_native_codegen/src/java/DartJavaCompiler.dart';
import 'package:path/path.dart';

class ListOpNode {
  ListOpNode pre;

  ListOpNode enter(ListOpNode enterWhich) {
    pre = enterWhich;
    return this;
  }

  ListOpNode exit() {
    return pre;
  }
}

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
}

class DNRootContext extends DNContext {
  String packageName;
  JavaFile javaFile;

  // 只有接口/属性里面import的class才会被生成代码
  List<ImportDeclarationContext> _rawImportList = [];
  List<String> _realImportStatement = [];

  // data from imports, record class name and javafile
  Map<String, JavaFile> _importFileMapWithName = {};
  bool _isInitImports = false;

  DNRootContext(internal, JavaFile javaFile) : super(internal) {
    this.javaFile = javaFile;
    this.javaFile.resolve = true;
    CompileContext.getContext().pushFile(this.javaFile);
    CompileContext.getContext().setCurrentCompileRootContext(this);
  }

  void setPackageName(String packageName) {
    this.packageName = packageName;
  }

  void addImport(ImportDeclarationContext import) {
    _rawImportList.add(import);
  }

  String convertType2Dart(String javaType) {
    if (!_isInitImports) {
      _initImports();
    }
    if (_importFileMapWithName.containsKey(javaType)) {
      // class type
      JavaFile javaFile = _importFileMapWithName[javaType];
      String fileName = basenameWithoutExtension(javaFile.path);
      String statement = "import '${fileName}.dart';";
      if (!_realImportStatement.contains(statement)) {
        _realImportStatement.add(statement);
      }
      CompileContext.getContext().pushFile(javaFile);
      return javaType;
    }
    // todo basic type ?
    return javaType;
  }

  void _initImportWithOneFile(File file) {
    String javaFileName = basenameWithoutExtension(file.path);
    if (javaFileName == null) {
      return;
    }
    JavaFile javaFile = new JavaFile();
    javaFile.path = file.path;
    if (!file.existsSync()) {
      javaFile.fileType = FILE_TYPE.aar;
      javaFile.resolve = true;
    } else {
      javaFile.fileType = FILE_TYPE.source_file;
    }
    _importFileMapWithName[javaFileName] = javaFile;
  }

  void _initImports() {
    _rawImportList.forEach((import) {
      String importStatement =
          import.singleTypeImportDeclaration()?.typeName()?.text;
      String javaPath = javaFile.path;
      // win ?
      String fileSep = "/";

      String packagePathId = packageName.replaceAll(".", fileSep);
      int packagePathIndex = javaPath.indexOf(packagePathId);
      if (packagePathIndex < 0) {
        print("cannot find package path: ${packageName}");
        return;
      }

      String rootFilePath = javaPath.substring(0, packagePathIndex);
      String destFilePath =
          rootFilePath + importStatement.replaceAll(".", fileSep);
      if (destFilePath.endsWith(";")) {
        destFilePath = destFilePath.substring(0, destFilePath.length - 1);
      }

      bool isDir = destFilePath.endsWith("*");
      if (isDir) {
        destFilePath = destFilePath.replaceAll('${fileSep}*', fileSep);
      } else {
        destFilePath = destFilePath + ".java";
      }

      // new java file
      if (isDir) {
        Directory dir = new Directory(destFilePath);
        if (!dir.existsSync()) {
          return;
        }
        List<FileSystemEntity> dirSubFiles = dir.listSync();
        dirSubFiles.forEach((file) {
          if (file is File) {
            _initImportWithOneFile(file);
          }
        });
      }

      File destFile = new File(destFilePath);
      _initImportWithOneFile(destFile);
    });
    _isInitImports = true;
  }

  parse() {
    String header = _parseHeader();
    String body = _parseBody();
    // import 要在body后，因为parseBody内会触发对import的计算
    String import = _parseImport();
    return ('${header}\n${import}\n${body}');
  }

  String _parseHeader() {
    var result = '';
    result +=
        '// Generated by @dartnative/codegen:\n// https://www.npmjs.com/package/@dartnative/codegen\n\n';
    result += "import 'dart:ffi';\n\n";
    result += "import 'package:dart_native/dart_native.dart';\n";
    result += "import 'package:dart_native_gen/dart_native_gen.dart';";
    return result;
  }

  String _parseImport() {
    String importStatement = '';
    _realImportStatement.forEach((s) {
      importStatement += '${s}\n';
    });
    return importStatement;
  }

  String _parseBody() {
    return this.children.map((ctx) => ctx.parse()).join('\n');
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
      String methodStatement = '';
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
              methodStatement += CompileContext.getContext()
                  .convertType2Dart(param.unannType().text);
              methodStatement += " ";
              methodStatement += param.variableDeclaratorId().text;
              methodStatement += ", ";
            });
          }

          FormalParameterContext lastParam =
              paramsList?.lastFormalParameter()?.formalParameter();
          if (lastParam != null) {
            methodStatement += CompileContext.getContext()
                .convertType2Dart(lastParam.unannType().text);
            methodStatement += " ";
            methodStatement += lastParam.variableDeclaratorId().text;
          }
        }
        methodStatement += ")";
      }
      methodStatement += "{}";
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
      String type = CompileContext.getContext()
          .convertType2Dart(aFieldContext.unannType().text);
      VariableDeclaratorListContext aDeclaratorListContext =
          aFieldContext.variableDeclaratorList();
      if (aDeclaratorListContext != null) {
        String statement = '';
        aDeclaratorListContext
            ?.variableDeclarators()
            ?.forEach((aDeclaratorContext) {
          String value =
              aDeclaratorContext.variableDeclaratorId()?.identifier()?.text;
          if (type != null && value != null) {
            statement += '${type} get${toUpperCaseFirstV(value)}(){}';
            statement +=
                'void set${toUpperCaseFirstV(value)}(${type} ${value}){}';
          }
        });
        return statement;
      }
    }
    return "";
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
