/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2022, Jean-David Gadina - www.xs-labs.com
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the Software), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED AS IS, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 ******************************************************************************/

import Foundation
import ArgumentParser

struct Options: ParsableArguments
{
    @Flag(     help: "Performs a case-insensitive search."            ) var insensitive = false
    @Flag(     help: "Treat every file type as an executable."        ) var all         = false
    @Flag(     help: "Also search in the symbols table."              ) var symbols     = false
    @Flag(     help: "Also search in the Objective-C methods table."  ) var objc        = false
    @Argument( help: "The directory to search."                       ) var path:         String
    @Argument( help: "The strings to search for."                     ) var strings:      [ String ]
}

let options = Options.parseOrExit()

if options.objc, FileManager.default.fileExists( atPath: "/opt/homebrew/bin/macho" ) == false
{
    print( "Error: The macho utility is not installed in /opt/homebrew/bin" )
    print( "Please run: brew install --HEAD macmade/tap/macho" )
    exit( -1 )
}

guard let enumerator = FileManager.default.enumerator( atPath: options.path )
else
{
    print( "Error: Cannot enumerate directory \( options.path )" )
    exit( -1 )
}

let files: [ URL ] = enumerator.compactMap
{
    file in return autoreleasepool
    {
        guard let file = file as? String
        else
        {
            return nil
        }
        
        let url = URL( fileURLWithPath: options.path ).appendingPathComponent( file )
        
        if options.all
        {
            return url
        }
        
        guard FileManager.default.isExecutableFile( atPath: url.path )
        else
        {
            return nil
        }
        
        return url
    }
}

files.forEach
{
    file in autoreleasepool
    {
        let strings     = getStrings( url: file )
        let symbols     = options.symbols ? getSymbols(     url: file ) : []
        let objcMethods = options.objc    ? getObjCMethods( url: file ) : []
        let all         = [ strings, symbols, objcMethods ].flatMap { $0 }
        let matches     = all.filter
        {
            contains( string: $0, search: options.strings )
        }
        
        if matches.isEmpty == false
        {
            print( file.path )
            
            matches.forEach
            {
                print( "    \( $0.trimmingCharacters( in: .whitespaces ) )" )
            }
        }
    }
}

func getLines( command: String, arguments: [ String ] ) -> [ String ]
{
    guard let task    = Task.run( path: command, arguments: arguments, input: nil ),
          let out     = String( data: task.standardOutput, encoding: .utf8 ),
          task.terminationStatus == 0
    else
    {
        return []
    }
    
    return out.components( separatedBy: .newlines )
}

func getStrings( url: URL ) -> [ String ]
{
    getLines( command: "/usr/bin/strings", arguments: [ url.path ] )
}

func getSymbols( url: URL ) -> [ String ]
{
    getLines( command: "/usr/bin/nm", arguments: [ url.path ] )
}

func getObjCMethods( url: URL ) -> [ String ]
{
    getLines( command: "/opt/homebrew/bin/macho", arguments: [ "-m", url.path ] )
}

func contains( string: String, search: [ String ] ) -> Bool
{
    return search.contains
    {
        if options.insensitive
        {
            return string.localizedCaseInsensitiveContains( $0 )
        }
        else
        {
            return string.contains( $0 )
        }
    }
}
