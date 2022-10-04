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

public class Task
{
    private var task:    Process
    private var pipeOut: Pipe
    private var pipeErr: Pipe

    public private( set ) var terminationStatus: Int32?
    public private( set ) var standardOutput:    Data
    public private( set ) var standardError:     Data

    public class func run( path: String, arguments: [ String ], input: Data? ) -> Task?
    {
        guard FileManager.default.fileExists( atPath: path )
        else
        {
            return nil
        }

        let task = Task( executable: URL( fileURLWithPath: path ), arguments: arguments )

        task.run( input: input )

        return task
    }

    public init( executable: URL, arguments: [ String ] )
    {
        self.pipeOut = Pipe()
        self.pipeErr = Pipe()
        self.task    = Process()

        self.task.launchPath     = executable.path
        self.task.arguments      = arguments
        self.task.standardOutput = self.pipeOut
        self.task.standardError  = self.pipeErr

        self.standardOutput = Data()
        self.standardError  = Data()

        NotificationCenter.default.addObserver( self, selector: #selector( self.dataAvailableForStandardOutput( _: ) ), name: NSNotification.Name.NSFileHandleDataAvailable, object: self.pipeOut.fileHandleForReading )
        NotificationCenter.default.addObserver( self, selector: #selector( self.dataAvailableForStandardError( _: )  ), name: NSNotification.Name.NSFileHandleDataAvailable, object: self.pipeErr.fileHandleForReading )

        self.pipeOut.fileHandleForReading.waitForDataInBackgroundAndNotify()
        self.pipeErr.fileHandleForReading.waitForDataInBackgroundAndNotify()
    }

    public func run( input: Data? )
    {
        if let _ = input
        {
            self.task.standardInput = Pipe()
        }

        self.task.launch()

        if let input = input, let pipe = self.task.standardInput as? Pipe
        {
            let handle = pipe.fileHandleForWriting

            handle.write( input )
            try? handle.close()
        }

        self.task.waitUntilExit()

        self.terminationStatus = self.task.terminationStatus
    }

    @objc
    private func dataAvailableForStandardOutput( _ notification: Notification )
    {
        guard let handle = notification.object as? FileHandle?,
              let data   = handle?.availableData
        else
        {
            return
        }

        self.standardOutput.append( data )
        handle?.waitForDataInBackgroundAndNotify()
    }

    @objc
    private func dataAvailableForStandardError( _ notification: Notification )
    {
        guard let handle = notification.object as? FileHandle?,
              let data = handle?.availableData
        else
        {
            return
        }

        self.standardError.append( data )
        handle?.waitForDataInBackgroundAndNotify()
    }
}
