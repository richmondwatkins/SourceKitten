//
//  DocCommand.swift
//  SourceKitten
//
//  Created by JP Simard on 2015-01-07.
//  Copyright (c) 2015 SourceKitten. All rights reserved.
//

import Commandant
import Foundation
import Result
import SourceKittenFramework

struct DocCommand: CommandType {
    let verb = "doc"
    let function = "Print Swift docs as JSON or Objective-C docs as XML"

    struct Options: OptionsType {
        let spmModule: String
        let singleFile: Bool
        let moduleName: String
        let objc: Bool
        let arguments: [String]

        static func create(spmModule: String) -> (singleFile: Bool) -> (moduleName: String) -> (objc: Bool) -> (arguments: [String]) -> Options {
            return { singleFile in { moduleName in { objc in { arguments in
                self.init(spmModule: spmModule, singleFile: singleFile, moduleName: moduleName, objc: objc, arguments: arguments)
            }}}}
        }

        static func evaluate(m: CommandMode) -> Result<Options, CommandantError<SourceKittenError>> {
            return create
                <*> m <| Option(key: "spm-module", defaultValue: "", usage: "document a Swift Package Manager module")
                <*> m <| Option(key: "single-file", defaultValue: false, usage: "only document one file")
                <*> m <| Option(key: "module-name", defaultValue: "",    usage: "name of module to document (can't be used with `--single-file` or `--objc`)")
                <*> m <| Option(key: "objc",        defaultValue: false, usage: "document Objective-C headers")
                <*> m <| Argument(defaultValue: [], usage: "Arguments list that passed to xcodebuild. If `-` prefixed argument exists, place ` -- ` before that.")
        }
    }

    func run(options: Options) -> Result<(), SourceKittenError> {
        let args = options.arguments
        if !options.spmModule.isEmpty {
            if let docs = Module(spmName: options.spmModule)?.docs {
                print(docs)
                return .Success()
            }
            return .Failure(.DocFailed)
        } else if options.objc {
            return runObjC(options, args: args)
        } else if options.singleFile {
            return runSwiftSingleFile(args)
        }
        let moduleName: String? = options.moduleName.isEmpty ? nil : options.moduleName
        return runSwiftModule(moduleName, args: args)
    }

    func runSwiftModule(moduleName: String?, args: [String]) -> Result<(), SourceKittenError> {
        let module = Module(xcodeBuildArguments: args, name: moduleName)

        if let docs = module?.docs {
            print(docs)
            return .Success()
        }
        return .Failure(.DocFailed)
    }

    func runSwiftSingleFile(args: [String]) -> Result<(), SourceKittenError> {
        if args.isEmpty {
            return .Failure(.InvalidArgument(description: "at least 5 arguments are required when using `--single-file`"))
        }
        let sourcekitdArguments = Array(args.dropFirst(1))
        if let file = File(path: args[0]),
            docs = SwiftDocs(file: file, arguments: sourcekitdArguments) {
            print(docs)
            return .Success()
        }
        return .Failure(.ReadFailed(path: args[0]))
    }

    func runObjC(options: Options, args: [String]) -> Result<(), SourceKittenError> {
        if args.isEmpty {
            return .Failure(.InvalidArgument(description: "at least 5 arguments are required when using `--objc`"))
        }
        let translationUnit = ClangTranslationUnit(headerFiles: [args[0]], compilerArguments: Array(args.dropFirst(1)))
        print(translationUnit)
        return .Success()
    }
}
