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

let arguments = ProcessInfo.processInfo.arguments

if arguments.count != 3
{
    let exec = arguments.isEmpty ? "FindString" : URL( fileURLWithPath: arguments[ 0 ] ).lastPathComponent

    print( "Usage: \( exec ) PATH STRING" )
    exit( -1 )
}

let path   = arguments[ 1 ]
let search = arguments[ 2 ]

guard let enumerator = FileManager.default.enumerator( atPath: path )
else
{
    exit( -1 )
}

enumerator.compactMap { $0 as? String }.forEach
{
    let url = URL( fileURLWithPath: path ).appendingPathComponent( $0 )

    guard FileManager.default.isExecutableFile( atPath: url.path )
    else
    {
        return
    }

    guard let task = Task.run( path: "/usr/bin/strings", arguments: [ url.path ], input: nil ),
          let out  = String( data: task.standardOutput, encoding: .utf8 ),
          task.terminationStatus == 0
    else
    {
        return
    }

    if out.contains( search )
    {
        print( url.path )
    }
}
