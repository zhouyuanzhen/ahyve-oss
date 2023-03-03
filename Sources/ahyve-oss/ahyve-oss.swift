import Foundation
import ArgumentParser
import Virtualization

func createConsoleConfiguration() -> VZSerialPortConfiguration {
    let consoleConfiguration = VZVirtioConsoleDeviceSerialPortConfiguration()

    let inputFileHandle = FileHandle.standardInput
    let outputFileHandle = FileHandle.standardOutput

    // Put stdin into raw mode, disabling local echo, input canonicalization and CR-NL mapping.
    var attributes = termios()
    tcgetattr(inputFileHandle.fileDescriptor, &attributes)
    attributes.c_iflag &= ~tcflag_t(ICRNL)
    attributes.c_lflag &= ~tcflag_t(ICANON | ECHO)
    tcsetattr(inputFileHandle.fileDescriptor, TCSANOW, &attributes)

    consoleConfiguration.attachment = VZFileHandleSerialPortAttachment(fileHandleForReading: inputFileHandle, fileHandleForWriting: outputFileHandle)

    return consoleConfiguration
}

class Delegate: NSObject, VZVirtualMachineDelegate {
    func guestDidStop(_ virtualMachine: VZVirtualMachine) { exit(0) }
    func virtualMachine(_ virtualMachine: VZVirtualMachine, didStopWithError error: Error) { exit(1) }
}

var vm: VZVirtualMachine? = nil
let vmCfg = VZVirtualMachineConfiguration()

let delegate = Delegate()

struct AhyveOSS: ParsableCommand {
    @Option(name: .shortAndLong, help: "CPU Count")
    var cpus: Int = 1

    @Option(name: [ .short, .customLong("mem") ], help: "Memory Size (MB)")
    var memory: UInt64 = 512 // 512 MB default

    @Option(name: [ .short, .customLong("disk") ], help: "VMDisk file path")
    var disk: String = ""

    @Option(name: [ .short, .customLong("net") ], help: "Network (Use n=no to disable network of the VM)")
    var network: String = "nat"

    @Option(name: .shortAndLong, help: "Kernel file path")
    var kernel: String?

    @Option(name: .shortAndLong, help: "Initrd file path")
    var initrd: String?

    @Option(name: .long, help: "Kernel cmdline")
    var cmdline: String?

    mutating func run() throws {
        vmCfg.cpuCount = cpus
        vmCfg.memorySize = memory * 1024 * 1024

        let vmKernelURL = URL(fileURLWithPath: kernel!)
        let vmBootLoader = VZLinuxBootLoader(kernelURL: vmKernelURL)
        if initrd != nil { vmBootLoader.initialRamdiskURL = URL(fileURLWithPath: initrd!) }
        if cmdline != nil { vmBootLoader.commandLine = cmdline! }
        
        vmCfg.bootLoader = vmBootLoader

        vmCfg.serialPorts = [ createConsoleConfiguration() ]

        if disk != "" {
            vmCfg.storageDevices = []
            let vmDisk: VZDiskImageStorageDeviceAttachment
            do {
                vmDisk = try VZDiskImageStorageDeviceAttachment(url: URL(fileURLWithPath: disk), readOnly: false)
                vmCfg.storageDevices.append(VZVirtioBlockDeviceConfiguration(attachment: vmDisk))
            } catch { throw error }
        }

        if network != "no" {
            vmCfg.networkDevices = []
            let netCfg = VZVirtioNetworkDeviceConfiguration()
            netCfg.attachment = VZNATNetworkDeviceAttachment()
            vmCfg.networkDevices.append(netCfg)
        }
        
        vmCfg.entropyDevices = [ VZVirtioEntropyDeviceConfiguration() ]
        
        do {try vmCfg.validate()} catch {throw error}
        
        vm = VZVirtualMachine(configuration: vmCfg)
        vm!.delegate = delegate

        vm!.start(completionHandler: { (result: Result<Void, Error>) -> Void in
            switch result {
            case .success:
                return
            case .failure(let error):
                print(error)
                return
            }
        })

        RunLoop.main.run()
    }
}

AhyveOSS.main()
