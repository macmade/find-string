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
    @Flag(     help: "Also search in the symbols table."              ) var symbols     = false
    @Flag(     help: "Also search in the Objective-C methods table."  ) var objc        = false
    @Argument( help: "The directory to search."                       ) var path:         String
    @Argument( help: "The strings to search for."                     ) var strings:      [ String ]
}

let options = Options.parseOrExit()

guard let enumerator = FileManager.default.enumerator( atPath: options.path )
else
{
    print( "Error: Cannot enumerate directory \( options.path )" )
    exit( -1 )
}

enum FileType
{
    case machO
    case windowsPE
}

let files: [ ( url: URL, type: FileType ) ] = enumerator.compactMap
{
    file in return autoreleasepool
    {
        guard let file = file as? String
        else
        {
            return nil
        }
        
        let url = URL( fileURLWithPath: options.path ).appendingPathComponent( file )
        
        if FileManager.default.isExecutableFile( atPath: url.path ) || isMachO( url: url )
        {
            return ( url, .machO )
        }
        
        if url.pathExtension == "exe" || url.pathExtension == "dll" || isWindowsPE( url: url )
        {
            return ( url, .windowsPE )
        }
        
        return nil
    }
}

if options.objc, FileManager.default.fileExists( atPath: "/opt/homebrew/bin/macho" ) == false
{
    print( "Error: The macho utility is not installed in /opt/homebrew/bin" )
    print( "Please run: brew install macmade/tap/macho" )
    exit( -1 )
}


if files.contains( where: { $0.type == .windowsPE } ), FileManager.default.fileExists( atPath: "/opt/homebrew/bin/rpecli" ) == false
{
    print( "Error: The rpecli utility is not installed in /opt/homebrew/bin" )
    print( "Please run: brew install macmade/tap/rpecli" )
    exit( -1 )
}

files.forEach
{
    file in autoreleasepool
    {
        let strings     = getStrings( file: file )
        let symbols     = options.symbols ? getSymbols(     file: file ) : []
        let objcMethods = options.objc    ? getObjCMethods( file: file ) : []
        let all         = [ strings, symbols, objcMethods ].flatMap { $0 }
        let matches     = all.filter
        {
            contains( string: $0, search: options.strings )
        }
        
        if matches.isEmpty == false
        {
            print( file.url.path )
            
            matches.forEach
            {
                print( "    \( $0.trimmingCharacters( in: .whitespaces ) )" )
            }
        }
    }
}

func isMachO( url: URL ) -> Bool
{
    let signatures: [ UInt32 ] =
    [
        0xfeedface,
        0xcefaedfe,
        0xfeedfacf,
        0xcffaedfe,
        0xcafebabe,
        0xbebafeca,
        0x64796C64,
        0x646C7964,
    ]
    
    guard let data = try? Data( contentsOf: url ), data.count >= 4
    else
    {
        return false
    }
    
    let u1    = UInt32( data[ 0 ] )
    let u2    = UInt32( data[ 1 ] )
    let u3    = UInt32( data[ 2 ] )
    let u4    = UInt32( data[ 3 ] )
    let magic = u1 | ( u2 << 8 ) | ( u3 << 16 ) | ( u4 << 24 )
    
    return signatures.contains { $0 == magic }
}

func isWindowsPE( url: URL ) -> Bool
{
    let signatures: [ UInt32 ] =
    [
        0x5A4D,
        0x4D5A,
    ]
    
    guard let data = try? Data( contentsOf: url ), data.count >= 2
    else
    {
        return false
    }
    
    let u1    = UInt32( data[ 0 ] )
    let u2    = UInt32( data[ 1 ] )
    let magic = u1 | ( u2 << 8 )
    
    return signatures.contains { $0 == magic }
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

func getStrings( file: ( url: URL, type: FileType ) ) -> [ String ]
{
    switch file.type
    {
        case .machO:     return getLines( command: "/usr/bin/strings",         arguments: [ file.url.path ] )
        case .windowsPE: return getLines( command: "/opt/homebrew/bin/rpecli", arguments: [ "strings", file.url.path ] )
    }
}

func getSymbols( file: ( url: URL, type: FileType ) ) -> [ String ]
{
    switch file.type
    {
        case .machO:     return getLines( command: "/usr/bin/nm",              arguments: [ file.url.path ] )
        case .windowsPE: return getLines( command: "/opt/homebrew/bin/rpecli", arguments: [ "export", file.url.path ] )
    }
    
}

func getObjCMethods( file: ( url: URL, type: FileType ) ) -> [ String ]
{
    switch file.type
    {
        case .machO:     return getLines( command: "/opt/homebrew/bin/macho", arguments: [ "-m", file.url.path ] )
        case .windowsPE: return []
    }
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
